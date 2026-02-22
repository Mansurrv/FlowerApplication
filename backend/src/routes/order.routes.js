const router = require("express").Router();
const Order = require("../models/Order");
const Flower = require("../models/Flower"); 
const { applyQueryOptions, buildPaginationMeta } = require("../utils/query");
const authMiddleware = require("../middleware/authMiddleware");
const requireRole = require("../middleware/requireRole");
const requireAnyRole = require("../middleware/requireAnyRole");

const isAdmin = (req) => req.user && req.user.role === "admin";

const requireSelfIfRole = (role, paramName) => (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({ message: "Unauthorized" });
  }
  if (req.user.role === role) {
    const expected = String(req.params[paramName] || "");
    const actual = String(req.user.id || "");
    if (!expected || expected !== actual) {
      return res.status(403).json({ message: "Forbidden" });
    }
  }
  next();
};

const allowedStatusByRole = {
  user: ["cancelled"],
  florist: ["confirmed", "preparing", "delivering", "cancelled"],
  deliver: ["delivering", "delivered"],
  admin: ["pending", "confirmed", "preparing", "delivering", "delivered", "cancelled"],
};

router.use(authMiddleware);


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

    console.log('Creating order with data:', req.body);
    
    
    if (!req.body.userId || !req.body.totalPrice || !req.body.city || !req.body.items) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    
    if (!req.body.floristId && req.body.items && req.body.items.length > 0) {
      try {
        
        const firstFlower = await Flower.findById(req.body.items[0].flowerId);
        if (firstFlower && firstFlower.floristId) {
          req.body.floristId = firstFlower.floristId;
          console.log('Auto-assigned floristId from flower:', req.body.floristId);
        }
      } catch (err) {
        console.log('Could not auto-assign floristId:', err.message);
      }
    }
    
    const order = await Order.create(req.body);
    console.log('Order created successfully:', order.orderNumber);
    res.status(201).json(order);
  } catch (err) {
    console.error('Order creation error:', err);
    res.status(400).json({ error: err.message });
  }
});

router.get("/", requireAnyRole("admin", "florist", "deliver"), async (req, res, next) => {
  try {
    const filter = {};

    if (req.query.status) {
      filter.status = req.query.status;
    }

    if (req.query.userId) {
      filter.userId = req.query.userId;
    }

    if (req.query.floristId) {
      filter.floristId = req.query.floristId;
    }

    if (req.query.deliverId) {
      filter.deliverId = req.query.deliverId;
    }

    if (req.user.role === "florist") {
      filter.floristId = req.user.id;
    } else if (req.user.role === "deliver") {
      filter.deliverId = req.user.id;
    }

    const baseQuery = Order.find(filter)
      .populate("userId", "name phone city")
      .populate("floristId", "name shopName email")
      .populate("deliverId", "name vehicleType");

    const { query, pagination } = applyQueryOptions(baseQuery, req.query, {
      defaultSort: "-createdAt",
    });

    const orders = await query;

    if (pagination) {
      const total = await Order.countDocuments(filter);
      return res.json({
        data: orders,
        pagination: buildPaginationMeta(total, pagination.page, pagination.limit),
      });
    }

    res.json(orders);
  } catch (err) {
    next(err);
  }
});


router.get(
  "/user/:userId",
  requireAnyRole("user", "admin"),
  requireSelfIfRole("user", "userId"),
  async (req, res, next) => {
  try {
    const filter = { userId: req.params.userId };
    const baseQuery = Order.find(filter)
      .populate("floristId", "name shopName");

    const { query, pagination } = applyQueryOptions(baseQuery, req.query, {
      defaultSort: "-createdAt",
    });

    const orders = await query;

    if (pagination) {
      const total = await Order.countDocuments(filter);
      return res.json({
        data: orders,
        pagination: buildPaginationMeta(total, pagination.page, pagination.limit),
      });
    }

    res.json(orders);
  } catch (err) {
    next(err);
  }
});


