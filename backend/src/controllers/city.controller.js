const City = require("../models/City");

exports.getCities = async (req, res) => {
  try {
    const cities = await City.find().sort({ name: 1 });
    res.json(cities);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

exports.addCity = async (req, res) => {
  try {
    const { name } = req.body;

    const exists = await City.findOne({ name });
    if (exists) return res.status(400).json({ message: "City already exists" });

    const city = await City.create({ name });
    res.status(201).json(city);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};