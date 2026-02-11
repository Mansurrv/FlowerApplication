package server

import (
	"net/http"
	"time"

	"FlowerApplication/server/models"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

type paymentInput struct {
	OrderID string     `json:"orderId"`
	Amount  float64    `json:"amount"`
	Method  string     `json:"method"`
	Status  string     `json:"status"`
	PaidAt  *time.Time `json:"paidAt"`
}

func (a *App) handleCreatePayment(c *gin.Context) {
	var payload paymentInput
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}

	orderID, err := primitive.ObjectIDFromHex(payload.OrderID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid orderId"})
		return
	}

	payment := models.Payment{
		OrderID:   orderID,
		Amount:    payload.Amount,
		Method:    payload.Method,
		Status:    payload.Status,
		PaidAt:    payload.PaidAt,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	result, err := a.Store.Payments.InsertOne(ctx, payment)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	if oid, ok := result.InsertedID.(primitive.ObjectID); ok {
		payment.ID = oid
	}

	c.JSON(http.StatusCreated, payment)
}

func (a *App) handlePaymentsByOrder(c *gin.Context) {
	orderID, err := primitive.ObjectIDFromHex(c.Param("orderId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	cursor, err := a.Store.Payments.Find(ctx, bson.M{"orderId": orderID})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var payments []models.Payment
	if err := cursor.All(ctx, &payments); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, payments)
}
