const express = require("express");
const cors = require("cors");
const path = require("path");
const swaggerUi = require("swagger-ui-express");
const YAML = require("yamljs");

const authRoutes = require("./routes/auth.routes");
const categoryRoutes = require("./routes/category.routes");
const flowerRoutes = require("./routes/flower.routes");
const orderRoutes = require("./routes/order.routes");
const userRoutes = require("./routes/user.routes");
const favoriteRoutes = require("./routes/favorite.routes");
const orderItemRoutes = require("./routes/orderItem.routes");
const paymentRoutes = require("./routes/payment.routes");
const routeRoutes = require("./routes/route.routes");
const cityRoutes = require("./routes/city.routes");
const promotionRoutes = require("./routes/promotion.routes");
const connectionRoutes = require("./routes/connection.routes")
const floristRoutes = require('./routes/florist.routes');
const adminRoutes = require("./routes/admin.routes");
const notificationRoutes = require("./routes/notification.routes");

const app = express();
const apiV1 = express.Router();

app.use(cors());
app.use(express.json());

const webRoot = path.join(__dirname, "web");
const webIndex = path.join(webRoot, "index.html");
const webAdmin = path.join(webRoot, "admin.html");
app.use("/web", express.static(webRoot));

app.get("/", (req, res) => {
  res.sendFile(webIndex);
});

app.get("/admin", (req, res) => {
  res.sendFile(webAdmin);
});

const uiRoot = path.join(__dirname, "..", "..", "golang", "ui");
const uiStatic = path.join(uiRoot, "static");
const uiIndex = path.join(uiRoot, "html", "index.html");

app.use("/static", express.static(uiStatic));
app.get("/wishlist", (req, res) => {
  res.sendFile(uiIndex);
});
app.get("/wishlist/", (req, res) => {
  res.sendFile(uiIndex);
});

const authTestPage = path.join(__dirname, "index.html");
app.get("/auth-test", (req, res) => {
  res.sendFile(authTestPage);
});

const openapiPath = path.join(__dirname, "docs", "openapi.yaml");
try {
  const openapiDocument = YAML.load(openapiPath);
  app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(openapiDocument));
} catch (error) {
  
  console.warn("OpenAPI spec not loaded:", error.message);
}

apiV1.use("/cities", cityRoutes);
apiV1.use("/promotions", promotionRoutes);
apiV1.use("/auth", authRoutes);
apiV1.use("/categories", categoryRoutes);
apiV1.use("/flowers", flowerRoutes);
apiV1.use("/orders", orderRoutes);
apiV1.use("/users", userRoutes);
apiV1.use("/favorites", favoriteRoutes);
apiV1.use("/order-items", orderItemRoutes);
apiV1.use("/payments", paymentRoutes);
apiV1.use("/routes", routeRoutes);
apiV1.use("/florists", floristRoutes);
apiV1.use("/connection", connectionRoutes);
apiV1.use("/admin", adminRoutes);
apiV1.use("/notifications", notificationRoutes);


app.use("/api/v1", apiV1);
app.use("/api", apiV1);

const { notFound, errorHandler } = require("./middleware/errorHandler");

app.use(notFound);
app.use(errorHandler);

module.exports = app;
