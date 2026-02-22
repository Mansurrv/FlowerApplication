const express = require("express");
const mongoose = require("mongoose");
const Notification = require("../models/Notification");
const User = require("../models/User");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

const isValidObjectId = (value) =>
  mongoose.Types.ObjectId.isValid(String(value));

router.use(authMiddleware);

router.post("/", async (req, res) => {
  try {
    const message = String(req.body.message || "").trim();
    if (!message) {
      return res.status(400).json({ error: "message is required" });
    }

    const fromUser = String(req.user.id || "").trim();
    if (!fromUser) {
      return res.status(400).json({ error: "from_user is required" });
    }
    if (!isValidObjectId(fromUser)) {
      return res.status(400).json({ error: "invalid sender id" });
    }

    const toUser = String(req.body.to_user || req.body.toUser || "").trim();
    if (!toUser) {
      return res.status(400).json({ error: "to_user is required" });
    }
    if (!isValidObjectId(toUser)) {
      return res.status(400).json({ error: "invalid user id" });
    }

    const notification = await Notification.create({
      from_user: fromUser,
      to_user: toUser,
      message,
      created_at: Math.floor(Date.now() / 1000),
    });

    res.status(200).json(notification);
  } catch (err) {
    res.status(500).json({ error: "failed to create notification" });
  }
});

router.get("/", async (req, res) => {
  try {
    let userId = String(
      req.query.to_user || req.query.userId || req.query.toUser || "",
    ).trim();
    if (!userId) {
      userId = String(req.user.id || "").trim();
    }

    if (!userId) {
      return res.status(400).json({ error: "to_user is required" });
    }
    if (!isValidObjectId(userId)) {
      return res.status(400).json({ error: "invalid user id" });
    }
    if (req.user.role !== "admin" && String(req.user.id) !== String(userId)) {
      return res.status(403).json({ error: "forbidden" });
    }

    const notifications = await Notification.find({ to_user: userId }).lean();

    const fromIds = Array.from(
      new Set(
        notifications
          .map((notification) =>
            notification.from_user ? notification.from_user.toString() : "",
          )
          .filter(Boolean),
      ),
    );

    let userMap = {};
    if (fromIds.length > 0) {
      const users = await User.find({ _id: { $in: fromIds } })
        .select(
          "name email phone city shopName profileImage lastActivity vehicleType",
        )
        .lean();

      userMap = users.reduce((acc, user) => {
        acc[user._id.toString()] = user;
        return acc;
      }, {});
    }

    const response = notifications.map((notification) => {
      const fromKey = notification.from_user
        ? notification.from_user.toString()
        : "";
      return {
        _id: notification._id,
        from_user: fromKey && userMap[fromKey] ? userMap[fromKey] : notification.from_user,
        to_user: notification.to_user,
        message: notification.message,
        created_at: notification.created_at,
      };
    });

    res.status(200).json(response);
  } catch (err) {
    res.status(500).json({ error: "failed to fetch" });
  }
});

router.delete("/:id", async (req, res) => {
  const rawId = String(req.params.id || "").trim();
  if (!rawId) {
    return res.status(400).json({ error: "invalid notification id" });
  }

  try {
    if (isValidObjectId(rawId)) {
      const existing = await Notification.findById(rawId);
      if (!existing) {
        return res.status(404).json({ error: "notification not found" });
      }
      if (req.user.role !== "admin" && String(existing.to_user) !== String(req.user.id)) {
        return res.status(403).json({ error: "forbidden" });
      }
      await Notification.findByIdAndDelete(rawId);
      return res.status(200).json({ success: true });
    }

    const existingRaw = await Notification.findOne({ _id: rawId });
    if (existingRaw) {
      if (req.user.role !== "admin" && String(existingRaw.to_user) !== String(req.user.id)) {
        return res.status(403).json({ error: "forbidden" });
      }
    }
    const result = await Notification.collection.deleteOne({ _id: rawId });
    if (!result || result.deletedCount === 0) {
      return res.status(404).json({ error: "notification not found" });
    }

    res.status(200).json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
