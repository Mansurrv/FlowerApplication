package main

import (
	"FlowerApplication/server"
	"context"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"go.mongodb.org/mongo-driver/mongo/readpref"
	"go.mongodb.org/mongo-driver/x/mongo/driver/connstring"
)

func loadEnvFile(path string) {
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		value = strings.Trim(value, `"'`)
		if os.Getenv(key) == "" {
			_ = os.Setenv(key, value)
		}
	}
}

func extractDatabaseName(uri string) string {
	cs, err := connstring.Parse(uri)
	if err != nil {
		return ""
	}
	return cs.Database
}

func connectMongo(uri string) (*mongo.Client, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, options.Client().ApplyURI(uri))
	if err != nil {
		return nil, err
	}

	if err := client.Ping(ctx, readpref.Primary()); err != nil {
		return nil, err
	}

	log.Printf("MongoDB connected")
	return client, nil
}

func main() {
	cwd, _ := os.Getwd()
	loadEnvFile(filepath.Join(cwd, ".env"))
	loadEnvFile(filepath.Join(cwd, "backend", ".env"))
	loadEnvFile(filepath.Join(cwd, "..", "backend", ".env"))
	loadEnvFile(filepath.Join(cwd, "..", ".env"))

	mongoURI := strings.TrimSpace(os.Getenv("MONGO_URI"))
	if mongoURI == "" {
		mongoURI = strings.TrimSpace(os.Getenv("DATABASE_URL"))
	}
	jwtSecret := strings.TrimSpace(os.Getenv("JWT_SECRET"))
	port := strings.TrimSpace(os.Getenv("PORT"))
	env := strings.TrimSpace(os.Getenv("NODE_ENV"))
	if env == "" {
		env = "development"
	}
	if port == "" {
		port = "4040"
	}
	if mongoURI == "" {
		log.Fatal("Missing required environment variable: MONGO_URI (or DATABASE_URL)")
	}
	if jwtSecret == "" {
		log.Fatal("Missing required environment variable: JWT_SECRET")
	}

	client, err := connectMongo(mongoURI)
	if err != nil {
		log.Fatal(err)
	}

	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = client.Disconnect(ctx)
	}()

	dbName := strings.TrimSpace(os.Getenv("MONGO_DB_NAME"))
	if dbName == "" {
		dbName = strings.TrimSpace(os.Getenv("DB_NAME"))
	}
	if dbName == "" {
		dbName = strings.TrimSpace(os.Getenv("DATABASE_NAME"))
	}
	if dbName == "" {
		dbName = extractDatabaseName(mongoURI)
	}
	if dbName == "" {
		dbName = "test"
	}

	store := server.NewStore(client.Database(dbName))
	app := server.NewApp(store, []byte(jwtSecret), env)

	router := app.Router()
	log.Printf("Using MongoDB database: %s", dbName)
	log.Printf("Server running on port %s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatal(err)
	}
}
