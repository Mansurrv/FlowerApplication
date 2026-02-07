const express = require("express");
const OrderItem = require("../models/OrderItem");

const router = express.Router();

router.post("/", async (req, res) => {
  const item = await OrderItem.create(req.body);
  res.status(201).json(item);
});

router.get("/order/:orderId", async (req, res) => {
  const items = await OrderItem.find({ orderId: req.params.orderId })
    .populate("flowerId");
  res.json(items);
});

module.exports = router;
