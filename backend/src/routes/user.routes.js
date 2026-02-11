const express = require("express");
const User = require("../models/User");
const authMiddleware = require("../middleware/authMiddleware");
const { applyQueryOptions, buildPaginationMeta } = require("../utils/query");
const router = express.Router();

router.get("/", async (req, res, next) => {
  try {
    const filter = { role: "user" };
    const baseQuery = User.find(filter).select("-password");
    const { query, pagination } = applyQueryOptions(baseQuery, req.query, {
      defaultSort: "-createdAt",
    });
    const users = await query;

    if (pagination) {
      const total = await User.countDocuments(filter);
      return res.json({
        data: users,
        pagination: buildPaginationMeta(total, pagination.page, pagination.limit),
      });
    }

    res.json(users);
  } catch (error) {
    next(error);
  }
});

router.get("/:id", async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id).select("-password");
    if (!user) {
      return res.status(404).json({ message: "Пользователь не найден" });
    }
    if (user.role !== "user") {
      return res.status(403).json({ 
        message: "Доступ запрещен. Только пользователи с ролью 'user'" 
      });
    }
    res.json(user);
  } catch (error) {
    next(error);
  }
});


router.put("/profile", authMiddleware, async (req, res, next) => {
  try {
    const userId = req.user.id;
    const user = await User.findById(userId);

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const { name, city, phone } = req.body;

    if (name !== undefined) user.name = name;
    if (city !== undefined) user.city = city;
    if (phone !== undefined) user.phone = phone;

    await user.save();

    res.json({
      success: true,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        city: user.city,
        phone: user.phone,
      },
    });
  } catch (error) {
    next(error);
  }
});


module.exports = router;
