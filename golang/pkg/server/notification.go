package server

import (
	"net/http"
	"strings"
	"time"

	"FlowerApplication/pkg/server/models"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

func (a *App) handleCreateNotification(c *gin.Context) {
	var input struct {
		ToUser   string `json:"to_user"`
		FromUser string `json:"from_user"`
		Message  string `json:"message"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid input"})
		return
	}

	message := strings.TrimSpace(input.Message)
	if message == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "message is required"})
		return
	}

	fromID := ""
	if userValue, ok := c.Get("user"); ok {
		if authUser, ok := userValue.(AuthUser); ok && strings.TrimSpace(authUser.ID) != "" {
			fromID = authUser.ID
		}
	}
	if fromID == "" {
		fromID = strings.TrimSpace(input.FromUser)
	}
	if fromID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "from_user is required"})
		return
	}

	fromObjID, err := primitive.ObjectIDFromHex(fromID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid sender id"})
		return
	}

	toObjID, err := primitive.ObjectIDFromHex(input.ToUser)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
		return
	}

	notification := models.Notification{
		FromUser:  fromObjID,
		ToUser:    toObjID,
		Message:   message,
		CreatedAt: time.Now().Unix(),
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	result, err := a.Store.Notifications.InsertOne(ctx, notification)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create notification"})
		return
	}
	if oid, ok := result.InsertedID.(primitive.ObjectID); ok {
		notification.ID = oid
	}

	c.JSON(http.StatusOK, notification)
}

func (a *App) handleGetMyNotifications(c *gin.Context) {

	userID := ""
	if userValue, ok := c.Get("user"); ok {
		if authUser, ok := userValue.(AuthUser); ok && strings.TrimSpace(authUser.ID) != "" {
			userID = authUser.ID
		}
	}
	if userID == "" {
		userID = strings.TrimSpace(c.Query("to_user"))
		if userID == "" {
			userID = strings.TrimSpace(c.Query("userId"))
		}
	}
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "to_user is required"})
		return
	}

	userObjID, err := primitive.ObjectIDFromHex(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
		return
	}

	filter := bson.M{"to_user": userObjID}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	cursor, err := a.Store.Notifications.Find(ctx, filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch"})
		return
	}
	defer cursor.Close(ctx)

	var notifications []models.Notification

	for cursor.Next(ctx) {
		var notification models.Notification
		if err := cursor.Decode(&notification); err == nil {
			notifications = append(notifications, notification)
		}
	}

	fromIDs := make([]primitive.ObjectID, 0, len(notifications))
	for _, notification := range notifications {
		if notification.FromUser != primitive.NilObjectID {
			fromIDs = append(fromIDs, notification.FromUser)
		}
	}

	userMap, err := fetchUserMap(ctx, a.Store.Users, fromIDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	response := make([]gin.H, 0, len(notifications))
	for _, notification := range notifications {
		fromValue := interface{}(notification.FromUser)
		if user, ok := userMap[notification.FromUser]; ok {
			fromValue = user
		}
		response = append(response, gin.H{
			"_id":        notification.ID,
			"from_user":  fromValue,
			"to_user":    notification.ToUser,
			"message":    notification.Message,
			"created_at": notification.CreatedAt,
		})
	}

	c.JSON(http.StatusOK, response)
}

func (a *App) handleDeleteNotification(c *gin.Context) {
	rawID := strings.TrimSpace(c.Param("id"))
	if rawID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid notification id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var res *mongo.DeleteResult
	var err error

	if objectID, parseErr := primitive.ObjectIDFromHex(rawID); parseErr == nil {
		res, err = a.Store.Notifications.DeleteOne(ctx, bson.M{"_id": objectID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		if res.DeletedCount > 0 {
			c.JSON(http.StatusOK, gin.H{"success": true})
			return
		}
	}

	res, err = a.Store.Notifications.DeleteOne(ctx, bson.M{"_id": rawID})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if res.DeletedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "notification not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}
