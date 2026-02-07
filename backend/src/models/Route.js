const mongoose = require("mongoose");

const routeSchema = new mongoose.Schema(
    {
        orderId: {type: mongoose.Schema.Types.ObjectId, ref: "Order", required: true},
        startPoint: String,
        endPoint: String,
    },
    {timestamps: true},
);

module.exports = mongoose.model("Route", routeSchema);