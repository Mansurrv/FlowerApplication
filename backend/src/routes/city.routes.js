const router = require("express").Router();
const cityController = require("../controllers/city.controller");
const City = require("../models/City");
const authMiddleware = require("../middleware/authMiddleware");
const requireRole = require("../middleware/requireRole");

router.get("/", cityController.getCities);
router.post("/", authMiddleware, requireRole("admin"), cityController.addCity);

router.put("/:id", authMiddleware, requireRole("admin"), async (req, res) => {
  try {
    const city = await City.findByIdAndUpdate(
      req.params.id,
      { name: req.body.name },
      { new: true, runValidators: true }
    );
    if (!city) return res.status(404).json({ message: "Not found" });
    res.json(city);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.delete("/:id", authMiddleware, requireRole("admin"), async (req, res) => {
  await City.findByIdAndDelete(req.params.id);
  res.json({ message: "City deleted" });
});

module.exports = router;
