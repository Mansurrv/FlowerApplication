const path = require("path");
require("dotenv").config({ path: path.join(__dirname, "..", ".env") });

const app = require("./app")
const connectDB = require("./config/db")
const { validateEnv } = require("./config/env");

validateEnv();
connectDB()

const PORT = process.env.PORT || 4040
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`)
})
