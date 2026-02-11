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
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func (a *App) handleCreateOrder(c *gin.Context) {
	var order models.Order
	if err := c.ShouldBindJSON(&order); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if order.UserID == "" || order.TotalPrice == 0 || order.City == "" || len(order.Items) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Missing required fields"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	if order.FloristID == "" && len(order.Items) > 0 {
		firstFlowerID := order.Items[0].FlowerID
		if flowerObjectID, ok := parseObjectID(firstFlowerID); ok {
			var flower models.Flower
			if err := a.Store.Flowers.FindOne(ctx, bson.M{"_id": flowerObjectID}).Decode(&flower); err == nil {
				if flower.FloristID != primitive.NilObjectID {
					order.FloristID = flower.FloristID.Hex()
				}
			}
		}
	}

	if order.Status == "" {
		order.Status = "pending"
	}
	if order.OrderNumber == "" {
		randomSuffix := time.Now().UnixNano() % 1000
		order.OrderNumber = "ORD-" + time.Now().Format("20060102150405") + "-" + strconv.FormatInt(randomSuffix, 10)
	}
	order.CreatedAt = time.Now()

	result, err := a.Store.Orders.InsertOne(ctx, order)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if oid, ok := result.InsertedID.(primitive.ObjectID); ok {
		order.ID = oid
	}

	c.JSON(http.StatusCreated, order)
}

func (a *App) handleListOrders(c *gin.Context) {
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{}
	if status := strings.TrimSpace(c.Query("status")); status != "" {
		filter["status"] = status
	}
	if userId := strings.TrimSpace(c.Query("userId")); userId != "" {
		filter["userId"] = userId
	}
	if floristId := strings.TrimSpace(c.Query("floristId")); floristId != "" {
		filter["floristId"] = floristId
	}
	if deliverId := strings.TrimSpace(c.Query("deliverId")); deliverId != "" {
		filter["deliverId"] = deliverId
	}

	findOptions, pagination := utils.BuildFindOptions(c, "-createdAt")
	cursor, err := a.Store.Orders.Find(ctx, filter, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var orders []models.Order
	if err := cursor.All(ctx, &orders); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	populated, err := a.populateOrders(ctx, orders, orderPopulateOptions{User: true, Florist: true, Deliver: true})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	if pagination != nil {
		total, err := a.Store.Orders.CountDocuments(ctx, filter)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"data":       populated,
			"pagination": utils.BuildPaginationMeta(total, pagination.Page, pagination.Limit),
		})
		return
	}

	c.JSON(http.StatusOK, populated)
}

func (a *App) handleOrdersByUser(c *gin.Context) {
	userId := c.Param("userId")
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{"userId": userId}
	findOptions, pagination := utils.BuildFindOptions(c, "-createdAt")
	cursor, err := a.Store.Orders.Find(ctx, filter, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var orders []models.Order
	if err := cursor.All(ctx, &orders); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	populated, err := a.populateOrders(ctx, orders, orderPopulateOptions{Florist: true})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	if pagination != nil {
		total, err := a.Store.Orders.CountDocuments(ctx, filter)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"data":       populated,
			"pagination": utils.BuildPaginationMeta(total, pagination.Page, pagination.Limit),
		})
		return
	}

	c.JSON(http.StatusOK, populated)
}

func (a *App) handleOrdersByFlorist(c *gin.Context) {
	floristId := c.Param("floristId")
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{"floristId": floristId}
	findOptions, pagination := utils.BuildFindOptions(c, "-createdAt")
	cursor, err := a.Store.Orders.Find(ctx, filter, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var orders []models.Order
	if err := cursor.All(ctx, &orders); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	populated, err := a.populateOrders(ctx, orders, orderPopulateOptions{User: true, Florist: true, Deliver: true})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	if pagination != nil {
		total, err := a.Store.Orders.CountDocuments(ctx, filter)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"data":       populated,
			"pagination": utils.BuildPaginationMeta(total, pagination.Page, pagination.Limit),
		})
		return
	}

	c.JSON(http.StatusOK, populated)
}

func (a *App) handleOrdersByDeliver(c *gin.Context) {
	deliverId := c.Param("deliverId")
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{"deliverId": deliverId}
	findOptions, pagination := utils.BuildFindOptions(c, "-createdAt")
	cursor, err := a.Store.Orders.Find(ctx, filter, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var orders []models.Order
	if err := cursor.All(ctx, &orders); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	populated, err := a.populateOrders(ctx, orders, orderPopulateOptions{User: true, Florist: true})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	if pagination != nil {
		total, err := a.Store.Orders.CountDocuments(ctx, filter)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"data":       populated,
			"pagination": utils.BuildPaginationMeta(total, pagination.Page, pagination.Limit),
		})
		return
	}

	c.JSON(http.StatusOK, populated)
}

