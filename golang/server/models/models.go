package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type User struct {
	ID           primitive.ObjectID `bson:"_id,omitempty" json:"_id,omitempty"`
	Name         string             `bson:"name,omitempty" json:"name,omitempty"`
	Email        string             `bson:"email,omitempty" json:"email,omitempty"`
	Password     string             `bson:"password,omitempty" json:"-"`
	Role         string             `bson:"role,omitempty" json:"role,omitempty"`
	City         string             `bson:"city,omitempty" json:"city,omitempty"`
	Phone        string             `bson:"phone,omitempty" json:"phone,omitempty"`
	ShopName     string             `bson:"shopName,omitempty" json:"shopName,omitempty"`
	Address      string             `bson:"address,omitempty" json:"address,omitempty"`
	Description  string             `bson:"description,omitempty" json:"description,omitempty"`
	Rating       float64            `bson:"rating,omitempty" json:"rating,omitempty"`
	TotalReviews int                `bson:"totalReviews,omitempty" json:"totalReviews,omitempty"`
	Status       string             `bson:"status,omitempty" json:"status,omitempty"`
	ProfileImage string             `bson:"profileImage,omitempty" json:"profileImage,omitempty"`
	LastActivity *time.Time         `bson:"lastActivity,omitempty" json:"lastActivity,omitempty"`
	VehicleType  string             `bson:"vehicleType,omitempty" json:"vehicleType,omitempty"`
	CreatedAt    time.Time          `bson:"createdAt,omitempty" json:"createdAt,omitempty"`
	UpdatedAt    time.Time          `bson:"updatedAt,omitempty" json:"updatedAt,omitempty"`
}

type UserLite struct {
	ID           primitive.ObjectID `bson:"_id,omitempty" json:"_id,omitempty"`
	Name         string             `bson:"name,omitempty" json:"name,omitempty"`
	Email        string             `bson:"email,omitempty" json:"email,omitempty"`
	Phone        string             `bson:"phone,omitempty" json:"phone,omitempty"`
	City         string             `bson:"city,omitempty" json:"city,omitempty"`
	ShopName     string             `bson:"shopName,omitempty" json:"shopName,omitempty"`
	ProfileImage string             `bson:"profileImage,omitempty" json:"profileImage,omitempty"`
	LastActivity *time.Time         `bson:"lastActivity,omitempty" json:"lastActivity,omitempty"`
	VehicleType  string             `bson:"vehicleType,omitempty" json:"vehicleType,omitempty"`
}

type Category struct {
	ID   primitive.ObjectID `bson:"_id,omitempty" json:"_id,omitempty"`
	Name string             `bson:"name,omitempty" json:"name,omitempty"`
}

type City struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"_id,omitempty"`
	Name      string             `bson:"name,omitempty" json:"name,omitempty"`
	CreatedAt time.Time          `bson:"createdAt,omitempty" json:"createdAt,omitempty"`
	UpdatedAt time.Time          `bson:"updatedAt,omitempty" json:"updatedAt,omitempty"`
}

type Flower struct {
	ID          primitive.ObjectID `bson:"_id,omitempty" json:"_id,omitempty"`
	Name        string             `bson:"name,omitempty" json:"name,omitempty"`
	Price       float64            `bson:"price,omitempty" json:"price,omitempty"`
	Description string             `bson:"description,omitempty" json:"description,omitempty"`
	ImageURL    string             `bson:"image_url,omitempty" json:"image_url,omitempty"`
	Available   bool               `bson:"available,omitempty" json:"available,omitempty"`
	CategoryID  primitive.ObjectID `bson:"categoryId,omitempty" json:"categoryId,omitempty"`
	FloristID   primitive.ObjectID `bson:"floristId,omitempty" json:"floristId,omitempty"`
	City        string             `bson:"city,omitempty" json:"city,omitempty"`
	CreatedAt   time.Time          `bson:"createdAt,omitempty" json:"createdAt,omitempty"`
	UpdatedAt   time.Time          `bson:"updatedAt,omitempty" json:"updatedAt,omitempty"`
}

type OrderItemInline struct {
	FlowerID string  `bson:"flowerId,omitempty" json:"flowerId,omitempty"`
	Quantity int     `bson:"quantity,omitempty" json:"quantity,omitempty"`
	Price    float64 `bson:"price,omitempty" json:"price,omitempty"`
}

type Order struct {
	ID              primitive.ObjectID `bson:"_id,omitempty" json:"_id,omitempty"`
	UserID          string             `bson:"userId,omitempty" json:"userId,omitempty"`
	FloristID       string             `bson:"floristId,omitempty" json:"floristId,omitempty"`
	DeliverID       string             `bson:"deliverId,omitempty" json:"deliverId,omitempty"`
	Status          string             `bson:"status,omitempty" json:"status,omitempty"`
	TotalPrice      float64            `bson:"totalPrice,omitempty" json:"totalPrice,omitempty"`
	City            string             `bson:"city,omitempty" json:"city,omitempty"`
	OrderNumber     string             `bson:"orderNumber,omitempty" json:"orderNumber,omitempty"`
	DeliveryAddress string             `bson:"deliveryAddress,omitempty" json:"deliveryAddress,omitempty"`
	Items           []OrderItemInline  `bson:"items,omitempty" json:"items,omitempty"`
	CreatedAt       time.Time          `bson:"createdAt,omitempty" json:"createdAt,omitempty"`
}

type OrderItem struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"_id,omitempty"`
	OrderID   primitive.ObjectID `bson:"orderId,omitempty" json:"orderId,omitempty"`
	FlowerID  primitive.ObjectID `bson:"flowerId,omitempty" json:"flowerId,omitempty"`
	Quantity  int                `bson:"quantity,omitempty" json:"quantity,omitempty"`
	Price     float64            `bson:"price,omitempty" json:"price,omitempty"`
	CreatedAt time.Time          `bson:"createdAt,omitempty" json:"createdAt,omitempty"`
	UpdatedAt time.Time          `bson:"updatedAt,omitempty" json:"updatedAt,omitempty"`
}

