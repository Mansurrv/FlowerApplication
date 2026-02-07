const router = require("express").Router();
const Flower = require("../models/Flower");

router.post("/", async (req, res) => {
  try {
    const flower = await Flower.create(req.body);
    res.status(201).json(flower);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get("/", async (req, res) => {
  const flowers = await Flower.find()
    .populate("categoryId", "name")
    .populate("floristId", "name shopName city");

  res.json(flowers);
});

router.get("/search/advanced", async (req, res) => {
  try {
    const { q, category, minPrice, maxPrice, available } = req.query;
    const query = {};

    if (q && q.trim().length > 0) {
      query.$or = [
        { name: { $regex: q, $options: "i" } },
        { description: { $regex: q, $options: "i" } }
      ];
    }

    if (category) {
      const categoryDoc = await Category.findOne({ 
        name: { $regex: new RegExp(`^${category}$`, "i") } 
      });
      if (categoryDoc) {
        query.categoryId = categoryDoc._id;
      }
    }

    if (minPrice || maxPrice) {
      query.price = {};
      if (minPrice) query.price.$gte = Number(minPrice);
      if (maxPrice) query.price.$lte = Number(maxPrice);
    }

    if (available !== undefined) {
      query.available = available === "true";
    }

    const flowers = await Flower.find(query)
      .populate("categoryId", "name")
      .populate("floristId", "shopName")
      .lean();

    res.status(200).json({
      success: true,
      count: flowers.length,
      flowers: flowers
    });
  } catch (error) {
    console.error("Advanced search error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message
    });
  }
});

router.get("/popular", async (req, res) => {
  try {
    const popularFlowers = await Flower.find({ available: true })
      .sort({ createdAt: -1 })
      .limit(10)
      .populate("categoryId", "name")
      .populate("floristId", "shopName")
      .lean();

    res.status(200).json({
      success: true,
      count: popularFlowers.length,
      flowers: popularFlowers  // Make sure this is always an array
    });
  } catch (error) {
    console.error("Popular flowers error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message
    });
  }
});

router.get("/search", async (req, res) => {
  try {
    const { q } = req.query;
    
    if (!q || q.trim().length === 0) {
      return res.status(200).json({
        success: true,
        count: 0,
        flowers: []
      });
    }

    const flowers = await Flower.find({
      $or: [
        { name: { $regex: q, $options: "i" } },
        { description: { $regex: q, $options: "i" } }
      ]
    })
      .populate("categoryId", "name")
      .populate("floristId", "shopName")
      .lean();

    res.status(200).json({
      success: true,
      count: flowers.length,
      flowers: flowers 
    });
  } catch (error) {
    console.error("Search error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message
    });
  }
});

router.get("/popular", async (req, res) => {
  try {
    const popularFlowers = await Flower.find({ available: true })
      .sort({ createdAt: -1 })
      .limit(10)
      .populate("categoryId", "name")
      .populate("floristId", "shopName")
      .lean();

    res.status(200).json({
      success: true,
      count: popularFlowers.length,
      flowers: popularFlowers 
    });
  } catch (error) {
    console.error("Popular flowers error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message
    });
  }
});

router.get("/category/:categoryId", async (req, res) => {
  const flowers = await Flower.find({
    categoryId: req.params.categoryId
  });
  res.json(flowers);
});

router.get("/city/:city", async (req, res) => {
  const flowers = await Flower.find({ city: req.params.city });
  res.json(flowers);
});

router.put("/:id", async (req, res) => {
  const flower = await Flower.findByIdAndUpdate(
    req.params.id,
    req.body,
    { new: true }
  );
  res.json(flower);
});

router.delete("/:id", async (req, res) => {
  await Flower.findByIdAndDelete(req.params.id);
  res.json({ message: "Flower deleted" });
});

module.exports = router;