func (a *App) handleAvailableOrders(c *gin.Context) {
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{
		"status": bson.M{"$in": []string{"confirmed", "preparing", "delivering"}},
		"$or": []bson.M{
			{"deliverId": bson.M{"$exists": false}},
			{"deliverId": nil},
			{"deliverId": ""},
		},
	}

	findOptions, pagination := utils.BuildFindOptions(c, "-createdAt")
	cursor, err := a.Store.Orders.Find(ctx, filter, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var orders []models.Order
	if err := cursor.All(ctx, &orders); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	populated, err := a.populateOrders(ctx, orders, orderPopulateOptions{User: true, Florist: true})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	if pagination != nil {
		total, err := a.Store.Orders.CountDocuments(ctx, filter)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"data":       populated,
			"pagination": utils.BuildPaginationMeta(total, pagination.Page, pagination.Limit),
		})
		return
	}

	c.JSON(http.StatusOK, populated)
}

func (a *App) handleOrdersByFlower(c *gin.Context) {
	flowerId := c.Param("flowerId")
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{"items.flowerId": flowerId}
	findOptions, pagination := utils.BuildFindOptions(c, "-createdAt")
	cursor, err := a.Store.Orders.Find(ctx, filter, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var orders []models.Order
	if err := cursor.All(ctx, &orders); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	populated, err := a.populateOrders(ctx, orders, orderPopulateOptions{User: true, Florist: true, Deliver: true})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	if pagination != nil {
		total, err := a.Store.Orders.CountDocuments(ctx, filter)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"data":       populated,
			"pagination": utils.BuildPaginationMeta(total, pagination.Page, pagination.Limit),
		})
		return
	}

	c.JSON(http.StatusOK, populated)
}

func (a *App) handleOrdersMissingFlorist(c *gin.Context) {
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{
		"$or": []bson.M{
			{"floristId": bson.M{"$exists": false}},
			{"floristId": nil},
			{"floristId": ""},
		},
	}

	findOptions := options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}})
	cursor, err := a.Store.Orders.Find(ctx, filter, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var orders []models.Order
	if err := cursor.All(ctx, &orders); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	populated, err := a.populateOrders(ctx, orders, orderPopulateOptions{User: true})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	message := "All orders have floristId"
	if len(populated) > 0 {
		message = strconv.Itoa(len(populated)) + " orders need floristId"
	}

	c.JSON(http.StatusOK, gin.H{
		"count":   len(populated),
		"orders":  populated,
		"message": message,
	})
}

func (a *App) handleOrdersFixFlorist(c *gin.Context) {
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{
		"$or": []bson.M{
			{"floristId": bson.M{"$exists": false}},
			{"floristId": nil},
			{"floristId": ""},
		},
	}

	cursor, err := a.Store.Orders.Find(ctx, filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var orders []models.Order
	if err := cursor.All(ctx, &orders); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	updatedCount := 0
	errors := make([]gin.H, 0)

	for _, order := range orders {
		if len(order.Items) == 0 {
			continue
		}
		firstFlowerID := order.Items[0].FlowerID
		flowerObjectID, ok := parseObjectID(firstFlowerID)
		if !ok {
			errors = append(errors, gin.H{"orderId": order.ID, "error": "invalid flowerId"})
			continue
		}

		var flower models.Flower
		if err := a.Store.Flowers.FindOne(ctx, bson.M{"_id": flowerObjectID}).Decode(&flower); err != nil {
			errors = append(errors, gin.H{"orderId": order.ID, "error": err.Error()})
			continue
		}

		if flower.FloristID == primitive.NilObjectID {
			continue
		}

		_, err := a.Store.Orders.UpdateByID(ctx, order.ID, bson.M{"$set": bson.M{"floristId": flower.FloristID.Hex()}})
		if err != nil {
			errors = append(errors, gin.H{"orderId": order.ID, "error": err.Error()})
			continue
		}
		updatedCount++
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"updated": updatedCount,
		"errors":  errors,
		"message": "Updated " + strconv.Itoa(updatedCount) + " orders with floristId",
	})
}

func (a *App) handleUpdateOrderStatus(c *gin.Context) {
	id, err := primitive.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid resource id"})
		return
	}

	var payload struct {
		Status string `json:"status"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var updated models.Order
	err = a.Store.Orders.FindOneAndUpdate(ctx, bson.M{"_id": id}, bson.M{"$set": bson.M{"status": payload.Status}}, options.FindOneAndUpdate().SetReturnDocument(options.After)).Decode(&updated)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, updated)
}

func (a *App) handleAssignDeliver(c *gin.Context) {
	id, err := primitive.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid resource id"})
		return
	}

	var payload struct {
		DeliverID string `json:"deliverId"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var updated models.Order
	err = a.Store.Orders.FindOneAndUpdate(ctx, bson.M{"_id": id}, bson.M{"$set": bson.M{"deliverId": payload.DeliverID}}, options.FindOneAndUpdate().SetReturnDocument(options.After)).Decode(&updated)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, updated)
}

func (a *App) handleAssignFlorist(c *gin.Context) {
	id, err := primitive.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid resource id"})
		return
	}

	var payload struct {
		FloristID string `json:"floristId"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var updated models.Order
	err = a.Store.Orders.FindOneAndUpdate(ctx, bson.M{"_id": id}, bson.M{"$set": bson.M{"floristId": payload.FloristID}}, options.FindOneAndUpdate().SetReturnDocument(options.After)).Decode(&updated)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, updated)
}

func (a *App) handleDeleteOrder(c *gin.Context) {
	id, err := primitive.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	_, err = a.Store.Orders.DeleteOne(ctx, bson.M{"_id": id})
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Order deleted"})
}
