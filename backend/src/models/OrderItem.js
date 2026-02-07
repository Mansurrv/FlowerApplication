const mongoose = require("mongoose");

const orderItemSchema = new mongoose.Schema(
    {
        orderId: {type: mongoose.Schema.Types.ObjectId, ref: "Order", required: true},
        flowerId: {type: mongoose.Schema.Types.ObjectId, ref: "Flower", required: true},
        quantity: Number,
        price: Number,
    },
    {timestamps: true}
);

module.exports = mongoose.model("OrderItem", orderItemSchema);