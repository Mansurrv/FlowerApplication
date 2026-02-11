package server

import (
	"net/http"
	"strings"

	"FlowerApplication/server/models"
	"FlowerApplication/server/utils"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func (a *App) handleAdminListUsers(c *gin.Context) {
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{}
	if role := strings.TrimSpace(c.Query("role")); role != "" {
		filter["role"] = role
	} else {
		filter["role"] = bson.M{"$ne": "admin"}
	}

	if status := strings.TrimSpace(c.Query("status")); status != "" {
		filter["status"] = status
	}

	if q := strings.TrimSpace(c.Query("q")); q != "" {
		filter["$or"] = []bson.M{
			{"name": bson.M{"$regex": q, "$options": "i"}},
			{"email": bson.M{"$regex": q, "$options": "i"}},
			{"phone": bson.M{"$regex": q, "$options": "i"}},
			{"shopName": bson.M{"$regex": q, "$options": "i"}},
		}
	}

	findOptions, pagination := utils.BuildFindOptions(c, "-createdAt")
	if c.Query("fields") == "" {
		findOptions.SetProjection(bson.M{"password": 0})
	}

	cursor, err := a.Store.Users.Find(ctx, filter, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var users []models.User
	if err := cursor.All(ctx, &users); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	if pagination != nil {
		total, err := a.Store.Users.CountDocuments(ctx, filter)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"data":       users,
			"pagination": utils.BuildPaginationMeta(total, pagination.Page, pagination.Limit),
		})
		return
	}

	c.JSON(http.StatusOK, users)
}

func (a *App) handleAdminUpdateUser(c *gin.Context) {
	userID, err := primitive.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	var payload map[string]interface{}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}

	allowedFields := map[string]bool{
		"name":        true,
		"email":       true,
		"city":        true,
		"phone":       true,
		"shopName":    true,
		"address":     true,
		"description": true,
		"status":      true,
		"role":        true,
	}

	updates := bson.M{}
	for field, value := range payload {
		if !allowedFields[field] {
			continue
		}
		updates[field] = value
	}

	if role, ok := updates["role"].(string); ok {
		validRoles := map[string]bool{"user": true, "admin": true, "florist": true, "deliver": true}
		if !validRoles[role] {
			c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid role"})
			return
		}
	}

	if status, ok := updates["status"].(string); ok {
		validStatuses := map[string]bool{"active": true, "inactive": true}
		if !validStatuses[status] {
			c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid status"})
			return
		}
	}

	if len(updates) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "No valid fields provided"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var user models.User
	err = a.Store.Users.FindOneAndUpdate(ctx, bson.M{"_id": userID}, bson.M{"$set": updates}, options.FindOneAndUpdate().SetReturnDocument(options.After).SetProjection(bson.M{"password": 0})).Decode(&user)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, user)
}

func (a *App) handleAdminDeleteUser(c *gin.Context) {
	userID := c.Param("id")
	userValue, ok := c.Get("user")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "No token, authorization denied"})
		return
	}
	authUser := userValue.(AuthUser)
	if authUser.ID == userID {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Admin cannot delete own account"})
		return
	}

	id, err := primitive.ObjectIDFromHex(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	res, err := a.Store.Users.DeleteOne(ctx, bson.M{"_id": id})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}
	if res.DeletedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "User deleted"})
}
