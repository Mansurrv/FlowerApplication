const router = require("express").Router();
const Order = require("../models/Order");
const Flower = require("../models/Flower"); // Add this import

// In order.routes.js, update the POST endpoint
router.post("/", async (req, res) => {
  try {
    console.log('Creating order with data:', req.body);
    
    // Validate required fields
    if (!req.body.userId || !req.body.totalPrice || !req.body.city || !req.body.items) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    // If floristId is not provided in request, try to get it from the first item
    if (!req.body.floristId && req.body.items && req.body.items.length > 0) {
      try {
        // Get the flower details to extract floristId
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

router.get("/", async (req, res) => {
  const orders = await Order.find()
    .populate("userId", "name phone city")
    .populate("floristId", "name shopName email")
    .populate("deliverId", "name vehicleType")
    .sort({ createdAt: -1 }); // Sort by newest first

  res.json(orders);
});

// Get orders for a specific user (customer)
router.get("/user/:userId", async (req, res) => {
  const orders = await Order.find({ userId: req.params.userId })
    .populate("floristId", "name shopName")
    .sort({ createdAt: -1 });
  res.json(orders);
});

// Get orders for a specific florist - IMPROVED VERSION
router.get("/florist/:floristId", async (req, res) => {
  try {
    console.log('Fetching orders for florist:', req.params.floristId);
    
    // Find orders where floristId matches OR where items contain products from this florist
    const orders = await Order.find({
      $or: [
        { floristId: req.params.floristId },
        // You could also search in items if you store floristId there
        // { "items.floristId": req.params.floristId }
      ]
    })
    .populate("userId", "name phone email city")
    .populate("floristId", "name shopName email")
    .populate("deliverId", "name phone")
    .sort({ createdAt: -1 });
    
    console.log(`Found ${orders.length} orders for florist ${req.params.floristId}`);
    res.json(orders);
  } catch (err) {
    console.error('Error fetching florist orders:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get orders assigned to a delivery partner
router.get("/deliver/:deliverId", async (req, res) => {
  try {
    const orders = await Order.find({ deliverId: req.params.deliverId })
      .populate("userId", "name phone email city")
      .populate("floristId", "name shopName email")
      .sort({ createdAt: -1 });
    res.json(orders);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get available orders for delivery
router.get("/available", async (req, res) => {
  try {
    const orders = await Order.find({
      status: { $in: ["confirmed", "preparing", "delivering"] },
      $or: [
        { deliverId: { $exists: false } },
        { deliverId: null },
        { deliverId: "" },
      ],
    })
      .populate("userId", "name phone email city")
      .populate("floristId", "name shopName email")
      .sort({ createdAt: -1 });
    res.json(orders);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// NEW: Get orders by flower ID (useful for florists to see who ordered specific flowers)
router.get("/flower/:flowerId", async (req, res) => {
  try {
    const orders = await Order.find({
      "items.flowerId": req.params.flowerId
    })
    .populate("userId", "name phone email city")
    .populate("floristId", "name shopName email")
    .populate("deliverId", "name phone")
    .sort({ createdAt: -1 });
    
    res.json(orders);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// NEW: Get orders that need floristId to be populated (for fixing existing orders)
router.get("/fix/florist", async (req, res) => {
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
    res.status(500).json({ error: err.message });
  }
});

// NEW: Update orders to add floristId from flower data
router.put("/fix/add-florist-id", async (req, res) => {
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
          // Get the first flower to find floristId
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
    res.status(500).json({ error: err.message });
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

// Assign delivery partner to order
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

// NEW: Update order floristId
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
