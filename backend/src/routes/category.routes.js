const router = require("express").Router();
const Category = require("../models/Category");
const { applyQueryOptions, buildPaginationMeta } = require("../utils/query");
const authMiddleware = require("../middleware/authMiddleware");
const requireRole = require("../middleware/requireRole");

router.post("/", authMiddleware, requireRole("admin"), async (req, res) => {
  try {
    const category = await Category.create(req.body);
    res.status(201).json(category);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get("/", async (req, res, next) => {
  try {
    const { query, pagination } = applyQueryOptions(Category.find(), req.query, {
      defaultSort: "name",
    });
    const categories = await query;

    if (pagination) {
      const total = await Category.countDocuments();
      return res.json({
        data: categories,
        pagination: buildPaginationMeta(total, pagination.page, pagination.limit),
      });
    }

    res.json(categories);
  } catch (err) {
    next(err);
  }
});

router.get("/:id", async (req, res) => {
  const category = await Category.findById(req.params.id);
  if (!category) return res.status(404).json({ message: "Not found" });
  res.json(category);
});

router.put("/:id", authMiddleware, requireRole("admin"), async (req, res) => {
  try {
    const category = await Category.findByIdAndUpdate(
      req.params.id,
      { name: req.body.name },
      { new: true, runValidators: true }
    );
    if (!category) return res.status(404).json({ message: "Not found" });
    res.json(category);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.delete("/:id", authMiddleware, requireRole("admin"), async (req, res) => {
  await Category.findByIdAndDelete(req.params.id);
  res.json({ message: "Category deleted" });
});

module.exports = router;
