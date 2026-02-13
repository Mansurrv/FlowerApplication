const mongoose = require("mongoose")

const flowerSchema = new mongoose.Schema({
    name: String,
    price: Number,
    description: String,
    image_url: String, 
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
  timestamps: true 
})

// Query optimization for filters and popular listings
flowerSchema.index({ categoryId: 1, available: 1, price: 1 });
flowerSchema.index({ floristId: 1, available: 1, createdAt: -1 });
flowerSchema.index({ city: 1, available: 1, createdAt: -1 });

module.exports = mongoose.model("Flower", flowerSchema)
