const router = require("express").Router();
const auth = require("../controllers/auth.controller");
const express = require('express');

router.post("/register", auth.register);
router.post("/login", auth.login);
router.post("/reset-password", auth.resetPassword);

module.exports = router;
