const router = require("express").Router();
const Promotion = require("../models/Promotion");
const authMiddleware = require("../middleware/authMiddleware");
const requireRole = require("../middleware/requireRole");

router.get("/", async (req, res) => {
  try {
    const includeAll = String(req.query.all || "") === "true";
    const filter = includeAll ? {} : { isActive: true };
    const promotions = await Promotion.find(filter).sort({
      sortOrder: 1,
      createdAt: -1,
    });
    res.json(promotions);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.post("/", authMiddleware, requireRole("admin"), async (req, res) => {
  try {
    const { title, subtitle, imageUrl, isActive, sortOrder } = req.body || {};

    if (!title || !imageUrl) {
      return res.status(400).json({
        message: "Title and imageUrl are required",
      });
    }

    const promotion = await Promotion.create({
      title: String(title).trim(),
      subtitle: subtitle ? String(subtitle).trim() : "",
      imageUrl: String(imageUrl).trim(),
      isActive: isActive !== undefined ? Boolean(isActive) : true,
      sortOrder: Number.isFinite(Number(sortOrder))
        ? Number(sortOrder)
        : 0,
    });

    res.status(201).json(promotion);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

router.delete(
  "/:id",
  authMiddleware,
  requireRole("admin"),
  async (req, res) => {
    try {
      const promotion = await Promotion.findByIdAndDelete(req.params.id);
      if (!promotion) {
        return res.status(404).json({ message: "Promotion not found" });
      }
      res.json({ message: "Promotion deleted" });
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  }
);

module.exports = router;
