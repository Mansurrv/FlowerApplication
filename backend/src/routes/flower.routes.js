const router = require("express").Router();
const Flower = require("../models/Flower");
const Category = require("../models/Category");
const { applyQueryOptions, buildPaginationMeta } = require("../utils/query");

router.post("/", async (req, res) => {
  try {
    const flower = await Flower.create(req.body);
    res.status(201).json(flower);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get("/", async (req, res, next) => {
  try {
    const {
      q,
      categoryId,
      floristId,
      city,
      available,
      minPrice,
      maxPrice,
    } = req.query;
    const filter = {};

    if (q && String(q).trim().length > 0) {
      filter.$or = [
        { name: { $regex: String(q), $options: "i" } },
        { description: { $regex: String(q), $options: "i" } },
      ];
    }

    if (categoryId) {
      filter.categoryId = categoryId;
    }

    if (floristId) {
      filter.floristId = floristId;
    }

    if (city) {
      filter.city = city;
    }

    if (available !== undefined) {
      filter.available = String(available) === "true";
    }

    if (minPrice || maxPrice) {
      filter.price = {};
      if (minPrice) filter.price.$gte = Number(minPrice);
      if (maxPrice) filter.price.$lte = Number(maxPrice);
    }

    const baseQuery = Flower.find(filter)
      .populate("categoryId", "name")
      .populate("floristId", "name shopName city");

    const { query, pagination } = applyQueryOptions(baseQuery, req.query, {
      defaultSort: "-createdAt",
    });

    const flowers = await query;

    if (pagination) {
      const total = await Flower.countDocuments(filter);
      return res.json({
        data: flowers,
        pagination: buildPaginationMeta(total, pagination.page, pagination.limit),
      });
    }

    res.json(flowers);
  } catch (err) {
    next(err);
  }
});

router.get("/search/advanced", async (req, res, next) => {
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
    next(error);
  }
});

router.get("/popular", async (req, res, next) => {
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
    next(error);
  }
});

router.get("/search", async (req, res, next) => {
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
    next(error);
  }
});

router.get("/popular", async (req, res, next) => {
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
    next(error);
  }
});

router.get("/category/:categoryId", async (req, res, next) => {
  try {
    const filter = { categoryId: req.params.categoryId };
    const baseQuery = Flower.find(filter);
    const { query, pagination } = applyQueryOptions(baseQuery, req.query, {
      defaultSort: "-createdAt",
    });
    const flowers = await query;

    if (pagination) {
      const total = await Flower.countDocuments(filter);
      return res.json({
        data: flowers,
        pagination: buildPaginationMeta(total, pagination.page, pagination.limit),
      });
    }

    res.json(flowers);
  } catch (err) {
    next(err);
  }
});

router.get("/city/:city", async (req, res, next) => {
  try {
    const filter = { city: req.params.city };
    const baseQuery = Flower.find(filter);
    const { query, pagination } = applyQueryOptions(baseQuery, req.query, {
      defaultSort: "-createdAt",
    });
    const flowers = await query;

    if (pagination) {
      const total = await Flower.countDocuments(filter);
      return res.json({
        data: flowers,
        pagination: buildPaginationMeta(total, pagination.page, pagination.limit),
      });
    }

    res.json(flowers);
  } catch (err) {
    next(err);
  }
});

router.put("/:id", async (req, res, next) => {
  try {
    const flower = await Flower.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );
    res.json(flower);
  } catch (err) {
    next(err);
  }
});

router.delete("/:id", async (req, res, next) => {
  try {
    await Flower.findByIdAndDelete(req.params.id);
    res.json({ message: "Flower deleted" });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
