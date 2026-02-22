const express = require("express");
const Favorite = require("../models/Favorite");
const authMiddleware = require("../middleware/authMiddleware");
const requireAnyRole = require("../middleware/requireAnyRole");
const router = express.Router();

router.use(authMiddleware);

router.post("/", async (req, res) => {
  try {
    const flowerId = req.body.flowerId;
    if (!flowerId) {
      return res.status(400).json({ message: "flowerId is required" });
    }
    const favorite = await Favorite.create({
      userId: req.user.id,
      flowerId: String(flowerId),
    });
    res.status(201).json(favorite);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get("/user/:userId", requireAnyRole("user", "admin"), async (req, res) => {
  if (req.user.role === "user" && String(req.user.id) !== String(req.params.userId)) {
    return res.status(403).json({ message: "Forbidden" });
  }
  const favorites = await Favorite.find({ userId: req.params.userId })
    .populate("flowerId");
  res.json(favorites);
});

router.delete("/:id", async (req, res) => {
  const favorite = await Favorite.findById(req.params.id);
  if (!favorite) {
    return res.status(404).json({ message: "Favorite not found" });
  }
  if (req.user.role === "user" && String(favorite.userId) !== String(req.user.id)) {
    return res.status(403).json({ message: "Forbidden" });
  }
  await Favorite.findByIdAndDelete(req.params.id);
  res.json({ message: "Favorite removed" });
});

module.exports = router;
