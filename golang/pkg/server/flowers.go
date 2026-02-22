package server

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"FlowerApplication/pkg/server/models"
	"FlowerApplication/pkg/server/utils"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type flowerInput struct {
	Name        string  `json:"name"`
	Price       float64 `json:"price"`
	Description string  `json:"description"`
	ImageURL    string  `json:"image_url"`
	ImageAlt    string  `json:"imageUrl"`
	Available   *bool   `json:"available"`
	CategoryID  string  `json:"categoryId"`
	FloristID   string  `json:"floristId"`
	City        string  `json:"city"`
}

func (a *App) handleCreateFlower(c *gin.Context) {
	var payload flowerInput
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	categoryID := primitive.NilObjectID
	if payload.CategoryID != "" {
		id, err := primitive.ObjectIDFromHex(payload.CategoryID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid categoryId"})
			return
		}
		categoryID = id
	}

	floristID := primitive.NilObjectID
	if payload.FloristID != "" {
		id, err := primitive.ObjectIDFromHex(payload.FloristID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid floristId"})
			return
		}
		floristID = id
	}

	imageURL := strings.TrimSpace(payload.ImageURL)
	if imageURL == "" {
		imageURL = strings.TrimSpace(payload.ImageAlt)
	}

	available := false
	if payload.Available != nil {
		available = *payload.Available
	}

	flower := models.Flower{
		Name:        strings.TrimSpace(payload.Name),
		Price:       payload.Price,
		Description: strings.TrimSpace(payload.Description),
		ImageURL:    imageURL,
		Available:   available,
		CategoryID:  categoryID,
		FloristID:   floristID,
		City:        strings.TrimSpace(payload.City),
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	result, err := a.Store.Flowers.InsertOne(ctx, flower)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if oid, ok := result.InsertedID.(primitive.ObjectID); ok {
		flower.ID = oid
	}

	c.JSON(http.StatusCreated, flower)
}

func (a *App) handleListFlowers(c *gin.Context) {
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{}
	q := strings.TrimSpace(c.Query("q"))
	if q != "" {
		filter["$or"] = []bson.M{
			{"name": bson.M{"$regex": q, "$options": "i"}},
			{"description": bson.M{"$regex": q, "$options": "i"}},
		}
	}

	if categoryRaw := strings.TrimSpace(c.Query("categoryId")); categoryRaw != "" {
		id, err := primitive.ObjectIDFromHex(categoryRaw)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid categoryId"})
			return
		}
		filter["categoryId"] = id
	}

	if floristRaw := strings.TrimSpace(c.Query("floristId")); floristRaw != "" {
		id, err := primitive.ObjectIDFromHex(floristRaw)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid floristId"})
			return
		}
		filter["floristId"] = id
	}

	if city := strings.TrimSpace(c.Query("city")); city != "" {
		filter["city"] = city
	}

	if availableRaw := c.Query("available"); availableRaw != "" {
		available := strings.ToLower(availableRaw) == "true"
		filter["available"] = available
	}

	minPrice := strings.TrimSpace(c.Query("minPrice"))
	maxPrice := strings.TrimSpace(c.Query("maxPrice"))
	if minPrice != "" || maxPrice != "" {
		priceFilter := bson.M{}
		if minPrice != "" {
			if value, err := strconv.ParseFloat(minPrice, 64); err == nil {
				priceFilter["$gte"] = value
			}
		}
		if maxPrice != "" {
			if value, err := strconv.ParseFloat(maxPrice, 64); err == nil {
				priceFilter["$lte"] = value
			}
		}
		if len(priceFilter) > 0 {
			filter["price"] = priceFilter
		}
	}

	findOptions := utils.BuildFindOptions(c, "-createdAt")
	cursor, err := a.Store.Flowers.Find(ctx, filter, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var flowers []models.Flower
	if err := cursor.All(ctx, &flowers); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	populated, err := a.populateFlowers(ctx, flowers, flowerPopulateOptions{Category: true, Florist: true})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, populated)
}

