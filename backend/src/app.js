const express = require("express");
const cors = require("cors");

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
const connectionRoutes = require("./routes/connection.routes")
const floristRoutes = require('./routes/florist.routes');
const adminRoutes = require("./routes/admin.routes");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.send("Flower Shop API is running");
});

app.use("/api/cities", cityRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/categories", categoryRoutes);
app.use("/api/flowers", flowerRoutes);
app.use("/api/orders", orderRoutes);
app.use("/api/users", userRoutes);
app.use("/api/favorites", favoriteRoutes);
app.use("/api/order-items", orderItemRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/routes", routeRoutes);
app.use('/api/florists', floristRoutes);
app.use("/api/connection", connectionRoutes)
app.use("/api/admin", adminRoutes);

module.exports = app;
