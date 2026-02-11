const router = require("express").Router();
const Order = require("../models/Order");
const Flower = require("../models/Flower"); 
const { applyQueryOptions, buildPaginationMeta } = require("../utils/query");


router.post("/", async (req, res) => {
  try {
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

router.get("/", async (req, res, next) => {
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


router.get("/user/:userId", async (req, res, next) => {
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


router.get("/florist/:floristId", async (req, res, next) => {
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


router.get("/deliver/:deliverId", async (req, res, next) => {
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


router.get("/available", async (req, res, next) => {
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


router.get("/flower/:flowerId", async (req, res, next) => {
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


router.get("/fix/florist", async (req, res, next) => {
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


router.put("/fix/add-florist-id", async (req, res, next) => {
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
    const order = await Order.findByIdAndUpdate(
      req.params.id,
      { status: req.body.status },
      { new: true }
    );
    res.json(order);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});


router.put("/:id/assign-deliver", async (req, res) => {
  try {
    const order = await Order.findByIdAndUpdate(
      req.params.id,
      { deliverId: req.body.deliverId },
      { new: true }
    );
    res.json(order);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});


router.put("/:id/florist", async (req, res) => {
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
    await Order.findByIdAndDelete(req.params.id);
    res.json({ message: "Order deleted" });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
