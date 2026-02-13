const express = require("express");
const Route = require("../models/Route");
const authMiddleware = require("../middleware/authMiddleware");
const requireRole = require("../middleware/requireRole");

const router = express.Router();

router.use(authMiddleware);

router.post("/", requireRole("admin"), async (req, res) => {
  const route = await Route.create(req.body);
  res.status(201).json(route);
});

router.get("/order/:orderId", requireRole("admin"), async (req, res) => {
  const route = await Route.findOne({ orderId: req.params.orderId });
  res.json(route);
});

module.exports = router;
