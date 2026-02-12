package server

import "go.mongodb.org/mongo-driver/mongo"

type Store struct {
	DB            *mongo.Database
	Users         *mongo.Collection
	Flowers       *mongo.Collection
	Categories    *mongo.Collection
	Cities        *mongo.Collection
	Orders        *mongo.Collection
	OrderItems    *mongo.Collection
	Routes        *mongo.Collection
	Favorites     *mongo.Collection
	Promotions    *mongo.Collection
	Notifications *mongo.Collection
}

func NewStore(db *mongo.Database) *Store {
	return &Store{
		DB:            db,
		Users:         db.Collection("users"),
		Flowers:       db.Collection("flowers"),
		Categories:    db.Collection("categories"),
		Cities:        db.Collection("cities"),
		Orders:        db.Collection("orders"),
		OrderItems:    db.Collection("orderitems"),
		Routes:        db.Collection("routes"),
		Favorites:     db.Collection("favorites"),
		Promotions:    db.Collection("promotions"),
		Notifications: db.Collection("notifications"),
	}
}
