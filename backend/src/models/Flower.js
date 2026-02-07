const mongoose = require("mongoose")

const flowerSchema = new mongoose.Schema({
    name: String,
    price: Number,
    description: String,
    image_url: String, // Changed from imageUrl to image_url
    available: Boolean,

    categoryId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Category"
    },
    floristId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User"
    },

    city: String
}, {
  timestamps: true // Add timestamps
})

module.exports = mongoose.model("Flower", flowerSchema)