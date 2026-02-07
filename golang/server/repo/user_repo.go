package repo

import (
	"FlowerApplication/server/structs"
	"context"
	"fmt"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

type UserRepo struct {
	Collection *mongo.Collection
}

func (r *UserRepo) Create(context context.Context, user *structs.User) error {
	user.DateCreated = time.Now()
	_, err := r.Collection.InsertOne(context, user)
	return err
}

func (r *UserRepo) FindByEmail(context context.Context, email string) (*structs.User, error) {
	var user structs.User
	err := r.Collection.FindOne(context, bson.M{"email": email}).Decode(&user)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepo) FindById(context context.Context, id interface{}) (*structs.User, error) {
	var user structs.User
	err := r.Collection.FindOne(context, bson.M{"_id": id}).Decode(&user)
	if err != nil {
		fmt.Println("DEBUG: FindByID error:", err)
		fmt.Println("DEBUG: ID used:", id)
		return nil, err
	}

	return &user, nil
}

func (r *UserRepo) DeleteById(context context.Context, id interface{}) error {
	_, err := r.Collection.DeleteOne(context, bson.M{"_id": id})
	return err
}

func (r *UserRepo) UpdateById(context context.Context, id interface{}, update bson.M) error {
	_, err := r.Collection.UpdateOne(context, bson.M{"_id": id}, bson.M{"$set": update})
	return err
}
