package server

import (
	"net/http"
	"time"

	"FlowerApplication/pkg/server/models"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

type routeInput struct {
	OrderID    string `json:"orderId"`
	StartPoint string `json:"startPoint"`
	EndPoint   string `json:"endPoint"`
}

func (a *App) handleCreateRoute(c *gin.Context) {
	var payload routeInput
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}

	orderID, err := primitive.ObjectIDFromHex(payload.OrderID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid orderId"})
		return
	}

	route := models.Route{
		OrderID:    orderID,
		StartPoint: payload.StartPoint,
		EndPoint:   payload.EndPoint,
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	result, err := a.Store.Routes.InsertOne(ctx, route)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	if oid, ok := result.InsertedID.(primitive.ObjectID); ok {
		route.ID = oid
	}

	c.JSON(http.StatusCreated, route)
}

func (a *App) handleRouteByOrder(c *gin.Context) {
	orderID, err := primitive.ObjectIDFromHex(c.Param("orderId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var route models.Route
	err = a.Store.Routes.FindOne(ctx, bson.M{"orderId": orderID}).Decode(&route)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusOK, nil)
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, route)
}
