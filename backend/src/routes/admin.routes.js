const express = require('express');
const User = require('../models/User');
const authMiddleware = require('../middleware/authMiddleware');
const requireRole = require('../middleware/requireRole');
const { applyQueryOptions, buildPaginationMeta } = require('../utils/query');

const router = express.Router();

router.use(authMiddleware);
router.use(requireRole('admin'));

router.get('/users', async (req, res, next) => {
  try {
    const { role, status, q } = req.query;
    const filter = {};

    if (role) {
      filter.role = role;
    } else {
      filter.role = { $ne: 'admin' };
    }

    if (status) {
      filter.status = status;
    }

    if (q) {
      const query = String(q);
      filter.$or = [
        { name: { $regex: query, $options: 'i' } },
        { email: { $regex: query, $options: 'i' } },
        { phone: { $regex: query, $options: 'i' } },
        { shopName: { $regex: query, $options: 'i' } },
      ];
    }

    const baseQuery = User.find(filter).select('-password');
    const { query, pagination } = applyQueryOptions(baseQuery, req.query, {
      defaultSort: '-createdAt',
    });
    const users = await query;

    if (pagination) {
      const total = await User.countDocuments(filter);
      return res.json({
        data: users,
        pagination: buildPaginationMeta(total, pagination.page, pagination.limit),
      });
    }

    res.json(users);
  } catch (error) {
    next(error);
  }
});

router.patch('/users/:id', async (req, res, next) => {
  try {
    const allowedFields = [
      'name',
      'email',
      'city',
      'phone',
      'shopName',
      'address',
      'description',
      'status',
      'role',
    ];

    const updates = {};
    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        updates[field] = req.body[field];
      }
    }

    if (updates.role) {
      const validRoles = ['user', 'admin', 'florist', 'deliver'];
      if (!validRoles.includes(updates.role)) {
        return res.status(400).json({ message: 'Invalid role' });
      }
    }

    if (updates.status) {
      const validStatuses = ['active', 'inactive'];
      if (!validStatuses.includes(updates.status)) {
        return res.status(400).json({ message: 'Invalid status' });
      }
    }

    const user = await User.findByIdAndUpdate(req.params.id, updates, {
      new: true,
      runValidators: true,
    }).select('-password');

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.json(user);
  } catch (error) {
    next(error);
  }
});

router.delete('/users/:id', async (req, res, next) => {
  try {
    if (req.user && req.user.id === req.params.id) {
      return res
        .status(400)
        .json({ message: 'Admin cannot delete own account' });
    }

    const user = await User.findByIdAndDelete(req.params.id);

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.json({ message: 'User deleted' });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
