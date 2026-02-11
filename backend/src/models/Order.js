const mongoose = require('mongoose');

const orderItemSchema = new mongoose.Schema({
  flowerId: { type: String, required: true },
  quantity: { type: Number, required: true, min: 1 },
  price: { type: Number, required: true, min: 0 }
});


const orderSchema = new mongoose.Schema({
  userId: { type: String, required: true },
  floristId: { type: String, required: true }, 
  deliverId: { type: String }, 
  status: { 
    type: String, 
    required: true, 
    enum: ['pending', 'confirmed', 'preparing', 'delivering', 'delivered', 'cancelled'],
    default: 'pending'
  },
  totalPrice: { type: Number, required: true, min: 0 },
  city: { type: String, required: true },
  orderNumber: { type: String, unique: true },
  deliveryAddress: { type: String },
  items: [orderItemSchema],
  createdAt: { type: Date, default: Date.now }
});

orderSchema.pre('save', async function() {
  if (!this.orderNumber) {
    const timestamp = Date.now();
    const random = Math.floor(Math.random() * 1000);
    this.orderNumber = `ORD-${timestamp}-${random}`;
  }
});

module.exports = mongoose.model('Order', orderSchema);