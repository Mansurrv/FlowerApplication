package server

import (
	"context"
	"time"

	"FlowerApplication/server/models"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

const requestTimeout = 10 * time.Second

func withTimeout(ctx context.Context) (context.Context, context.CancelFunc) {
	return context.WithTimeout(ctx, requestTimeout)
}

func uniqueObjectIDs(ids []primitive.ObjectID) []primitive.ObjectID {
	seen := make(map[primitive.ObjectID]struct{})
	result := make([]primitive.ObjectID, 0, len(ids))
	for _, id := range ids {
		if id == primitive.NilObjectID {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		result = append(result, id)
	}
	return result
}

func parseObjectID(value string) (primitive.ObjectID, bool) {
	id, err := primitive.ObjectIDFromHex(value)
	if err != nil {
		return primitive.NilObjectID, false
	}
	return id, true
}

func fetchUserMap(ctx context.Context, collection *mongo.Collection, ids []primitive.ObjectID) (map[primitive.ObjectID]models.UserLite, error) {
	ids = uniqueObjectIDs(ids)
	result := make(map[primitive.ObjectID]models.UserLite)
	if len(ids) == 0 {
		return result, nil
	}

	projection := bson.M{
		"name":         1,
		"email":        1,
		"phone":        1,
		"city":         1,
		"shopName":     1,
		"profileImage": 1,
		"lastActivity": 1,
		"vehicleType":  1,
	}

	cursor, err := collection.Find(ctx, bson.M{"_id": bson.M{"$in": ids}}, options.Find().SetProjection(projection))
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var user models.UserLite
		if err := cursor.Decode(&user); err != nil {
			return nil, err
		}
		result[user.ID] = user
	}
	return result, cursor.Err()
}

func fetchCategoryMap(ctx context.Context, collection *mongo.Collection, ids []primitive.ObjectID) (map[primitive.ObjectID]models.Category, error) {
	ids = uniqueObjectIDs(ids)
	result := make(map[primitive.ObjectID]models.Category)
	if len(ids) == 0 {
		return result, nil
	}
	cursor, err := collection.Find(ctx, bson.M{"_id": bson.M{"$in": ids}})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var category models.Category
		if err := cursor.Decode(&category); err != nil {
			return nil, err
		}
		result[category.ID] = category
	}
	return result, cursor.Err()
}

func fetchFlowerMap(ctx context.Context, collection *mongo.Collection, ids []primitive.ObjectID) (map[primitive.ObjectID]models.Flower, error) {
	ids = uniqueObjectIDs(ids)
	result := make(map[primitive.ObjectID]models.Flower)
	if len(ids) == 0 {
		return result, nil
	}
	cursor, err := collection.Find(ctx, bson.M{"_id": bson.M{"$in": ids}})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var flower models.Flower
		if err := cursor.Decode(&flower); err != nil {
			return nil, err
		}
		result[flower.ID] = flower
	}
	return result, cursor.Err()
}
