package repo

import (
	"FlowerApplication/server/structs"
	"context"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

type AdminRepo struct {
	Collection *mongo.Collection
}

func (r *AdminRepo) Create(context context.Context, admin *structs.Admin) error {
	_, err := r.Collection.InsertOne(context, admin)
	return err
}

func (r *AdminRepo) FindByUserID(context context.Context, userID primitive.ObjectID) (*structs.Admin, error) {
	var admin structs.Admin
	err := r.Collection.FindOne(context, bson.M{"user_id": userID}).Decode(&admin)
	if err != nil {
		return nil, err
	}
	return &admin, nil
}

func (r *AdminRepo) DeleteById(context context.Context, id primitive.ObjectID) error {
	_, err := r.Collection.DeleteOne(context, bson.M{"_id": id})
	return err
}

func (r *AdminRepo) GetAll(context context.Context) ([]structs.Admin, error) {
	cursor, err := r.Collection.Find(context, bson.M{})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(context)

	var admins []structs.Admin
	for cursor.Next(context) {
		var admin structs.Admin
		err := cursor.Decode(&admin)
		if err != nil {
			return nil, err
		}
		admins = append(admins, admin)
	}
	return admins, nil
}
