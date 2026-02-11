const mongoose = require("mongoose");

const promotionSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true },
    subtitle: { type: String, default: "", trim: true },
    imageUrl: { type: String, required: true, trim: true },
    isActive: { type: Boolean, default: true },
    sortOrder: { type: Number, default: 0 },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Promotion", promotionSchema);
