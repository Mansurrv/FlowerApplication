const express = require('express');
const router = express.Router();
const floristController = require('../controllers/florist.controller');
const authMiddleware = require('../middleware/authMiddleware');

router.use(authMiddleware);

// Florist profile routes
router.get('/profile', floristController.getProfile);
router.put('/profile', floristController.updateProfile);

// Florist statistics
router.get('/statistics', floristController.getStatistics);

// Florist's flowers
router.get('/flowers', floristController.getFlowers);

// Florist's orders - ADD THIS
router.get('/orders', floristController.getOrders);

module.exports = router;