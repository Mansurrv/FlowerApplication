package server

import (
	"net/http"
	"strings"
	"time"

	"FlowerApplication/server/models"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"golang.org/x/crypto/bcrypt"
)

type registerRequest struct {
	Name     string `json:"name"`
	Email    string `json:"email"`
	Password string `json:"password"`
	City     string `json:"city"`
	Role     string `json:"role"`
	Phone    string `json:"phone"`
	ShopName string `json:"shopName"`
}

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type resetPasswordRequest struct {
	Email       string `json:"email"`
	NewPassword string `json:"newPassword"`
}

func (a *App) handleAuthRegister(c *gin.Context) {
	var payload registerRequest
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}

	payload.Email = strings.TrimSpace(payload.Email)
	payload.Name = strings.TrimSpace(payload.Name)
	if payload.Name == "" || payload.Email == "" || payload.Password == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Validation error"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var existing models.User
	err := a.Store.Users.FindOne(ctx, bson.M{"email": payload.Email}).Decode(&existing)
	if err == nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "User already exists"})
		return
	}
	if err != nil && err != mongo.ErrNoDocuments {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(payload.Password), 10)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Failed to hash password"})
		return
	}

	role := strings.TrimSpace(payload.Role)
	if role == "" {
		role = "user"
	}

	user := models.User{
		Name:         payload.Name,
		Email:        payload.Email,
		Password:     string(hashed),
		Role:         role,
		City:         strings.TrimSpace(payload.City),
		Phone:        strings.TrimSpace(payload.Phone),
		ShopName:     strings.TrimSpace(payload.ShopName),
		Status:       "active",
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
		Rating:       0,
		TotalReviews: 0,
	}

	result, err := a.Store.Users.InsertOne(ctx, user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	userID := ""
	if oid, ok := result.InsertedID.(interface{ Hex() string }); ok {
		userID = oid.Hex()
	}

	c.JSON(http.StatusCreated, gin.H{
		"message": "User registered successfully",
		"user": gin.H{
			"id":       userID,
			"name":     user.Name,
			"email":    user.Email,
			"role":     user.Role,
			"city":     user.City,
			"phone":    user.Phone,
			"shopName": user.ShopName,
		},
	})
}

func (a *App) handleAuthLogin(c *gin.Context) {
	var payload loginRequest
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}

	payload.Email = strings.TrimSpace(payload.Email)
	payload.Password = strings.TrimSpace(payload.Password)
	if payload.Email == "" || payload.Password == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid credentials"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var user models.User
	err := a.Store.Users.FindOne(ctx, bson.M{"email": payload.Email}).Decode(&user)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	if bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(payload.Password)) != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Wrong password"})
		return
	}

	claims := authClaims{
		ID:   user.ID.Hex(),
		Role: user.Role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(7 * 24 * time.Hour)),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(a.JWTSecret)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Failed to sign token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token": tokenString,
		"user": gin.H{
			"id":    user.ID.Hex(),
			"name":  user.Name,
			"email": user.Email,
			"role":  user.Role,
			"city":  user.City,
		},
	})
}

func (a *App) handleResetPassword(c *gin.Context) {
	var payload resetPasswordRequest
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}

	payload.Email = strings.TrimSpace(payload.Email)
	if payload.Email == "" || payload.NewPassword == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Email and new password are required"})
		return
	}

	ctx, cancel := withTimeout(c.Request.Context())
	defer cancel()

	var user models.User
	err := a.Store.Users.FindOne(ctx, bson.M{"email": payload.Email}).Decode(&user)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(payload.NewPassword), 10)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Failed to hash password"})
		return
	}

	_, err = a.Store.Users.UpdateByID(ctx, user.ID, bson.M{
		"$set": bson.M{
			"password":  string(hashed),
			"updatedAt": time.Now(),
		},
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Password updated successfully"})
}
