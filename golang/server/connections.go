package server

import (
	"net/http"
	"time"

	"FlowerApplication/server/models"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type connectRequest struct {
	UserID       string `json:"userId"`
	TargetUserID string `json:"targetUserId"`
}

func (a *App) handleConnectUser(c *gin.Context) {
	var payload connectRequest
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": err.Error()})
		return
	}

	userID, err := primitive.ObjectIDFromHex(payload.UserID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid userId"})
		return
	}
	targetID, err := primitive.ObjectIDFromHex(payload.TargetUserID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid targetUserId"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var user models.User
	if err := a.Store.Users.FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Пользователь не найден"})
		return
	}
	var target models.User
	if err := a.Store.Users.FindOne(ctx, bson.M{"_id": targetID}).Decode(&target); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Пользователь не найден"})
		return
	}

	if target.Role != "user" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Можно подключаться только к обычным пользователям"})
		return
	}

	var existing models.Connection
	err = a.Store.Connections.FindOne(ctx, bson.M{
		"$or": []bson.M{
			{"userId": userID, "connectedUserId": targetID},
			{"userId": targetID, "connectedUserId": userID},
		},
	}).Decode(&existing)
	if err == nil {
		message := "Запрос на подключение уже отправлен"
		showCurrent := false
		var currentPartner *models.User

		if existing.Status == "blocked" {
			message = "Подключение заблокировано"
		} else if existing.Status == "accepted" {
			showCurrent = true
			partnerID := existing.ConnectedUserID
			if existing.UserID == userID {
				partnerID = existing.ConnectedUserID
			} else {
				partnerID = existing.UserID
			}
			var partner models.User
			if err := a.Store.Users.FindOne(ctx, bson.M{"_id": partnerID}).Decode(&partner); err == nil {
				currentPartner = &partner
				message = "Вы уже подключены с " + partner.Name
			}
		}

		response := gin.H{
			"success":               false,
			"message":               message,
			"showCurrentConnection": showCurrent,
			"connectionId":          existing.ID,
		}

		if currentPartner != nil {
			response["currentPartner"] = gin.H{
				"id":   currentPartner.ID,
				"name": currentPartner.Name,
			}
		} else {
			response["currentPartner"] = nil
		}

		c.JSON(http.StatusBadRequest, response)
		return
	}
	if err != nil && err != mongo.ErrNoDocuments {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	var userActive models.Connection
	err = a.Store.Connections.FindOne(ctx, bson.M{
		"$or": []bson.M{
			{"userId": userID, "status": "accepted"},
			{"connectedUserId": userID, "status": "accepted"},
		},
	}).Decode(&userActive)
	if err == nil {
		partnerID := userActive.ConnectedUserID
		if userActive.UserID != userID {
			partnerID = userActive.UserID
		}
		var partner models.User
		_ = a.Store.Users.FindOne(ctx, bson.M{"_id": partnerID}).Decode(&partner)
		c.JSON(http.StatusBadRequest, gin.H{
			"success":               false,
			"message":               "У вас уже есть активное подключение",
			"showCurrentConnection": true,
			"currentPartner": gin.H{
				"id":           partnerID,
				"name":         partner.Name,
				"email":        partner.Email,
				"profileImage": partner.ProfileImage,
				"city":         partner.City,
			},
			"connectionId":   userActive.ID,
			"connectedSince": userActive.CreatedAt,
		})
		return
	}
	if err != nil && err != mongo.ErrNoDocuments {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	var targetActive models.Connection
	err = a.Store.Connections.FindOne(ctx, bson.M{
		"$or": []bson.M{
			{"userId": targetID, "status": "accepted"},
			{"connectedUserId": targetID, "status": "accepted"},
		},
	}).Decode(&targetActive)
	if err == nil {
		partnerID := targetActive.ConnectedUserID
		if targetActive.UserID != targetID {
			partnerID = targetActive.UserID
		}
		var partner models.User
		_ = a.Store.Users.FindOne(ctx, bson.M{"_id": partnerID}).Decode(&partner)

		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Пользователь " + target.Name + " уже подключен с " + partner.Name,
			"targetUserInfo": gin.H{
				"id":             targetID,
				"name":           target.Name,
				"currentPartner": partner.Name,
			},
		})
		return
	}
	if err != nil && err != mongo.ErrNoDocuments {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	connection := models.Connection{
		UserID:               userID,
		ConnectedUserID:      targetID,
		Status:               "accepted",
		NotificationsEnabled: true,
		LastActivity:         time.Now(),
		CreatedAt:            time.Now(),
		UpdatedAt:            time.Now(),
	}

	result, err := a.Store.Connections.InsertOne(ctx, connection)
	if err != nil {
		if writeErr, ok := err.(mongo.WriteException); ok {
			for _, we := range writeErr.WriteErrors {
				if we.Code == 11000 {
					c.JSON(http.StatusBadRequest, gin.H{
						"success": false,
						"message": "У пользователя уже есть активное подключение",
					})
					return
				}
			}
		}
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Ошибка сервера", "error": err.Error()})
		return
	}
	if oid, ok := result.InsertedID.(primitive.ObjectID); ok {
		connection.ID = oid
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"message": "Успешно подключено!",
		"data":    connection,
	})
}

