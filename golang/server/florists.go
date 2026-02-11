package server

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"FlowerApplication/server/models"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func (a *App) handleFloristProfile(c *gin.Context) {
	userValue, ok := c.Get("user")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "No token, authorization denied"})
		return
	}
	authUser := userValue.(AuthUser)

	userID, err := primitive.ObjectIDFromHex(authUser.ID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var user models.User
	if err := a.Store.Users.FindOne(ctx, bson.M{"_id": userID}, options.FindOne().SetProjection(bson.M{"password": 0})).Decode(&user); err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	if user.Role != "florist" {
		c.JSON(http.StatusForbidden, gin.H{"message": "Access denied. User is not a florist"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"shopName":     defaultString(user.ShopName, "My Flower Shop"),
		"email":        user.Email,
		"phone":        defaultString(user.Phone, ""),
		"city":         defaultString(user.City, ""),
		"address":      defaultString(user.Address, ""),
		"description":  defaultString(user.Description, ""),
		"rating":       user.Rating,
		"totalReviews": user.TotalReviews,
		"status":       defaultString(user.Status, "active"),
		"createdAt":    user.CreatedAt,
	})
}

func (a *App) handleUpdateFloristProfile(c *gin.Context) {
	userValue, ok := c.Get("user")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "No token, authorization denied"})
		return
	}
	authUser := userValue.(AuthUser)

	userID, err := primitive.ObjectIDFromHex(authUser.ID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var existing models.User
	if err := a.Store.Users.FindOne(ctx, bson.M{"_id": userID}).Decode(&existing); err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	if existing.Role != "florist" {
		c.JSON(http.StatusForbidden, gin.H{"message": "Access denied. User is not a florist"})
		return
	}

	var payload struct {
		ShopName    *string `json:"shopName"`
		Phone       *string `json:"phone"`
		Address     *string `json:"address"`
		Description *string `json:"description"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}

	updates := bson.M{}
	if payload.ShopName != nil {
		updates["shopName"] = strings.TrimSpace(*payload.ShopName)
	}
	if payload.Phone != nil {
		updates["phone"] = strings.TrimSpace(*payload.Phone)
	}
	if payload.Address != nil {
		updates["address"] = strings.TrimSpace(*payload.Address)
	}
	if payload.Description != nil {
		updates["description"] = strings.TrimSpace(*payload.Description)
	}
	updates["updatedAt"] = time.Now()

	var user models.User
	if err := a.Store.Users.FindOneAndUpdate(ctx, bson.M{"_id": userID}, bson.M{"$set": updates}, options.FindOneAndUpdate().SetReturnDocument(options.After)).Decode(&user); err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Profile updated successfully",
		"profile": gin.H{
			"shopName":     user.ShopName,
			"email":        user.Email,
			"phone":        user.Phone,
			"address":      user.Address,
			"description":  user.Description,
			"city":         user.City,
			"rating":       user.Rating,
			"totalReviews": user.TotalReviews,
			"status":       user.Status,
		},
	})
}

func (a *App) handleFloristStatistics(c *gin.Context) {
	userValue, ok := c.Get("user")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Access denied"})
		return
	}
	authUser := userValue.(AuthUser)
	userID, err := primitive.ObjectIDFromHex(authUser.ID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var user models.User
	if err := a.Store.Users.FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil || user.Role != "florist" {
		c.JSON(http.StatusForbidden, gin.H{"message": "Access denied"})
		return
	}

	floristID := userID.Hex()

	totalFlowers, _ := a.Store.Flowers.CountDocuments(ctx, bson.M{"floristId": userID})
	availableFlowers, _ := a.Store.Flowers.CountDocuments(ctx, bson.M{"floristId": userID, "available": true})
	soldOutFlowers, _ := a.Store.Flowers.CountDocuments(ctx, bson.M{"floristId": userID, "available": false})

	totalOrders, _ := a.Store.Orders.CountDocuments(ctx, bson.M{"floristId": floristID})
	pendingOrders, _ := a.Store.Orders.CountDocuments(ctx, bson.M{"floristId": floristID, "status": "pending"})
	completedOrders, _ := a.Store.Orders.CountDocuments(ctx, bson.M{"floristId": floristID, "status": "completed"})

	var completed []models.Order
	cursor, err := a.Store.Orders.Find(ctx, bson.M{"floristId": floristID, "status": "completed"})
	if err == nil {
		_ = cursor.All(ctx, &completed)
		cursor.Close(ctx)
	}

	totalRevenue := 0.0
	for _, order := range completed {
		totalRevenue += order.TotalPrice
	}

	c.JSON(http.StatusOK, gin.H{
		"success":             true,
		"totalFlowers":        totalFlowers,
		"availableFlowers":    availableFlowers,
		"soldOutFlowers":      soldOutFlowers,
		"totalOrders":         totalOrders,
		"pendingOrders":       pendingOrders,
		"completedOrders":     completedOrders,
		"totalRevenue":        formatMoney(totalRevenue),
		"popularCategory":     "Roses",
		"mostExpensiveFlower": "Premium Orchid",
		"cheapestFlower":      "Basic Daisy",
	})
}

func (a *App) handleFloristOrders(c *gin.Context) {
	userValue, ok := c.Get("user")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "Access denied"})
		return
	}
	authUser := userValue.(AuthUser)
	userID, err := primitive.ObjectIDFromHex(authUser.ID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var user models.User
	if err := a.Store.Users.FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil || user.Role != "florist" {
		c.JSON(http.StatusForbidden, gin.H{"success": false, "message": "Access denied"})
		return
	}

	cursor, err := a.Store.Orders.Find(ctx, bson.M{"floristId": userID.Hex()}, options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}}))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var orders []models.Order
	if err := cursor.All(ctx, &orders); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	populated, err := a.populateOrders(ctx, orders, orderPopulateOptions{User: true, Deliver: true})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "orders": populated})
}

func (a *App) handleFloristFlowers(c *gin.Context) {
	userValue, ok := c.Get("user")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Access denied"})
		return
	}
	authUser := userValue.(AuthUser)
	userID, err := primitive.ObjectIDFromHex(authUser.ID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var user models.User
	if err := a.Store.Users.FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil || user.Role != "florist" {
		c.JSON(http.StatusForbidden, gin.H{"message": "Access denied"})
		return
	}

	cursor, err := a.Store.Flowers.Find(ctx, bson.M{"floristId": userID}, options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}}))
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

	populated, err := a.populateFlowers(ctx, flowers, flowerPopulateOptions{Category: true})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	formatted := make([]gin.H, 0, len(populated))
	for _, flower := range populated {
		formatted = append(formatted, gin.H{
			"_id":         flower["_id"],
			"name":        flower["name"],
			"price":       flower["price"],
			"description": flower["description"],
			"image_url":   flower["image_url"],
			"available":   flower["available"],
			"categoryId":  flower["categoryId"],
			"floristId":   flower["floristId"],
			"city":        flower["city"],
			"createdAt":   flower["createdAt"],
			"updatedAt":   flower["updatedAt"],
		})
	}

	c.JSON(http.StatusOK, formatted)
}

func defaultString(value string, fallback string) string {
	if strings.TrimSpace(value) == "" {
		return fallback
	}
	return value
}

func formatMoney(value float64) string {
	return fmt.Sprintf("%.2f", value)
}
