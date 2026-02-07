const express = require("express");
const Route = require("../models/Route");

const router = express.Router();

router.post("/", async (req, res) => {
  const route = await Route.create(req.body);
  res.status(201).json(route);
});

router.get("/order/:orderId", async (req, res) => {
  const route = await Route.findOne({ orderId: req.params.orderId });
  res.json(route);
});

module.exports = router;