func (a *App) handleCurrentConnection(c *gin.Context) {
	userID, err := primitive.ObjectIDFromHex(c.Param("userId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid userId"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var connection models.Connection
	err = a.Store.Connections.FindOne(ctx, bson.M{
		"$or": []bson.M{
			{"userId": userID, "status": "accepted"},
			{"connectedUserId": userID, "status": "accepted"},
		},
	}).Decode(&connection)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusOK, gin.H{"success": true, "data": nil, "message": "Нет активных подключений"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	userIDs := []primitive.ObjectID{connection.UserID, connection.ConnectedUserID}
	userMap, err := fetchUserMap(ctx, a.Store.Users, userIDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	isUserInitiator := connection.UserID == userID
	partnerID := connection.ConnectedUserID
	if !isUserInitiator {
		partnerID = connection.UserID
	}

	partner := userMap[partnerID]

	connectionData := gin.H{
		"id": connection.ID,
		"partner": gin.H{
			"id":           partner.ID,
			"name":         partner.Name,
			"email":        partner.Email,
			"profileImage": partner.ProfileImage,
			"city":         partner.City,
			"lastActivity": partner.LastActivity,
		},
		"status":               connection.Status,
		"notificationsEnabled": connection.NotificationsEnabled,
		"connectedSince":       connection.CreatedAt,
		"lastActivity":         connection.LastActivity,
		"initiatedByMe":        isUserInitiator,
		"previousConnections":  connection.PreviousConnections,
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": connectionData})
}

func (a *App) handleConnectionHistory(c *gin.Context) {
	userID, err := primitive.ObjectIDFromHex(c.Param("userId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid userId"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	filter := bson.M{
		"$or": []bson.M{
			{"userId": userID},
			{"connectedUserId": userID},
		},
	}

	cursor, err := a.Store.Connections.Find(ctx, filter, options.Find().SetSort(bson.D{{Key: "updatedAt", Value: -1}}))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}
	defer cursor.Close(ctx)

	var connections []models.Connection
	if err := cursor.All(ctx, &connections); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	userIDs := make([]primitive.ObjectID, 0)
	for _, conn := range connections {
		userIDs = append(userIDs, conn.UserID, conn.ConnectedUserID)
	}
	userMap, err := fetchUserMap(ctx, a.Store.Users, userIDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	history := make([]gin.H, 0, len(connections))
	for _, conn := range connections {
		partnerID := conn.ConnectedUserID
		initiatedByMe := conn.UserID == userID
		if !initiatedByMe {
			partnerID = conn.UserID
		}
		partner := userMap[partnerID]

		var disconnectedAt *time.Time
		var duration *int
		if conn.Status != "accepted" {
			updated := conn.UpdatedAt
			disconnectedAt = &updated
		} else {
			days := int(time.Since(conn.CreatedAt).Hours() / 24)
			duration = &days
		}

		history = append(history, gin.H{
			"connectionId": conn.ID,
			"partner": gin.H{
				"id":           partner.ID,
				"name":         partner.Name,
				"profileImage": partner.ProfileImage,
			},
			"status":         conn.Status,
			"connectedAt":    conn.CreatedAt,
			"disconnectedAt": disconnectedAt,
			"duration":       duration,
			"initiatedByMe":  initiatedByMe,
		})
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": history})
}

func (a *App) handleConnectionList(c *gin.Context) {
	userID, err := primitive.ObjectIDFromHex(c.Param("userId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid userId"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var connection models.Connection
	err = a.Store.Connections.FindOne(ctx, bson.M{
		"$or": []bson.M{
			{"userId": userID, "status": "accepted"},
			{"connectedUserId": userID, "status": "accepted"},
		},
	}).Decode(&connection)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusOK, gin.H{"success": true, "data": []gin.H{}})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	userIDs := []primitive.ObjectID{connection.UserID, connection.ConnectedUserID}
	userMap, err := fetchUserMap(ctx, a.Store.Users, userIDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	initiatedByMe := connection.UserID == userID
	partnerID := connection.ConnectedUserID
	if !initiatedByMe {
		partnerID = connection.UserID
	}
	partner := userMap[partnerID]

	connectionData := gin.H{
		"id":                   connection.ID,
		"userId":               partner.ID,
		"name":                 partner.Name,
		"email":                partner.Email,
		"profileImage":         partner.ProfileImage,
		"city":                 partner.City,
		"lastActivity":         connection.LastActivity,
		"connectionDate":       connection.CreatedAt,
		"notificationsEnabled": connection.NotificationsEnabled,
		"connectionId":         connection.ID,
		"initiatedByMe":        initiatedByMe,
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    []gin.H{connectionData},
	})
}
