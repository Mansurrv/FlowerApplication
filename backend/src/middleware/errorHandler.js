const notFound = (req, res, next) => {
  res.status(404);
  next(new Error(`Not Found - ${req.originalUrl}`));
};

const errorHandler = (err, req, res, next) => {
  const statusCode =
    err && (err.statusCode || err.status)
      ? err.statusCode || err.status
      : res.statusCode && res.statusCode !== 200
      ? res.statusCode
      : 500;

  if (err && err.name === "CastError") {
    res.status(400).json({ message: "Invalid resource id" });
    return;
  }

  if (err && err.name === "ValidationError") {
    res.status(400).json({ message: err.message });
    return;
  }

  res.status(statusCode).json({
    message: err && err.message ? err.message : "Server error",
    ...(process.env.NODE_ENV === "development" ? { stack: err.stack } : {}),
  });
};

module.exports = {
  notFound,
  errorHandler,
};
