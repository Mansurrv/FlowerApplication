const mongoose = require('mongoose');

const ConnectionSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  connectedUserId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  status: {
    type: String,
    enum: ['pending', 'accepted', 'rejected', 'blocked'],
    default: 'accepted'
  },
  previousConnections: [{
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User'
    },
    connectedAt: Date,
    disconnectedAt: Date,
    reason: String
  }],
  notificationsEnabled: {
    type: Boolean,
    default: true
  },
  lastActivity: {
    type: Date,
    default: Date.now
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

ConnectionSchema.index({ userId: 1, connectedUserId: 1 }, { unique: true });
ConnectionSchema.index({ userId: 1, status: 'accepted' }, { unique: true });
ConnectionSchema.index({ connectedUserId: 1, status: 'accepted' }, { unique: true });

module.exports = mongoose.model('Connection', ConnectionSchema);