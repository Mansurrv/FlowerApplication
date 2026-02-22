const requiredVars = ["MONGO_URI", "JWT_SECRET"];

function validateEnv() {
  const missing = requiredVars.filter((key) => {
    const value = process.env[key];
    return !value || String(value).trim().length === 0;
  });

  if (missing.length > 0) {
    console.error(`Missing required environment variables: ${missing.join(", ")}`);
    process.exit(1);
  }
}

module.exports = {
  validateEnv,
};