type Payment struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"_id,omitempty"`
	OrderID   primitive.ObjectID `bson:"orderId,omitempty" json:"orderId,omitempty"`
	Amount    float64            `bson:"amount,omitempty" json:"amount,omitempty"`
	Method    string             `bson:"method,omitempty" json:"method,omitempty"`
	Status    string             `bson:"status,omitempty" json:"status,omitempty"`
	PaidAt    *time.Time         `bson:"paidAt,omitempty" json:"paidAt,omitempty"`
	CreatedAt time.Time          `bson:"createdAt,omitempty" json:"createdAt,omitempty"`
	UpdatedAt time.Time          `bson:"updatedAt,omitempty" json:"updatedAt,omitempty"`
}

type Favorite struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"_id,omitempty"`
	UserID    primitive.ObjectID `bson:"userId,omitempty" json:"userId,omitempty"`
	FlowerID  primitive.ObjectID `bson:"flowerId,omitempty" json:"flowerId,omitempty"`
	CreatedAt time.Time          `bson:"createdAt,omitempty" json:"createdAt,omitempty"`
	UpdatedAt time.Time          `bson:"updatedAt,omitempty" json:"updatedAt,omitempty"`
}

type Route struct {
	ID         primitive.ObjectID `bson:"_id,omitempty" json:"_id,omitempty"`
	OrderID    primitive.ObjectID `bson:"orderId,omitempty" json:"orderId,omitempty"`
	StartPoint string             `bson:"startPoint,omitempty" json:"startPoint,omitempty"`
	EndPoint   string             `bson:"endPoint,omitempty" json:"endPoint,omitempty"`
	CreatedAt  time.Time          `bson:"createdAt,omitempty" json:"createdAt,omitempty"`
	UpdatedAt  time.Time          `bson:"updatedAt,omitempty" json:"updatedAt,omitempty"`
}

type Promotion struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"_id,omitempty"`
	Title     string             `bson:"title,omitempty" json:"title,omitempty"`
	Subtitle  string             `bson:"subtitle,omitempty" json:"subtitle,omitempty"`
	ImageURL  string             `bson:"imageUrl,omitempty" json:"imageUrl,omitempty"`
	IsActive  bool               `bson:"isActive,omitempty" json:"isActive,omitempty"`
	SortOrder int                `bson:"sortOrder,omitempty" json:"sortOrder,omitempty"`
	CreatedAt time.Time          `bson:"createdAt,omitempty" json:"createdAt,omitempty"`
	UpdatedAt time.Time          `bson:"updatedAt,omitempty" json:"updatedAt,omitempty"`
}

type ConnectionHistory struct {
	UserID         primitive.ObjectID `bson:"userId,omitempty" json:"userId,omitempty"`
	ConnectedAt    *time.Time         `bson:"connectedAt,omitempty" json:"connectedAt,omitempty"`
	DisconnectedAt *time.Time         `bson:"disconnectedAt,omitempty" json:"disconnectedAt,omitempty"`
	Reason         string             `bson:"reason,omitempty" json:"reason,omitempty"`
}

type Connection struct {
	ID                   primitive.ObjectID  `bson:"_id,omitempty" json:"_id,omitempty"`
	UserID               primitive.ObjectID  `bson:"userId,omitempty" json:"userId,omitempty"`
	ConnectedUserID      primitive.ObjectID  `bson:"connectedUserId,omitempty" json:"connectedUserId,omitempty"`
	Status               string              `bson:"status,omitempty" json:"status,omitempty"`
	PreviousConnections  []ConnectionHistory `bson:"previousConnections,omitempty" json:"previousConnections,omitempty"`
	NotificationsEnabled bool                `bson:"notificationsEnabled,omitempty" json:"notificationsEnabled,omitempty"`
	LastActivity         time.Time           `bson:"lastActivity,omitempty" json:"lastActivity,omitempty"`
	CreatedAt            time.Time           `bson:"createdAt,omitempty" json:"createdAt,omitempty"`
	UpdatedAt            time.Time           `bson:"updatedAt,omitempty" json:"updatedAt,omitempty"`
}
