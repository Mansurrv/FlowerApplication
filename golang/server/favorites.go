package server

import (
	"net/http"
	"time"

	"FlowerApplication/server/models"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

type favoriteInput struct {
	UserID   string `json:"userId"`
	FlowerID string `json:"flowerId"`
}

func (a *App) handleCreateFavorite(c *gin.Context) {
	var payload favoriteInput
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}

	userID, err := primitive.ObjectIDFromHex(payload.UserID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid userId"})
		return
	}

	flowerID, err := primitive.ObjectIDFromHex(payload.FlowerID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid flowerId"})
		return
	}

	favorite := models.Favorite{
		UserID:    userID,
		FlowerID:  flowerID,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	result, err := a.Store.Favorites.InsertOne(ctx, favorite)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	if oid, ok := result.InsertedID.(primitive.ObjectID); ok {
		favorite.ID = oid
	}

	c.JSON(http.StatusCreated, favorite)
}

func (a *App) handleFavoritesByUser(c *gin.Context) {
	userID, err := primitive.ObjectIDFromHex(c.Param("userId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	cursor, err := a.Store.Favorites.Find(ctx, bson.M{"userId": userID})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var favorites []models.Favorite
	if err := cursor.All(ctx, &favorites); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	flowerIDs := make([]primitive.ObjectID, 0, len(favorites))
	for _, favorite := range favorites {
		if favorite.FlowerID != primitive.NilObjectID {
			flowerIDs = append(flowerIDs, favorite.FlowerID)
		}
	}

	flowerMap, err := fetchFlowerMap(ctx, a.Store.Flowers, flowerIDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	response := make([]gin.H, 0, len(favorites))
	for _, favorite := range favorites {
		flowerValue := interface{}(favorite.FlowerID)
		if flower, ok := flowerMap[favorite.FlowerID]; ok {
			flowerValue = flower
		}
		response = append(response, gin.H{
			"_id":       favorite.ID,
			"userId":    favorite.UserID,
			"flowerId":  flowerValue,
			"createdAt": favorite.CreatedAt,
			"updatedAt": favorite.UpdatedAt,
		})
	}

	c.JSON(http.StatusOK, response)
}

func (a *App) handleDeleteFavorite(c *gin.Context) {
	favoriteID, err := primitive.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	_, err = a.Store.Favorites.DeleteOne(ctx, bson.M{"_id": favoriteID})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Favorite removed"})
}
