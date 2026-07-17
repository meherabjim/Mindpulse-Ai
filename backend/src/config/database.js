const mysql = require("mysql2/promise");

// Create a reusable MySQL connection pool
const pool = mysql.createPool({
  host: process.env.DB_HOST || "localhost",
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  database: process.env.DB_NAME || "mindpulse_ai",

  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  charset: "utf8mb4",
});

// Check whether MySQL connection is working
const testDatabaseConnection = async () => {
  let connection;

  try {
    connection = await pool.getConnection();
    await connection.ping();

    console.log(
      `MySQL connected successfully: ${process.env.DB_NAME || "mindpulse_ai"}`
    );
  } finally {
    if (connection) {
      connection.release();
    }
  }
};

module.exports = {
  pool,
  testDatabaseConnection,
};