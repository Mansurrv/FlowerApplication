const City = require("../models/City");
const { applyQueryOptions, buildPaginationMeta } = require("../utils/query");

exports.getCities = async (req, res, next) => {
  try {
    const { query, pagination } = applyQueryOptions(City.find(), req.query, {
      defaultSort: "name",
    });
    const cities = await query;

    if (pagination) {
      const total = await City.countDocuments();
      return res.json({
        data: cities,
        pagination: buildPaginationMeta(total, pagination.page, pagination.limit),
      });
    }

    res.json(cities);
  } catch (err) {
    next(err);
  }
};

exports.addCity = async (req, res, next) => {
  try {
    const { name } = req.body;

    const exists = await City.findOne({ name });
    if (exists) return res.status(400).json({ message: "City already exists" });

    const city = await City.create({ name });
    res.status(201).json(city);
  } catch (err) {
    next(err);
  }
};
