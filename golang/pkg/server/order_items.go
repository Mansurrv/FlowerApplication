package server

import (
	"net/http"
	"time"

	"FlowerApplication/pkg/server/models"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

type orderItemInput struct {
	OrderID  string  `json:"orderId"`
	FlowerID string  `json:"flowerId"`
	Quantity int     `json:"quantity"`
	Price    float64 `json:"price"`
}

func (a *App) handleCreateOrderItem(c *gin.Context) {
	var payload orderItemInput
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}

	orderID, err := primitive.ObjectIDFromHex(payload.OrderID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid orderId"})
		return
	}
	flowerID, err := primitive.ObjectIDFromHex(payload.FlowerID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid flowerId"})
		return
	}

	item := models.OrderItem{
		OrderID:   orderID,
		FlowerID:  flowerID,
		Quantity:  payload.Quantity,
		Price:     payload.Price,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	result, err := a.Store.OrderItems.InsertOne(ctx, item)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	if oid, ok := result.InsertedID.(primitive.ObjectID); ok {
		item.ID = oid
	}

	c.JSON(http.StatusCreated, item)
}

func (a *App) handleOrderItemsByOrder(c *gin.Context) {
	orderID, err := primitive.ObjectIDFromHex(c.Param("orderId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	cursor, err := a.Store.OrderItems.Find(ctx, bson.M{"orderId": orderID})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var items []models.OrderItem
	if err := cursor.All(ctx, &items); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	flowerIDs := make([]primitive.ObjectID, 0, len(items))
	for _, item := range items {
		if item.FlowerID != primitive.NilObjectID {
			flowerIDs = append(flowerIDs, item.FlowerID)
		}
	}

	flowerMap, err := fetchFlowerMap(ctx, a.Store.Flowers, flowerIDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	response := make([]gin.H, 0, len(items))
	for _, item := range items {
		flowerValue := interface{}(item.FlowerID)
		if flower, ok := flowerMap[item.FlowerID]; ok {
			flowerValue = flower
		}
		response = append(response, gin.H{
			"_id":       item.ID,
			"orderId":   item.OrderID,
			"flowerId":  flowerValue,
			"quantity":  item.Quantity,
			"price":     item.Price,
			"createdAt": item.CreatedAt,
			"updatedAt": item.UpdatedAt,
		})
	}

	c.JSON(http.StatusOK, response)
}
