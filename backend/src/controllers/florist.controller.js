const User = require("../models/User");
const Flower = require("../models/Flower"); // If you have a Flower model
const Order = require("../models/Order"); // If you have an Order model

// Get florist profile
exports.getProfile = async (req, res) => {
  try {
    const userId = req.user.id; // From JWT middleware
    
    const user = await User.findById(userId).select('-password');
    
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }
    
    // Ensure user is a florist
    if (user.role !== 'florist') {
      return res.status(403).json({ message: "Access denied. User is not a florist" });
    }
    
    res.json({
      shopName: user.shopName || 'My Flower Shop',
      email: user.email,
      phone: user.phone || '',
      city: user.city || '',
      address: user.address || '',
      description: user.description || '',
      rating: user.rating || 0,
      totalReviews: user.totalReviews || 0,
      status: user.status || 'active',
      createdAt: user.createdAt
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Update florist profile
exports.updateProfile = async (req, res) => {
  try {
    const userId = req.user.id;
    const { shopName, phone, address, description } = req.body;
    
    const user = await User.findById(userId);
    
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }
    
    if (user.role !== 'florist') {
      return res.status(403).json({ message: "Access denied. User is not a florist" });
    }
    
    // Update fields
    if (shopName !== undefined) user.shopName = shopName;
    if (phone !== undefined) user.phone = phone;
    if (address !== undefined) user.address = address;
    if (description !== undefined) user.description = description;
    
    await user.save();
    
    res.json({
      message: "Profile updated successfully",
      profile: {
        shopName: user.shopName,
        email: user.email,
        phone: user.phone,
        address: user.address,
        description: user.description,
        city: user.city,
        rating: user.rating,
        totalReviews: user.totalReviews,
        status: user.status
      }
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Get florist statistics - updated version
exports.getStatistics = async (req, res) => {
  try {
    const userId = req.user.id;
    
    const user = await User.findById(userId);
    
    if (!user || user.role !== 'florist') {
      return res.status(403).json({ message: "Access denied" });
    }
    
    // Count flowers
    let totalFlowers = 0;
    let availableFlowers = 0;
    let soldOutFlowers = 0;
    
    try {
      if (Flower) {
        totalFlowers = await Flower.countDocuments({ floristId: userId });
        availableFlowers = await Flower.countDocuments({ 
          floristId: userId, 
          available: true 
        });
        soldOutFlowers = await Flower.countDocuments({ 
          floristId: userId, 
          available: false 
        });
      }
    } catch (flowerErr) {
      console.log('Flower count error:', flowerErr.message);
    }
    
    // Count orders
    let totalOrders = 0;
    let pendingOrders = 0;
    let completedOrders = 0;
    let totalRevenue = 0;
    
    try {
      if (Order) {
        // Count all orders for this florist
        totalOrders = await Order.countDocuments({ floristId: userId });
        pendingOrders = await Order.countDocuments({ 
          floristId: userId, 
          status: 'pending' 
        });
        completedOrders = await Order.countDocuments({ 
          floristId: userId, 
          status: 'completed' 
        });
        
        // Calculate total revenue from completed orders
        const completedOrdersList = await Order.find({ 
          floristId: userId, 
          status: 'completed' 
        });
        totalRevenue = completedOrdersList.reduce((sum, order) => {
          return sum + (order.totalPrice || 0);
        }, 0);
      }
    } catch (orderErr) {
      console.log('Order count error:', orderErr.message);
    }
    
    res.json({
      success: true,
      totalFlowers,
      availableFlowers,
      soldOutFlowers,
      totalOrders,
      pendingOrders,
      completedOrders,
      totalRevenue: totalRevenue.toFixed(2),
      popularCategory: 'Roses',
      mostExpensiveFlower: 'Premium Orchid',
      cheapestFlower: 'Basic Daisy'
    });
  } catch (err) {
    console.error('Statistics error:', err);
    res.status(500).json({ 
      success: false,
      message: err.message 
    });
  }
};

// Get florist's orders
exports.getOrders = async (req, res) => {
  try {
    const userId = req.user.id;
    
    const user = await User.findById(userId);
    
    if (!user || user.role !== 'florist') {
      return res.status(403).json({ 
        success: false,
        message: "Access denied" 
      });
    }
    
    let orders = [];
    if (Order) {
      orders = await Order.find({ floristId: userId })
        .populate('userId', 'name email phone city')
        .populate('deliverId', 'name phone')
        .sort({ createdAt: -1 });
    }
    
    res.json({
      success: true,
      orders: orders
    });
  } catch (err) {
    console.error('Get orders error:', err);
    res.status(500).json({ 
      success: false,
      message: err.message 
    });
  }
};

// In controllers/florist.controller.js
exports.getFlowers = async (req, res) => {
  try {
    const userId = req.user.id;
    
    const user = await User.findById(userId);
    
    if (!user || user.role !== 'florist') {
      return res.status(403).json({ message: "Access denied" });
    }
    
    let flowers = [];
    if (Flower) {
      flowers = await Flower.find({ floristId: userId })
        .populate('categoryId', 'name')
        .sort({ createdAt: -1 });
    }
    
    // Map the fields correctly
    const formattedFlowers = flowers.map(flower => ({
      _id: flower._id,
      name: flower.name,
      price: flower.price,
      description: flower.description,
      image_url: flower.image_url || flower.imageUrl, // Handle both
      available: flower.available,
      categoryId: flower.categoryId,
      floristId: flower.floristId,
      city: flower.city,
      createdAt: flower.createdAt,
      updatedAt: flower.updatedAt
    }));
    
    res.json(formattedFlowers);
  } catch (err) {
    console.error('Error getting florist flowers:', err);
    res.status(500).json({ message: err.message });
  }
};