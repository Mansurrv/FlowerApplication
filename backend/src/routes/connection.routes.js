const express = require("express");
const Connection = require("../models/Connection");
const User = require("../models/User");
const router = express.Router();
const mongoose = require("mongoose");

router.post("/connect", async (req, res) => {
  try {
    const { userId, targetUserId } = req.body;

    const user = await User.findById(userId);
    const targetUser = await User.findById(targetUserId);

    if (!user || !targetUser) {
      return res.status(404).json({ 
        success: false, 
        message: "Пользователь не найден" 
      });
    }

    if (targetUser.role !== 'user') {
      return res.status(400).json({
        success: false,
        message: "Можно подключаться только к обычным пользователям"
      });
    }

    const existingConnection = await Connection.findOne({
      $or: [
        { userId, connectedUserId: targetUserId },
        { userId: targetUserId, connectedUserId: userId }
      ]
    });

    if (existingConnection) {
      let message = "";
      let showCurrentConnection = false;
      let currentPartner = null;

      if (existingConnection.status === 'blocked') {
        message = "Подключение заблокировано";
      } else if (existingConnection.status === 'accepted') {
        const isUserConnected = existingConnection.userId.toString() === userId;
        currentPartner = isUserConnected ? existingConnection.connectedUserId : existingConnection.userId;
        
        const partnerUser = await User.findById(currentPartner).select('name email profileImage');
        
        message = `Вы уже подключены с ${partnerUser.name}`;
        showCurrentConnection = true;
      } else {
        message = "Запрос на подключение уже отправлен";
      }

      return res.status(400).json({
        success: false,
        message,
        showCurrentConnection,
        currentPartner: currentPartner ? {
          id: currentPartner,
          name: (await User.findById(currentPartner)).name
        } : null,
        connectionId: existingConnection._id
      });
    }

    const userHasActiveConnection = await Connection.findOne({
      $or: [
        { userId: userId, status: 'accepted' },
        { connectedUserId: userId, status: 'accepted' }
      ]
    });

    if (userHasActiveConnection) {
      const partnerId = userHasActiveConnection.userId.toString() === userId 
        ? userHasActiveConnection.connectedUserId 
        : userHasActiveConnection.userId;
      
      const partnerUser = await User.findById(partnerId).select('name email profileImage city');

      return res.status(400).json({
        success: false,
        message: "У вас уже есть активное подключение",
        showCurrentConnection: true,
        currentPartner: {
          id: partnerId,
          name: partnerUser.name,
          email: partnerUser.email,
          profileImage: partnerUser.profileImage,
          city: partnerUser.city
        },
        connectionId: userHasActiveConnection._id,
        connectedSince: userHasActiveConnection.createdAt
      });
    }

    const targetHasActiveConnection = await Connection.findOne({
      $or: [
        { userId: targetUserId, status: 'accepted' },
        { connectedUserId: targetUserId, status: 'accepted' }
      ]
    });

    if (targetHasActiveConnection) {
      const partnerId = targetHasActiveConnection.userId.toString() === targetUserId 
        ? targetHasActiveConnection.connectedUserId 
        : targetHasActiveConnection.userId;
      
      const partnerUser = await User.findById(partnerId).select('name');

      return res.status(400).json({
        success: false,
        message: `Пользователь ${targetUser.name} уже подключен с ${partnerUser.name}`,
        targetUserInfo: {
          id: targetUserId,
          name: targetUser.name,
          currentPartner: partnerUser.name
        }
      });
    }

    const connection = new Connection({
      userId,
      connectedUserId: targetUserId,
      status: 'accepted'
    });

    await connection.save();

    res.status(201).json({
      success: true,
      message: "Успешно подключено!",
      data: connection
    });
  } catch (error) {
    console.error("Connection error:", error);
    
    if (error.code === 11000) {
      return res.status(400).json({
        success: false,
        message: "У пользователя уже есть активное подключение"
      });
    }
    
    res.status(500).json({ 
      success: false, 
      message: "Ошибка сервера", 
      error: error.message 
    });
  }
});

