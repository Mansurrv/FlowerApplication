const express = require("express");
const Payment = require("../models/Payment");
const authMiddleware = require("../middleware/authMiddleware");
const requireRole = require("../middleware/requireRole");

const router = express.Router();

router.use(authMiddleware);

router.post("/", requireRole("admin"), async (req, res) => {
  const payment = await Payment.create(req.body);
  res.status(201).json(payment);
});

router.get("/order/:orderId", requireRole("admin"), async (req, res) => {
  const payments = await Payment.find({ orderId: req.params.orderId });
  res.json(payments);
});

module.exports = router;
