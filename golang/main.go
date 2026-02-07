package main

import (
	"FlowerApplication/server/handlers"
	"FlowerApplication/server/repo"
	"context"
	"log"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func connectMongo() (*mongo.Client, context.Context) {
	context, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	_ = cancel
	client, err := mongo.Connect(context, options.Client().ApplyURI("mongodb://localhost:27017"))
	if err != nil {
		log.Fatal(err)
	}
	return client, context
}

func main() {
	client, context := connectMongo()
	defer client.Disconnect(context)
	userCollection := client.
		Database("flower_shop").
		Collection("users")

	userRepository := repo.UserRepo{
		Collection: userCollection,
	}

	userHandlerCommon := &handlers.UserHandler{UserRepoHandler: &userRepository}
	r := gin.Default()
	api := r.Group("/api")
	{
		api.POST("/users/", userHandlerCommon.CreateUser)
		api.GET("/users/email/:email", userHandlerCommon.GetUserByEmail)
		api.GET("/users/id/:id", userHandlerCommon.GetUserByID)
		api.DELETE("/users/id/:id", userHandlerCommon.DeleteUserById)
		api.PUT("/users/id/:id", userHandlerCommon.UpdateById)
	}

	adminCollection := client.Database("flower_shop").Collection("admins")
	adminRepo := &repo.AdminRepo{Collection: adminCollection}
	adminHandler := &handlers.AdminHandler{Repo: adminRepo}

	api.POST("/admins", adminHandler.CreateAdmin)
	api.GET("/admins", adminHandler.GetAllAdmins)

	log.Println("8080")
	r.Run(":8080")
}
