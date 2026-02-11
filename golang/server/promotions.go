package server

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"FlowerApplication/server/models"
	"FlowerApplication/server/utils"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

func (a *App) handleListPromotions(c *gin.Context) {
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	includeAll := strings.ToLower(c.Query("all")) == "true"
	filter := bson.M{}
	if !includeAll {
		filter["isActive"] = true
	}

	findOptions, pagination := utils.BuildFindOptions(c, "sortOrder -createdAt")
	cursor, err := a.Store.Promotions.Find(ctx, filter, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var promotions []models.Promotion
	if err := cursor.All(ctx, &promotions); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	if pagination != nil {
		total, err := a.Store.Promotions.CountDocuments(ctx, filter)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"data":       promotions,
			"pagination": utils.BuildPaginationMeta(total, pagination.Page, pagination.Limit),
		})
		return
	}

	c.JSON(http.StatusOK, promotions)
}

func (a *App) handleCreatePromotion(c *gin.Context) {
	var payload struct {
		Title     string      `json:"title"`
		Subtitle  string      `json:"subtitle"`
		ImageURL  string      `json:"imageUrl"`
		IsActive  *bool       `json:"isActive"`
		SortOrder interface{} `json:"sortOrder"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}

	title := strings.TrimSpace(payload.Title)
	imageURL := strings.TrimSpace(payload.ImageURL)
	if title == "" || imageURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Title and imageUrl are required"})
		return
	}

	sortOrder := 0
	switch value := payload.SortOrder.(type) {
	case float64:
		sortOrder = int(value)
	case string:
		if parsed, err := strconv.Atoi(value); err == nil {
			sortOrder = parsed
		}
	}

	isActive := true
	if payload.IsActive != nil {
		isActive = *payload.IsActive
	}

	promotion := models.Promotion{
		Title:     title,
		Subtitle:  strings.TrimSpace(payload.Subtitle),
		ImageURL:  imageURL,
		IsActive:  isActive,
		SortOrder: sortOrder,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	result, err := a.Store.Promotions.InsertOne(ctx, promotion)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	if oid, ok := result.InsertedID.(primitive.ObjectID); ok {
		promotion.ID = oid
	}

	c.JSON(http.StatusCreated, promotion)
}

func (a *App) handleDeletePromotion(c *gin.Context) {
	promotionID, err := primitive.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	res, err := a.Store.Promotions.DeleteOne(ctx, bson.M{"_id": promotionID})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	if res.DeletedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Promotion not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Promotion deleted"})
}
