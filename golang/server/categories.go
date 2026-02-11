package server

import (
	"net/http"

	"FlowerApplication/server/models"
	"FlowerApplication/server/utils"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

func (a *App) handleCreateCategory(c *gin.Context) {
	var payload models.Category
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if payload.Name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Name is required"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	result, err := a.Store.Categories.InsertOne(ctx, bson.M{"name": payload.Name})
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	payload.ID, _ = result.InsertedID.(primitive.ObjectID)
	c.JSON(http.StatusCreated, payload)
}

func (a *App) handleListCategories(c *gin.Context) {
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	findOptions, pagination := utils.BuildFindOptions(c, "name")
	cursor, err := a.Store.Categories.Find(ctx, bson.M{}, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var categories []models.Category
	if err := cursor.All(ctx, &categories); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	if pagination != nil {
		total, err := a.Store.Categories.CountDocuments(ctx, bson.M{})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"data":       categories,
			"pagination": utils.BuildPaginationMeta(total, pagination.Page, pagination.Limit),
		})
		return
	}

	c.JSON(http.StatusOK, categories)
}

func (a *App) handleGetCategory(c *gin.Context) {
	id, err := utils.ParseObjectID(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var category models.Category
	if err := a.Store.Categories.FindOne(ctx, bson.M{"_id": id}).Decode(&category); err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"message": "Not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, category)
}

func (a *App) handleDeleteCategory(c *gin.Context) {
	id, err := utils.ParseObjectID(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	_, err = a.Store.Categories.DeleteOne(ctx, bson.M{"_id": id})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Category deleted"})
}
