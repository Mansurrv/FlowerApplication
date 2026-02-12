package server

import (
	"net/http"
	"strings"
	"time"

	"FlowerApplication/pkg/server/models"
	"FlowerApplication/pkg/server/utils"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

func (a *App) handleListCities(c *gin.Context) {
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	findOptions := utils.BuildFindOptions(c, "name")
	cursor, err := a.Store.Cities.Find(ctx, bson.M{}, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var cities []models.City
	if err := cursor.All(ctx, &cities); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, cities)
}

func (a *App) handleCreateCity(c *gin.Context) {
	var payload struct {
		Name string `json:"name"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}

	name := strings.TrimSpace(payload.Name)
	if name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "City name is required"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var existing models.City
	err := a.Store.Cities.FindOne(ctx, bson.M{"name": name}).Decode(&existing)
	if err == nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "City already exists"})
		return
	}
	if err != nil && err != mongo.ErrNoDocuments {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	city := models.City{
		Name:      name,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	result, err := a.Store.Cities.InsertOne(ctx, city)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	if oid, ok := result.InsertedID.(primitive.ObjectID); ok {
		city.ID = oid
	}

	c.JSON(http.StatusCreated, city)
}
