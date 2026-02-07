package handlers

import (
	"FlowerApplication/server/repo"
	"FlowerApplication/server/structs"
	"net/http"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

type AdminHandler struct {
	Repo *repo.AdminRepo
}

func (h *AdminHandler) CreateAdmin(context *gin.Context) {
	var admin structs.Admin
	err := context.ShouldBindJSON(&admin)
	if err != nil {
		context.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userID, err := primitive.ObjectIDFromHex(context.PostForm("user_id"))
	if err != nil {
		context.JSON(http.StatusBadRequest, gin.H{"error": "invalid user_id"})
		return
	}
	admin.UserID = userID

	err = h.Repo.Create(context.Request.Context(), &admin)
	if err != nil {
		context.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create admin"})
		return
	}

	context.JSON(http.StatusCreated, admin)
}

func (h *AdminHandler) GetAllAdmins(c *gin.Context) {
	admins, err := h.Repo.GetAll(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch admins"})
		return
	}
	c.JSON(http.StatusOK, admins)
}
