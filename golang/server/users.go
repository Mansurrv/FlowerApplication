package server

import (
	"net/http"
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

func (a *App) handleListUsers(c *gin.Context) {
	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{"role": "user"}
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

	users := make([]models.User, 0)
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

func (a *App) handleGetUser(c *gin.Context) {
	id, err := primitive.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var user models.User
	err = a.Store.Users.FindOne(ctx, bson.M{"_id": id}, options.FindOne().SetProjection(bson.M{"password": 0})).Decode(&user)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"message": "Пользователь не найден"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	if user.Role != "user" {
		c.JSON(http.StatusForbidden, gin.H{"message": "Доступ запрещен. Только пользователи с ролью 'user'"})
		return
	}

	c.JSON(http.StatusOK, user)
}

func (a *App) handleUpdateUserProfile(c *gin.Context) {
	userValue, ok := c.Get("user")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "No token, authorization denied"})
		return
	}
	authUser, ok := userValue.(AuthUser)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "No token, authorization denied"})
		return
	}

	var payload struct {
		Name  *string `json:"name"`
		City  *string `json:"city"`
		Phone *string `json:"phone"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}

	userID, err := primitive.ObjectIDFromHex(authUser.ID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid resource id"})
		return
	}

	updates := bson.M{}
	if payload.Name != nil {
		updates["name"] = strings.TrimSpace(*payload.Name)
	}
	if payload.City != nil {
		updates["city"] = strings.TrimSpace(*payload.City)
	}
	if payload.Phone != nil {
		updates["phone"] = strings.TrimSpace(*payload.Phone)
	}
	updates["updatedAt"] = time.Now()

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

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"user": gin.H{
			"id":    user.ID.Hex(),
			"name":  user.Name,
			"email": user.Email,
			"role":  user.Role,
			"city":  user.City,
			"phone": user.Phone,
		},
	})
}
