const mongoose = require("mongoose");

const notificationSchema = new mongoose.Schema(
  {
    from_user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    to_user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    message: { type: String, required: true },
    created_at: {
      type: Number,
      default: () => Math.floor(Date.now() / 1000),
    },
  },
  { collection: "notifications" },
);

module.exports = mongoose.model("Notification", notificationSchema);