router.get("/current/:userId", async (req, res) => {
  try {
    const userId = req.params.userId;

    const connection = await Connection.findOne({
      $or: [
        { userId: userId, status: 'accepted' },
        { connectedUserId: userId, status: 'accepted' }
      ]
    })
    .populate('userId', 'name email profileImage city lastActivity')
    .populate('connectedUserId', 'name email profileImage city lastActivity');

    if (!connection) {
      return res.json({
        success: true,
        data: null,
        message: "Нет активных подключений"
      });
    }

    const isUserInitiator = connection.userId._id.toString() === userId;
    const partner = isUserInitiator ? connection.connectedUserId : connection.userId;

    const connectionData = {
      id: connection._id,
      partner: {
        id: partner._id,
        name: partner.name,
        email: partner.email,
        profileImage: partner.profileImage,
        city: partner.city,
        lastActivity: partner.lastActivity
      },
      status: connection.status,
      notificationsEnabled: connection.notificationsEnabled,
      connectedSince: connection.createdAt,
      lastActivity: connection.lastActivity,
      initiatedByMe: isUserInitiator,
      previousConnections: connection.previousConnections
    };

    res.json({
      success: true,
      data: connectionData
    });
  } catch (error) {
    console.error("Get current connection error:", error);
    res.status(500).json({ 
      success: false, 
      message: "Ошибка сервера", 
      error: error.message 
    });
  }
});

router.get("/history/:userId", async (req, res) => {
  try {
    const userId = req.params.userId;

    const connections = await Connection.find({
      $or: [
        { userId: userId },
        { connectedUserId: userId }
      ]
    })
    .populate('userId', 'name profileImage')
    .populate('connectedUserId', 'name profileImage')
    .sort({ updatedAt: -1 });

    const history = connections.map(conn => {
      const partner = conn.userId._id.toString() === userId 
        ? conn.connectedUserId 
        : conn.userId;

      return {
        connectionId: conn._id,
        partner: {
          id: partner._id,
          name: partner.name,
          profileImage: partner.profileImage
        },
        status: conn.status,
        connectedAt: conn.createdAt,
        disconnectedAt: conn.status !== 'accepted' ? conn.updatedAt : null,
        duration: conn.status === 'accepted' 
          ? Math.floor((Date.now() - new Date(conn.createdAt).getTime()) / (1000 * 60 * 60 * 24))
          : null,
        initiatedByMe: conn.userId._id.toString() === userId
      };
    });

    res.json({
      success: true,
      data: history
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: "Ошибка сервера", 
      error: error.message 
    });
  }
});

router.get("/:userId", async (req, res) => {
  try {
    const userId = req.params.userId;

    const connection = await Connection.findOne({
      $or: [
        { userId: userId, status: 'accepted' },
        { connectedUserId: userId, status: 'accepted' }
      ]
    })
    .populate('userId', 'name email profileImage city lastActivity')
    .populate('connectedUserId', 'name email profileImage city lastActivity');

    if (!connection) {
      return res.json({
        success: true,
        data: []
      });
    }

    const partner = connection.userId._id.toString() === userId 
      ? connection.connectedUserId 
      : connection.userId;

    const connectionData = {
      id: connection._id,
      userId: partner._id,
      name: partner.name,
      email: partner.email,
      profileImage: partner.profileImage,
      city: partner.city,
      lastActivity: connection.lastActivity,
      connectionDate: connection.createdAt,
      notificationsEnabled: connection.notificationsEnabled,
      connectionId: connection._id,
      initiatedByMe: connection.userId._id.toString() === userId
    };

    res.json({
      success: true,
      data: [connectionData] 
    });
  } catch (error) {
    console.error("Get connections error:", error);
    res.status(500).json({ 
      success: false, 
      message: "Ошибка сервера", 
      error: error.message 
    });
  }
});

module.exports = router;