func (a *App) handleAdvancedFlowerSearch(c *gin.Context) {
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{}
	q := strings.TrimSpace(c.Query("q"))
	if q != "" {
		filter["$or"] = []bson.M{
			{"name": bson.M{"$regex": q, "$options": "i"}},
			{"description": bson.M{"$regex": q, "$options": "i"}},
		}
	}

	if categoryName := strings.TrimSpace(c.Query("category")); categoryName != "" {
		var category models.Category
		err := a.Store.Categories.FindOne(ctx, bson.M{
			"name": bson.M{"$regex": primitive.Regex{Pattern: "^" + categoryName + "$", Options: "i"}},
		}).Decode(&category)
		if err == nil {
			filter["categoryId"] = category.ID
		}
	}

	minPrice := strings.TrimSpace(c.Query("minPrice"))
	maxPrice := strings.TrimSpace(c.Query("maxPrice"))
	if minPrice != "" || maxPrice != "" {
		priceFilter := bson.M{}
		if minPrice != "" {
			if value, err := strconv.ParseFloat(minPrice, 64); err == nil {
				priceFilter["$gte"] = value
			}
		}
		if maxPrice != "" {
			if value, err := strconv.ParseFloat(maxPrice, 64); err == nil {
				priceFilter["$lte"] = value
			}
		}
		if len(priceFilter) > 0 {
			filter["price"] = priceFilter
		}
	}

	if availableRaw := c.Query("available"); availableRaw != "" {
		filter["available"] = strings.ToLower(availableRaw) == "true"
	}

	cursor, err := a.Store.Flowers.Find(ctx, filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var flowers []models.Flower
	if err := cursor.All(ctx, &flowers); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	populated, err := a.populateFlowers(ctx, flowers, flowerPopulateOptions{Category: true, Florist: true})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"count":   len(populated),
		"flowers": populated,
	})
}

func (a *App) handlePopularFlowers(c *gin.Context) {
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	findOptions := options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}}).SetLimit(10)
	cursor, err := a.Store.Flowers.Find(ctx, bson.M{"available": true}, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var flowers []models.Flower
	if err := cursor.All(ctx, &flowers); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	populated, err := a.populateFlowers(ctx, flowers, flowerPopulateOptions{Category: true, Florist: true})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"count":   len(populated),
		"flowers": populated,
	})
}

func (a *App) handleFlowerSearch(c *gin.Context) {
	q := strings.TrimSpace(c.Query("q"))
	if q == "" {
		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"count":   0,
			"flowers": []gin.H{},
		})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{
		"$or": []bson.M{
			{"name": bson.M{"$regex": q, "$options": "i"}},
			{"description": bson.M{"$regex": q, "$options": "i"}},
		},
	}

	cursor, err := a.Store.Flowers.Find(ctx, filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var flowers []models.Flower
	if err := cursor.All(ctx, &flowers); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	populated, err := a.populateFlowers(ctx, flowers, flowerPopulateOptions{Category: true, Florist: true})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"count":   len(populated),
		"flowers": populated,
	})
}

func (a *App) handleFlowersByCategory(c *gin.Context) {
	id, err := primitive.ObjectIDFromHex(c.Param("categoryId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{"categoryId": id}
	findOptions := utils.BuildFindOptions(c, "-createdAt")
	cursor, err := a.Store.Flowers.Find(ctx, filter, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var flowers []models.Flower
	if err := cursor.All(ctx, &flowers); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	populated, err := a.populateFlowers(ctx, flowers, flowerPopulateOptions{Category: false, Florist: false})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, populated)
}

func (a *App) handleFlowersByCity(c *gin.Context) {
	city := c.Param("city")
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{"city": city}
	findOptions := utils.BuildFindOptions(c, "-createdAt")
	cursor, err := a.Store.Flowers.Find(ctx, filter, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var flowers []models.Flower
	if err := cursor.All(ctx, &flowers); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	populated, err := a.populateFlowers(ctx, flowers, flowerPopulateOptions{Category: false, Florist: false})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, populated)
}

func (a *App) handleUpdateFlower(c *gin.Context) {
	id, err := primitive.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	var payload map[string]interface{}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}

	if categoryRaw, ok := payload["categoryId"].(string); ok && categoryRaw != "" {
		categoryID, err := primitive.ObjectIDFromHex(categoryRaw)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid categoryId"})
			return
		}
		payload["categoryId"] = categoryID
	}

	if floristRaw, ok := payload["floristId"].(string); ok && floristRaw != "" {
		floristID, err := primitive.ObjectIDFromHex(floristRaw)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid floristId"})
			return
		}
		payload["floristId"] = floristID
	}

	if imageAlt, ok := payload["imageUrl"].(string); ok && imageAlt != "" {
		payload["image_url"] = imageAlt
		delete(payload, "imageUrl")
	}

	payload["updatedAt"] = time.Now()

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var updated models.Flower
	err = a.Store.Flowers.FindOneAndUpdate(ctx, bson.M{"_id": id}, bson.M{"$set": payload}, options.FindOneAndUpdate().SetReturnDocument(options.After)).Decode(&updated)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"message": "Not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, updated)
}

func (a *App) handleDeleteFlower(c *gin.Context) {
	id, err := primitive.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	_, err = a.Store.Flowers.DeleteOne(ctx, bson.M{"_id": id})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Flower deleted"})
}
