const router = require("express").Router();
const cityController = require("../controllers/city.controller");

router.get("/", cityController.getCities);
router.post("/", cityController.addCity);

module.exports = router;
