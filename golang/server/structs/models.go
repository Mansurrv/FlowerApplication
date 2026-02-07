package structs

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type User struct {
	ID          int       `json:"id"`
	Name        string    `json:"name"`
	Email       string    `json:"email"`
	Password    string    `json:"password"`
	Role        string    `json:"role"`
	Phone       string    `json:"phone"`
	City        string    `json:"city"`
	Address     string    `json:"address"`
	DateCreated time.Time `json:"date_created"`
}

type Admin struct {
	ID     primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	UserID primitive.ObjectID `bson:"user_id" json:"user_id"`
}

type DeliveryPerson struct {
	ID            int    `json:"id"`
	UserID        int    `json:"user_id"`
	VehicleNumber string `json:"vehicle_number"`
	VihicleType   string `json:"vehicle_type"`
	LicenseNumber string `json:"license_number"`
	Status        string `json:"status"`
}

type Florist struct {
	ID          int     `json:"id"`
	UserID      int     `json:"user_id"`
	ShopName    string  `json:"shop_name"`
	ShopAddress string  `json:"shop_address"`
	Rating      float64 `json:"rating"`
	Status      string  `json:"status"`
}

type Category struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

type Flower struct {
	ID                int     `json:"id"`
	FloristID         int     `json:"florist_id"`
	CategoryID        int     `json:"category_id"`
	Price             float64 `json:"price"`
	Description       string  `json:"description"`
	ImageURL          string  `json:"image_url"`
	AvailableQuantity int     `json:"available_quantity"`
}

type Favorite struct {
	ID       int `json:"id"`
	UserID   int `json:"user_id"`
	FlowerID int `json:"flower_id"`
}

type Order struct {
	ID               int     `json:"id"`
	UserID           int     `json:"user_id"`
	DeliveryPersonID int     `json:"delivery_person_id"`
	TotalAmount      float64 `json:"total_amount"`
	Status           string  `json:"status"`
	OrderDate        string  `json:"order_date"`
	DeliveryDate     string  `json:"delivery_date"`
	DeliveryAddress  string  `json:"delivery_address"`
}

type OrderItem struct {
	ID       int     `json:"id"`
	OrderID  int     `json:"order_id"`
	FlowerID int     `json:"flower_id"`
	Quantity int     `json:"quantity"`
	Price    float64 `json:"price"`
}

type Review struct {
	ID        int       `json:"id"`
	UserID    int       `json:"user_id"`
	FloristID int       `json:"florist_id"`
	Rating    int       `json:"rating"`
	Comment   string    `json:"comment"`
	Date      time.Time `json:"date"`
}

type Route struct {
	ID               int     `json:"id"`
	DeliveryPersonID int     `json:"delivery_person_id"`
	OrderID          int     `json:"order_id"`
	Distance         float64 `json:"distance"`
	EstimatedTime    float64 `json:"estimated_time"`
	Start_point      string  `json:"start_point"`
	End_point        string  `json:"end_point"`
	Status           string  `json:"status"`
}

type Payment struct {
	ID          int     `json:"id"`
	OrderID     int     `json:"order_id"`
	Amount      float64 `json:"amount"`
	Method      string  `json:"method"`
	Status      string  `json:"status"`
	PaymentDate string  `json:"payment_date"`
}
