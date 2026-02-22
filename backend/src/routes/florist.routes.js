const express = require('express');
const router = express.Router();
const floristController = require('../controllers/florist.controller');
const authMiddleware = require('../middleware/authMiddleware');

router.use(authMiddleware);


router.get('/profile', floristController.getProfile);
router.put('/profile', floristController.updateProfile);


router.get('/statistics', floristController.getStatistics);


router.get('/flowers', floristController.getFlowers);


router.get('/orders', floristController.getOrders);

module.exports = router;