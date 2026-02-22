package server

import (
	"context"

	"FlowerApplication/pkg/server/models"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

type flowerPopulateOptions struct {
	Category bool
	Florist  bool
}

type orderPopulateOptions struct {
	User    bool
	Florist bool
	Deliver bool
}

func (a *App) populateFlowers(ctx context.Context, flowers []models.Flower, opts flowerPopulateOptions) ([]gin.H, error) {
	categoryIDs := make([]primitive.ObjectID, 0)
	floristIDs := make([]primitive.ObjectID, 0)

	if opts.Category || opts.Florist {
		for _, flower := range flowers {
			if opts.Category && flower.CategoryID != primitive.NilObjectID {
				categoryIDs = append(categoryIDs, flower.CategoryID)
			}
			if opts.Florist && flower.FloristID != primitive.NilObjectID {
				floristIDs = append(floristIDs, flower.FloristID)
			}
		}
	}

	categoryMap := map[primitive.ObjectID]models.Category{}
	floristMap := map[primitive.ObjectID]models.UserLite{}
	var err error
	if opts.Category && len(categoryIDs) > 0 {
		categoryMap, err = fetchCategoryMap(ctx, a.Store.Categories, categoryIDs)
		if err != nil {
			return nil, err
		}
	}
	if opts.Florist && len(floristIDs) > 0 {
		floristMap, err = fetchUserMap(ctx, a.Store.Users, floristIDs)
		if err != nil {
			return nil, err
		}
	}

	response := make([]gin.H, 0, len(flowers))
	for _, flower := range flowers {
		var categoryValue interface{} = flower.CategoryID
		if flower.CategoryID == primitive.NilObjectID {
			categoryValue = nil
		}
		if opts.Category {
			if category, ok := categoryMap[flower.CategoryID]; ok {
				categoryValue = category
			}
		}

		var floristValue interface{} = flower.FloristID
		if flower.FloristID == primitive.NilObjectID {
			floristValue = nil
		}
		if opts.Florist {
			if florist, ok := floristMap[flower.FloristID]; ok {
				floristValue = florist
			}
		}

		response = append(response, gin.H{
			"_id":         flower.ID,
			"name":        flower.Name,
			"price":       flower.Price,
			"description": flower.Description,
			"image_url":   flower.ImageURL,
			"available":   flower.Available,
			"categoryId":  categoryValue,
			"floristId":   floristValue,
			"city":        flower.City,
			"createdAt":   flower.CreatedAt,
			"updatedAt":   flower.UpdatedAt,
		})
	}
	return response, nil
}

func (a *App) populateOrders(ctx context.Context, orders []models.Order, opts orderPopulateOptions) ([]gin.H, error) {
	idList := make([]primitive.ObjectID, 0)
	if opts.User || opts.Florist || opts.Deliver {
		for _, order := range orders {
			if opts.User {
				if id, ok := parseObjectID(order.UserID); ok {
					idList = append(idList, id)
				}
			}
			if opts.Florist {
				if id, ok := parseObjectID(order.FloristID); ok {
					idList = append(idList, id)
				}
			}
			if opts.Deliver {
				if id, ok := parseObjectID(order.DeliverID); ok {
					idList = append(idList, id)
				}
			}
		}
	}

	userMap := map[primitive.ObjectID]models.UserLite{}
	var err error
	if len(idList) > 0 {
		userMap, err = fetchUserMap(ctx, a.Store.Users, idList)
		if err != nil {
			return nil, err
		}
	}

	response := make([]gin.H, 0, len(orders))
	for _, order := range orders {
		userValue := interface{}(order.UserID)
		if opts.User {
			if id, ok := parseObjectID(order.UserID); ok {
				if user, ok := userMap[id]; ok {
					userValue = user
				}
			}
		}

		floristValue := interface{}(order.FloristID)
		if opts.Florist {
			if id, ok := parseObjectID(order.FloristID); ok {
				if user, ok := userMap[id]; ok {
					floristValue = user
				}
			}
		}

		deliverValue := interface{}(order.DeliverID)
		if opts.Deliver {
			if id, ok := parseObjectID(order.DeliverID); ok {
				if user, ok := userMap[id]; ok {
					deliverValue = user
				}
			}
		}

		response = append(response, gin.H{
			"_id":             order.ID,
			"userId":          userValue,
			"floristId":       floristValue,
			"deliverId":       deliverValue,
			"status":          order.Status,
			"totalPrice":      order.TotalPrice,
			"city":            order.City,
			"orderNumber":     order.OrderNumber,
			"deliveryAddress": order.DeliveryAddress,
			"items":           order.Items,
			"createdAt":       order.CreatedAt,
		})
	}

	return response, nil
}
