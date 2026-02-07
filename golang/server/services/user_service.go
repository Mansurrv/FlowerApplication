package services

import (
	"FlowerApplication/server/structs"
	"errors"
)

func createUser(user structs.User) error {
	if user.Email == "" {
		return errors.New("email is required")
	}
	return nil
}
