const mongoose = require("mongoose");

const favoriteSchema = new mongoose.Schema(
    {
        userId: {type: mongoose.Schema.Types.ObjectId, ref: "User", required: true},
        flowerId: {type: mongoose.Schema.Types.ObjectId, ref: "Flower", required: true},
    },
    {timestamps: true}
);

favoriteSchema.index({ userId: 1, flowerId: 1 }, { unique: true });

module.exports = mongoose.model("Favorite", favoriteSchema);
