package server

import "github.com/gin-gonic/gin"

type App struct {
	Store     *Store
	JWTSecret []byte
	Env       string
}

func NewApp(store *Store, jwtSecret []byte, env string) *App {
	return &App{
		Store:     store,
		JWTSecret: jwtSecret,
		Env:       env,
	}
}

func (a *App) Router() *gin.Engine {
	if a.Env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery(), a.corsMiddleware())

	r.GET("/", func(c *gin.Context) {
		c.String(200, "Flower Shop API is running")
	})

	api := r.Group("/api")
	v1 := r.Group("/api/v1")

	a.registerRoutes(api)
	a.registerRoutes(v1)

	r.NoRoute(func(c *gin.Context) {
		c.JSON(404, gin.H{"message": "Not Found - " + c.Request.URL.Path})
	})

	return r
}

func (a *App) registerRoutes(rg *gin.RouterGroup) {
	auth := rg.Group("/auth")
	auth.POST("/register", a.handleAuthRegister)
	auth.POST("/login", a.handleAuthLogin)
	auth.POST("/reset-password", a.handleResetPassword)

	categories := rg.Group("/categories")
	categories.POST("/", a.handleCreateCategory)
	categories.GET("/", a.handleListCategories)
	categories.GET("/:id", a.handleGetCategory)
	categories.DELETE("/:id", a.handleDeleteCategory)

	cities := rg.Group("/cities")
	cities.GET("/", a.handleListCities)
	cities.POST("/", a.handleCreateCity)

	flowers := rg.Group("/flowers")
	flowers.POST("/", a.handleCreateFlower)
	flowers.GET("/", a.handleListFlowers)
	flowers.GET("/search/advanced", a.handleAdvancedFlowerSearch)
	flowers.GET("/search", a.handleFlowerSearch)
	flowers.GET("/popular", a.handlePopularFlowers)
	flowers.GET("/category/:categoryId", a.handleFlowersByCategory)
	flowers.GET("/city/:city", a.handleFlowersByCity)
	flowers.PUT("/:id", a.handleUpdateFlower)
	flowers.DELETE("/:id", a.handleDeleteFlower)

	orders := rg.Group("/orders")
	orders.POST("/", a.handleCreateOrder)
	orders.GET("/", a.handleListOrders)
	orders.GET("/user/:userId", a.handleOrdersByUser)
	orders.GET("/florist/:floristId", a.handleOrdersByFlorist)
	orders.GET("/deliver/:deliverId", a.handleOrdersByDeliver)
	orders.GET("/available", a.handleAvailableOrders)
	orders.GET("/flower/:flowerId", a.handleOrdersByFlower)
	orders.GET("/fix/florist", a.handleOrdersMissingFlorist)
	orders.PUT("/fix/add-florist-id", a.handleOrdersFixFlorist)
	orders.PUT("/:id/status", a.handleUpdateOrderStatus)
	orders.PUT("/:id/assign-deliver", a.handleAssignDeliver)
	orders.PUT("/:id/florist", a.handleAssignFlorist)
	orders.DELETE("/:id", a.handleDeleteOrder)

	users := rg.Group("/users")
	users.GET("/", a.handleListUsers)
	users.GET("/:id", a.handleGetUser)
	users.PUT("/profile", a.authMiddleware(), a.handleUpdateUserProfile)

	favorites := rg.Group("/favorites")
	favorites.POST("/", a.handleCreateFavorite)
	favorites.GET("/user/:userId", a.handleFavoritesByUser)
	favorites.DELETE("/:id", a.handleDeleteFavorite)

	orderItems := rg.Group("/order-items")
	orderItems.POST("/", a.handleCreateOrderItem)
	orderItems.GET("/order/:orderId", a.handleOrderItemsByOrder)

	payments := rg.Group("/payments")
	payments.POST("/", a.handleCreatePayment)
	payments.GET("/order/:orderId", a.handlePaymentsByOrder)

	routes := rg.Group("/routes")
	routes.POST("/", a.handleCreateRoute)
	routes.GET("/order/:orderId", a.handleRouteByOrder)

	promotions := rg.Group("/promotions")
	promotions.GET("/", a.handleListPromotions)
	promotions.POST("/", a.authMiddleware(), a.requireRole("admin"), a.handleCreatePromotion)
	promotions.DELETE("/:id", a.authMiddleware(), a.requireRole("admin"), a.handleDeletePromotion)

	connections := rg.Group("/connection")
	connections.POST("/connect", a.handleConnectUser)
	connections.GET("/current/:userId", a.handleCurrentConnection)
	connections.GET("/history/:userId", a.handleConnectionHistory)
	connections.GET("/:userId", a.handleConnectionList)

	florists := rg.Group("/florists")
	florists.Use(a.authMiddleware())
	florists.GET("/profile", a.handleFloristProfile)
	florists.PUT("/profile", a.handleUpdateFloristProfile)
	florists.GET("/statistics", a.handleFloristStatistics)
	florists.GET("/flowers", a.handleFloristFlowers)
	florists.GET("/orders", a.handleFloristOrders)

	admin := rg.Group("/admin")
	admin.Use(a.authMiddleware(), a.requireRole("admin"))
	admin.GET("/users", a.handleAdminListUsers)
	admin.PATCH("/users/:id", a.handleAdminUpdateUser)
	admin.DELETE("/users/:id", a.handleAdminDeleteUser)
}