router.get(
  "/florist/:floristId",
  requireAnyRole("florist", "admin"),
  requireSelfIfRole("florist", "floristId"),
  async (req, res, next) => {
  try {
    console.log('Fetching orders for florist:', req.params.floristId);
    
    
    const filter = {
      $or: [
        { floristId: req.params.floristId },
        
        
      ]
    };

    const baseQuery = Order.find(filter)
      .populate("userId", "name phone email city")
      .populate("floristId", "name shopName email")
      .populate("deliverId", "name phone");

    const { query, pagination } = applyQueryOptions(baseQuery, req.query, {
      defaultSort: "-createdAt",
    });

    const orders = await query;
    
    console.log(`Found ${orders.length} orders for florist ${req.params.floristId}`);

    if (pagination) {
      const total = await Order.countDocuments(filter);
      return res.json({
        data: orders,
        pagination: buildPaginationMeta(total, pagination.page, pagination.limit),
      });
    }

    res.json(orders);
  } catch (err) {
    console.error('Error fetching florist orders:', err);
    next(err);
  }
});


router.get(
  "/deliver/:deliverId",
  requireAnyRole("deliver", "admin"),
  requireSelfIfRole("deliver", "deliverId"),
  async (req, res, next) => {
  try {
    const filter = { deliverId: req.params.deliverId };
    const baseQuery = Order.find(filter)
      .populate("userId", "name phone email city")
      .populate("floristId", "name shopName email");

    const { query, pagination } = applyQueryOptions(baseQuery, req.query, {
      defaultSort: "-createdAt",
    });

    const orders = await query;

    if (pagination) {
      const total = await Order.countDocuments(filter);
      return res.json({
        data: orders,
        pagination: buildPaginationMeta(total, pagination.page, pagination.limit),
      });
    }

    res.json(orders);
  } catch (err) {
    next(err);
  }
});


router.get("/available", requireAnyRole("deliver", "admin"), async (req, res, next) => {
  try {
    const filter = {
      status: { $in: ["confirmed", "preparing", "delivering"] },
      $or: [
        { deliverId: { $exists: false } },
        { deliverId: null },
        { deliverId: "" },
      ],
    };

    const baseQuery = Order.find(filter)
      .populate("userId", "name phone email city")
      .populate("floristId", "name shopName email");

    const { query, pagination } = applyQueryOptions(baseQuery, req.query, {
      defaultSort: "-createdAt",
    });

    const orders = await query;

    if (pagination) {
      const total = await Order.countDocuments(filter);
      return res.json({
        data: orders,
        pagination: buildPaginationMeta(total, pagination.page, pagination.limit),
      });
    }

    res.json(orders);
  } catch (err) {
    next(err);
  }
});


router.get(
  "/flower/:flowerId",
  requireAnyRole("florist", "admin"),
  async (req, res, next) => {
  try {
    const filter = { "items.flowerId": req.params.flowerId };

    const baseQuery = Order.find(filter)
      .populate("userId", "name phone email city")
      .populate("floristId", "name shopName email")
      .populate("deliverId", "name phone");

    const { query, pagination } = applyQueryOptions(baseQuery, req.query, {
      defaultSort: "-createdAt",
    });

    const orders = await query;
    
    if (pagination) {
      const total = await Order.countDocuments(filter);
      return res.json({
        data: orders,
        pagination: buildPaginationMeta(total, pagination.page, pagination.limit),
      });
    }
    
    res.json(orders);
  } catch (err) {
    next(err);
  }
});

// Aggregation analytics for florist dashboards (multi-stage pipeline)
router.get(
  "/analytics/florist/:floristId",
  requireAnyRole("florist", "admin"),
  requireSelfIfRole("florist", "floristId"),
  async (req, res, next) => {
  try {
    const floristId = String(req.params.floristId);

    const pipeline = [
      { $match: { floristId } },
      {
        $facet: {
          summary: [
            {
              $group: {
                _id: null,
                totalOrders: { $sum: 1 },
                totalRevenue: { $sum: "$totalPrice" },
              },
            },
            { $project: { _id: 0 } },
          ],
          byStatus: [
            {
              $group: {
                _id: "$status",
                count: { $sum: 1 },
                revenue: { $sum: "$totalPrice" },
              },
            },
            { $sort: { count: -1 } },
          ],
          topFlowers: [
            { $unwind: "$items" },
            {
              $addFields: {
                flowerObjectId: {
                  $convert: {
                    input: "$items.flowerId",
                    to: "objectId",
                    onError: null,
                    onNull: null,
                  },
                },
              },
            },
            {
              $group: {
                _id: "$flowerObjectId",
                totalQuantity: { $sum: "$items.quantity" },
                totalSales: {
                  $sum: { $multiply: ["$items.quantity", "$items.price"] },
                },
              },
            },
            { $sort: { totalQuantity: -1 } },
            { $limit: 5 },
            {
              $lookup: {
                from: "flowers",
                localField: "_id",
                foreignField: "_id",
                as: "flower",
              },
            },
            {
              $unwind: {
                path: "$flower",
                preserveNullAndEmptyArrays: true,
              },
            },
            {
              $project: {
                _id: 0,
                flowerId: "$_id",
                name: "$flower.name",
                totalQuantity: 1,
                totalSales: 1,
              },
            },
          ],
        },
      },
    ];

    const [result] = await Order.aggregate(pipeline);
    const summary = (result && result.summary && result.summary[0]) || {
      totalOrders: 0,
      totalRevenue: 0,
    };

    res.json({
      floristId,
      summary,
      byStatus: result?.byStatus || [],
      topFlowers: result?.topFlowers || [],
    });
  } catch (err) {
    next(err);
  }
});

