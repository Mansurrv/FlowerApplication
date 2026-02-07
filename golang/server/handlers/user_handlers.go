package handlers

import (
	"FlowerApplication/server/repo"
	"FlowerApplication/server/structs"
	"net/http"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

type UserHandler struct {
	UserRepoHandler *repo.UserRepo
}

func (h *UserHandler) CreateUser(context *gin.Context) {
	var user structs.User
	err := context.ShouldBindJSON(&user)
	if err != nil {
		context.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.UserRepoHandler.Create(context.Request.Context(), &user)
	if err != nil {
		context.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	context.JSON(http.StatusCreated, user)
}

func (h *UserHandler) GetUserByEmail(context *gin.Context) {
	email := context.Param("email")
	user, err := h.UserRepoHandler.FindByEmail(context.Request.Context(), email)
	if err != nil {
		context.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
		return
	}

	context.JSON(http.StatusOK, user)
}

func (h *UserHandler) GetUserByID(context *gin.Context) {
	id := context.Param("id")
	objectID, err := primitive.ObjectIDFromHex(id)
	if err != nil {
		context.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
		return
	}

	user, err := h.UserRepoHandler.FindById(context.Request.Context(), objectID)
	if err != nil {
		context.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
		return
	}
	context.JSON(http.StatusOK, user)
}

func (h *UserHandler) DeleteUserById(context *gin.Context) {
	id := context.Param("id")
	objectID, err := primitive.ObjectIDFromHex(id)
	if err != nil {
		context.JSON(400, gin.H{"error": "invlid id"})
		return
	}

	err = h.UserRepoHandler.DeleteById(context.Request.Context(), objectID)
	if err != nil {
		context.JSON(500, gin.H{"error": "failed to delete user"})
		return
	}

	context.JSON(200, gin.H{"message": "user deleted"})
}

func (h *UserHandler) UpdateById(context *gin.Context) {
	id := context.Param("id")
	objectID, err := primitive.ObjectIDFromHex(id)
	if err != nil {
		context.JSON(400, gin.H{"error": "invalid id"})
		return
	}

	var updateData bson.M
	err = context.ShouldBindJSON(&updateData)
	if err != nil {
		context.JSON(400, gin.H{"error": err.Error()})
		return
	}

	err = h.UserRepoHandler.UpdateById(context.Request.Context(), objectID, updateData)
	if err != nil {
		context.JSON(500, gin.H{"error": "failed to update user"})
		return
	}
	context.JSON(200, gin.H{"message": "user updated"})
}
