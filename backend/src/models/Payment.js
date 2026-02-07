const mongoose = require("mongoose");

const paymentSchema = new mongoose.Schema(
    {
        orderId: {type: mongoose.Schema.Types.ObjectId, ref: "Order", required: true},
        amount: Number,
        method: String,
        status: String,
        paidAt: Date,
    },
    {timestamps: true}
);

module.exports = mongoose.model("Payment", paymentSchema);
