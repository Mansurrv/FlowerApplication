const router = require("express").Router();
const Promotion = require("../models/Promotion");
const authMiddleware = require("../middleware/authMiddleware");
const requireRole = require("../middleware/requireRole");
const { applyQueryOptions, buildPaginationMeta } = require("../utils/query");

router.get("/", async (req, res, next) => {
  try {
    const includeAll = String(req.query.all || "") === "true";
    const filter = includeAll ? {} : { isActive: true };
    const baseQuery = Promotion.find(filter);
    const { query, pagination } = applyQueryOptions(baseQuery, req.query, {
      defaultSort: "sortOrder -createdAt",
    });
    const promotions = await query;

    if (pagination) {
      const total = await Promotion.countDocuments(filter);
      return res.json({
        data: promotions,
        pagination: buildPaginationMeta(total, pagination.page, pagination.limit),
      });
    }

    res.json(promotions);
  } catch (err) {
    next(err);
  }
});

router.post("/", authMiddleware, requireRole("admin"), async (req, res, next) => {
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
    next(err);
  }
});

router.delete(
  "/:id",
  authMiddleware,
  requireRole("admin"),
  async (req, res, next) => {
    try {
      const promotion = await Promotion.findByIdAndDelete(req.params.id);
      if (!promotion) {
        return res.status(404).json({ message: "Promotion not found" });
      }
      res.json({ message: "Promotion deleted" });
    } catch (err) {
      next(err);
    }
  }
);

module.exports = router;
