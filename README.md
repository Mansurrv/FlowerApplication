# FlowerApplication

This README collects the exact code pieces for compound indexes, business logic, and role control in the backend.

**Compound Indexes**
`backend/src/models/Order.js`
```js
// Query optimization for common filters and dashboards
orderSchema.index({ floristId: 1, status: 1, createdAt: -1 });
orderSchema.index({ userId: 1, createdAt: -1 });
orderSchema.index({ deliverId: 1, status: 1, createdAt: -1 });
orderSchema.index({ "items.flowerId": 1 });
```

`backend/src/models/Flower.js`
```js
// Query optimization for filters and popular listings
flowerSchema.index({ categoryId: 1, available: 1, price: 1 });
flowerSchema.index({ floristId: 1, available: 1, createdAt: -1 });
flowerSchema.index({ city: 1, available: 1, createdAt: -1 });
```

`backend/src/models/Favorite.js`
```js
favoriteSchema.index({ userId: 1, flowerId: 1 }, { unique: true });
```

`backend/src/models/Connection.js`
```js
ConnectionSchema.index({ userId: 1, connectedUserId: 1 }, { unique: true });
ConnectionSchema.index({ userId: 1, status: 'accepted' }, { unique: true });
ConnectionSchema.index({ connectedUserId: 1, status: 'accepted' }, { unique: true });
```

**Business Logic**
`backend/src/routes/order.routes.js` (order creation validation and florist auto-assign)
```js
router.post("/", async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ message: "Unauthorized" });
    }
    if (!["user", "admin"].includes(req.user.role)) {
      return res.status(403).json({ message: "Forbidden" });
    }

    if (req.user.role === "user") {
      req.body.userId = req.user.id;
    } else if (!req.body.userId) {
      req.body.userId = req.user.id;
    }

    if (!req.body.userId || !req.body.totalPrice || !req.body.city || !req.body.items) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    if (!req.body.floristId && req.body.items && req.body.items.length > 0) {
      try {
        const firstFlower = await Flower.findById(req.body.items[0].flowerId);
        if (firstFlower && firstFlower.floristId) {
          req.body.floristId = firstFlower.floristId;
        }
      } catch (err) {
        console.log("Could not auto-assign floristId:", err.message);
      }
    }

    const order = await Order.create(req.body);
    res.status(201).json(order);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});
```

`backend/src/routes/order.routes.js` (status transition rules)
```js
const allowedStatusByRole = {
  user: ["cancelled"],
  florist: ["confirmed", "preparing", "delivering", "cancelled"],
  deliver: ["delivering", "delivered"],
  admin: ["pending", "confirmed", "preparing", "delivering", "delivered", "cancelled"],
};

router.put("/:id/status", async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const status = String(req.body.status || "").toLowerCase();
    if (!status) {
      return res.status(400).json({ message: "status is required" });
    }

    const allowedStatuses = allowedStatusByRole[req.user.role] || [];
    if (!allowedStatuses.includes(status)) {
      return res.status(403).json({ message: "Forbidden" });
    }

    const order = await Order.findById(req.params.id);
    if (!order) {
      return res.status(404).json({ message: "Order not found" });
    }

    if (req.user.role === "user" && String(order.userId) !== String(req.user.id)) {
      return res.status(403).json({ message: "Forbidden" });
    }
    if (req.user.role === "florist" && String(order.floristId) !== String(req.user.id)) {
      return res.status(403).json({ message: "Forbidden" });
    }
    if (req.user.role === "deliver" && String(order.deliverId) !== String(req.user.id)) {
      return res.status(403).json({ message: "Forbidden" });
    }

    order.status = status;
    await order.save();
    res.json(order);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});
```

**Role Control**
`backend/src/middleware/authMiddleware.js`
```js
const jwt = require("jsonwebtoken");

module.exports = function(req, res, next) {
  const token = req.header("Authorization")?.replace("Bearer ", "");
  if (!token) {
    return res.status(401).json({ message: "No token, authorization denied" });
  }
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    res.status(401).json({ message: "Token is not valid" });
  }
};
```

`backend/src/middleware/requireRole.js`
```js
module.exports = function requireRole(role) {
  return (req, res, next) => {
    if (!req.user || req.user.role !== role) {
      return res.status(403).json({ message: "Forbidden" });
    }
    next();
  };
};
```

`backend/src/middleware/requireAnyRole.js`
```js
module.exports = function requireAnyRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ message: "Forbidden" });
    }
    next();
  };
};
```

`backend/src/routes/category.routes.js` (admin-only routes)
```js
router.post("/", authMiddleware, requireRole("admin"), async (req, res) => {
  try {
    const category = await Category.create(req.body);
    res.status(201).json(category);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});
```

`backend/src/routes/flower.routes.js` (florist/admin routes)
```js
router.post("/", authMiddleware, requireAnyRole("florist", "admin"), async (req, res) => {
  try {
    if (req.user.role === "florist") {
      req.body.floristId = req.user.id;
    }
    const flower = await Flower.create(req.body);
    res.status(201).json(flower);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});
```
