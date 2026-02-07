const express = require("express");
const Favorite = require("../models/Favorite");
const router = express.Router();

router.post("/", async (req, res) => {
    const favorite = await Favorite.create(req.body);
    res.status(201).json(favorite);
});

router.get("/user/:userId", async (req, res) => {
  const favorites = await Favorite.find({ userId: req.params.userId })
    .populate("flowerId");
  res.json(favorites);
});

router.delete("/:id", async (req, res) => {
  await Favorite.findByIdAndDelete(req.params.id);
  res.json({ message: "Favorite removed" });
});

module.exports = router;