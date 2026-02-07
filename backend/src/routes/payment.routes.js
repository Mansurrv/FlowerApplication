const express = require("express");
const Payment = require("../models/Payment");

const router = express.Router();

router.post("/", async (req, res) => {
  const payment = await Payment.create(req.body);
  res.status(201).json(payment);
});

router.get("/order/:orderId", async (req, res) => {
  const payments = await Payment.find({ orderId: req.params.orderId });
  res.json(payments);
});

module.exports = router;
