
const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  role: { 
    type: String, 
    enum: ['user', 'admin', 'florist', 'deliver'], 
    default: 'user' 
  },
  city: { type: String, default: '' },
  phone: { type: String, default: '' },
  shopName: { type: String, default: '' },
  address: { type: String, default: '' },
  description: { type: String, default: '' },
  rating: { type: Number, default: 0 },
  totalReviews: { type: Number, default: 0 },
  status: { 
    type: String, 
    enum: ['active', 'inactive'], 
    default: 'active' 
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('User', userSchema);