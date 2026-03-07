const express = require("express");
const bodyParser = require("body-parser");
const cors = require("cors");
const { exec } = require("child_process");
const path = require("path");

const app = express();
const PORT = 3000;

// Middleware
app.use(cors());
app.use(express.json()); // Built-in middleware since Express 4.16

// Logging Middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  next();
});

// Serve static files from 'src'
app.use(express.static(path.join(__dirname, "src")));
// Also serve 'data' so the app can access it if needed (optional depending on use case)
app.use("/data", express.static(path.join(__dirname, "data")));

// API Endpoint to run terminal commands
app.post("/api/terminal/run", (req, res) => {
  const { command } = req.body;

  if (!command) {
    return res.status(400).json({ error: "No command provided" });
  }

  console.log(`Executing command: ${command}`);

  // specific safety check: mostly intended for 'claude' or 'ls' etc, but keeping open for the user as requested
  // In a real production app, this is unsafe. For a local dev tool, it's acceptable.

  exec(command, { cwd: __dirname }, (error, stdout, stderr) => {
    if (error) {
      console.error(`Error: ${error.message}`);
      return res.status(500).json({
        error: error.message,
        stderr: stderr,
        stdout: stdout,
      });
    }
    res.json({ stdout, stderr });
  });
});

app.listen(PORT, () => {
  console.log(`Weaver Server running at http://localhost:${PORT}`);
  console.log(`Open your browser to http://localhost:${PORT} to use the app.`);
});