// Advanced updates on embedded items using $push/$pull/$inc/$set and positional operator
router.post("/:id/items", async (req, res) => {
  try {
    if (!req.user || !["user", "admin"].includes(req.user.role)) {
      return res.status(403).json({ message: "Forbidden" });
    }
    const { flowerId, quantity, price } = req.body;
    const qty = Number(quantity);
    const unitPrice = Number(price);

    if (!flowerId || !Number.isFinite(qty) || qty <= 0 || !Number.isFinite(unitPrice)) {
      return res.status(400).json({ message: "flowerId, quantity (>0), and price are required" });
    }

    const existing = await Order.findById(req.params.id);
    if (!existing) {
      return res.status(404).json({ message: "Order not found" });
    }
    if (req.user.role === "user") {
      if (String(existing.userId) !== String(req.user.id)) {
        return res.status(403).json({ message: "Forbidden" });
      }
      if (existing.status !== "pending") {
        return res.status(400).json({ message: "Only pending orders can be modified" });
      }
    }

    const order = await Order.findByIdAndUpdate(
      req.params.id,
      {
        $push: {
          items: {
            flowerId: String(flowerId),
            quantity: qty,
            price: unitPrice,
          },
        },
        $inc: {
          totalPrice: qty * unitPrice,
        },
      },
      { new: true }
    );

    if (!order) {
      return res.status(404).json({ message: "Order not found" });
    }

    res.json(order);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.patch("/:id/items/:flowerId", async (req, res) => {
  try {
    if (!req.user || !["user", "admin"].includes(req.user.role)) {
      return res.status(403).json({ message: "Forbidden" });
    }
    const updates = {};
    if (req.body.quantity !== undefined) {
      const qty = Number(req.body.quantity);
      if (!Number.isFinite(qty) || qty <= 0) {
        return res.status(400).json({ message: "quantity must be a positive number" });
      }
      updates["items.$.quantity"] = qty;
    }
    if (req.body.price !== undefined) {
      const unitPrice = Number(req.body.price);
      if (!Number.isFinite(unitPrice) || unitPrice < 0) {
        return res.status(400).json({ message: "price must be a non-negative number" });
      }
      updates["items.$.price"] = unitPrice;
    }

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ message: "Provide quantity and/or price to update" });
    }

    const existing = await Order.findById(req.params.id);
    if (!existing) {
      return res.status(404).json({ message: "Order not found" });
    }
    if (req.user.role === "user") {
      if (String(existing.userId) !== String(req.user.id)) {
        return res.status(403).json({ message: "Forbidden" });
      }
      if (existing.status !== "pending") {
        return res.status(400).json({ message: "Only pending orders can be modified" });
      }
    }

    const order = await Order.findOneAndUpdate(
      { _id: req.params.id, "items.flowerId": String(req.params.flowerId) },
      { $set: updates },
      { new: true }
    );

    if (!order) {
      return res.status(404).json({ message: "Order or item not found" });
    }

    res.json(order);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.delete("/:id/items/:flowerId", async (req, res) => {
  try {
    if (!req.user || !["user", "admin"].includes(req.user.role)) {
      return res.status(403).json({ message: "Forbidden" });
    }
    const order = await Order.findOne(
      { _id: req.params.id, "items.flowerId": String(req.params.flowerId) },
      { items: 1, totalPrice: 1, userId: 1, status: 1 }
    );

    if (!order) {
      return res.status(404).json({ message: "Order or item not found" });
    }

    if (req.user.role === "user") {
      if (String(order.userId) !== String(req.user.id)) {
        return res.status(403).json({ message: "Forbidden" });
      }
      if (order.status !== "pending") {
        return res.status(400).json({ message: "Only pending orders can be modified" });
      }
    }

    const item = order.items.find(
      (entry) => String(entry.flowerId) === String(req.params.flowerId)
    );
    const decrement = item ? Number(item.price || 0) * Number(item.quantity || 0) : 0;

    const updated = await Order.findByIdAndUpdate(
      req.params.id,
      {
        $pull: { items: { flowerId: String(req.params.flowerId) } },
        $inc: { totalPrice: -decrement },
      },
      { new: true }
    );

    res.json(updated);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});


router.get("/fix/florist", requireRole("admin"), async (req, res, next) => {
  try {
    const orders = await Order.find({
      $or: [
        { floristId: { $exists: false } },
        { floristId: null },
        { floristId: "" }
      ]
    })
    .populate("userId", "name phone email city")
    .sort({ createdAt: -1 });
    
    res.json({
      count: orders.length,
      orders: orders,
      message: orders.length > 0 
        ? `${orders.length} orders need floristId` 
        : 'All orders have floristId'
    });
  } catch (err) {
    next(err);
  }
});


router.put("/fix/add-florist-id", requireRole("admin"), async (req, res, next) => {
  try {
    const ordersWithoutFloristId = await Order.find({
      $or: [
        { floristId: { $exists: false } },
        { floristId: null },
        { floristId: "" }
      ]
    });

    let updatedCount = 0;
    let errors = [];

    for (const order of ordersWithoutFloristId) {
      try {
        if (order.items && order.items.length > 0) {
          
          const firstFlower = await Flower.findById(order.items[0].flowerId);
          if (firstFlower && firstFlower.floristId) {
            order.floristId = firstFlower.floristId;
            await order.save();
            updatedCount++;
            console.log(`Updated order ${order._id} with floristId: ${firstFlower.floristId}`);
          }
        }
      } catch (err) {
        errors.push({ orderId: order._id, error: err.message });
      }
    }

    res.json({
      success: true,
      updated: updatedCount,
      errors: errors,
      message: `Updated ${updatedCount} orders with floristId`
    });
  } catch (err) {
    next(err);
  }
});

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


router.put("/:id/assign-deliver", async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ message: "Unauthorized" });
    }
    if (!["deliver", "admin"].includes(req.user.role)) {
      return res.status(403).json({ message: "Forbidden" });
    }

    let deliverId = req.body.deliverId;
    if (req.user.role === "deliver") {
      deliverId = req.user.id;
    }

    if (!deliverId) {
      return res.status(400).json({ message: "deliverId is required" });
    }

    const existing = await Order.findById(req.params.id);
    if (!existing) {
      return res.status(404).json({ message: "Order not found" });
    }
    if (req.user.role === "deliver" && existing.deliverId && String(existing.deliverId) !== String(req.user.id)) {
      return res.status(403).json({ message: "Forbidden" });
    }

    const order = await Order.findByIdAndUpdate(
      req.params.id,
      { deliverId: String(deliverId) },
      { new: true }
    );
    res.json(order);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});


router.put("/:id/florist", requireRole("admin"), async (req, res) => {
  try {
    const order = await Order.findByIdAndUpdate(
      req.params.id,
      { floristId: req.body.floristId },
      { new: true }
    );
    res.json(order);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.delete("/:id", async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const order = await Order.findById(req.params.id);
    if (!order) {
      return res.status(404).json({ message: "Order not found" });
    }

    if (!isAdmin(req) && req.user.role === "user" && String(order.userId) !== String(req.user.id)) {
      return res.status(403).json({ message: "Forbidden" });
    }
    if (!isAdmin(req) && req.user.role !== "user") {
      return res.status(403).json({ message: "Forbidden" });
    }

    await Order.findByIdAndDelete(req.params.id);
    res.json({ message: "Order deleted" });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
