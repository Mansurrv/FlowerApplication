package server

import "go.mongodb.org/mongo-driver/mongo"

type Store struct {
	DB          *mongo.Database
	Users       *mongo.Collection
	Flowers     *mongo.Collection
	Categories  *mongo.Collection
	Cities      *mongo.Collection
	Orders      *mongo.Collection
	OrderItems  *mongo.Collection
	Payments    *mongo.Collection
	Routes      *mongo.Collection
	Favorites   *mongo.Collection
	Promotions  *mongo.Collection
	Connections *mongo.Collection
}

func NewStore(db *mongo.Database) *Store {
	return &Store{
		DB:          db,
		Users:       db.Collection("users"),
		Flowers:     db.Collection("flowers"),
		Categories:  db.Collection("categories"),
		Cities:      db.Collection("cities"),
		Orders:      db.Collection("orders"),
		OrderItems:  db.Collection("orderitems"),
		Payments:    db.Collection("payments"),
		Routes:      db.Collection("routes"),
		Favorites:   db.Collection("favorites"),
		Promotions:  db.Collection("promotions"),
		Connections: db.Collection("connections"),
	}
}
