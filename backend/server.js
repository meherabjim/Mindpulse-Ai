require("dotenv").config();

const app = require("./src/app");
const {
  pool,
  testDatabaseConnection,
} = require("./src/config/database");

const PORT = Number(process.env.PORT) || 5000;

let server;

// Start the database connection and server
const startServer = async () => {
  try {
    await testDatabaseConnection();

    server = app.listen(PORT, () => {
      console.log("----------------------------------------");
      console.log("MindPulse AI Backend");
      console.log(`Environment: ${process.env.NODE_ENV || "development"}`);
      console.log(`Server: http://localhost:${PORT}`);
      console.log(`Health: http://localhost:${PORT}/api/v1/health`);
      console.log("----------------------------------------");
    });
  } catch (error) {
    console.error("Failed to start MindPulse AI Backend:");
    console.error(error.message);
    process.exit(1);
  }
};

// Gracefully close server and database
const shutdown = async (signal) => {
  console.log(`\n${signal} received. Closing application...`);

  try {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }

    await pool.end();

    console.log("Server and database connections closed successfully.");
    process.exit(0);
  } catch (error) {
    console.error("Shutdown error:", error.message);
    process.exit(1);
  }
};

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));

process.on("unhandledRejection", (error) => {
  console.error("Unhandled Promise Rejection:", error);
  shutdown("UNHANDLED_REJECTION");
});

startServer();