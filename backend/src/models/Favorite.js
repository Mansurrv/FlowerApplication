const mongoose = require("mongoose");

const favoriteSchema = new mongoose.Schema(
    {
        userId: {type: mongoose.Schema.Types.ObjectId, ref: "User", required: true},
        flowerId: {type: mongoose.Schema.Types.ObjectId, ref: "Flower", required: true},
    },
    {timestamps: true}
);

module.exports = mongoose.model("Favorite", favoriteSchema);

