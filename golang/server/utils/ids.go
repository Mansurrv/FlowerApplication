package utils

import "go.mongodb.org/mongo-driver/bson/primitive"

func ParseObjectID(value string) (primitive.ObjectID, error) {
	return primitive.ObjectIDFromHex(value)
}

func IsZeroObjectID(id primitive.ObjectID) bool {
	return id == primitive.NilObjectID
}
