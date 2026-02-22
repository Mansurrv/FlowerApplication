const express = require("express");
const OrderItem = require("../models/OrderItem");
const authMiddleware = require("../middleware/authMiddleware");
const requireRole = require("../middleware/requireRole");

const router = express.Router();

router.use(authMiddleware);

router.post("/", requireRole("admin"), async (req, res) => {
  const item = await OrderItem.create(req.body);
  res.status(201).json(item);
});

router.get("/order/:orderId", requireRole("admin"), async (req, res) => {
  const items = await OrderItem.find({ orderId: req.params.orderId })
    .populate("flowerId");
  res.json(items);
});

module.exports = router;
