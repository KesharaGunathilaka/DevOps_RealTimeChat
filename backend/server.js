import express from "express";
import dotenv from "dotenv";
import cookieParser from "cookie-parser";
import cors from "cors";
import mongoose from "mongoose";

import path from "path";

import { connectDB } from "./lib/db.js";

import authRoutes from "./routes/authRoutes.js";
import chatRoutes from "./routes/chatRoutes.js";
import { app, server } from "./lib/socket.js";
import logger from "./utils/logger.js";

dotenv.config();

const PORT = process.env.PORT || 5000;
const __dirname = path.resolve();
const Origin = process.env.ORIGIN || "http://localhost:5173";

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(cookieParser());
app.use(
  cors({
    origin: Origin,
    credentials: true,
  })
);

// Readiness probe for Docker healthchecks and the post-deploy smoke test.
app.get("/api/health", (req, res) => {
  const dbUp = mongoose.connection.readyState === 1;
  res.status(dbUp ? 200 : 503).json({ status: dbUp ? "ok" : "degraded", db: dbUp });
});

app.use("/api/auth", authRoutes);
app.use("/api/chat", chatRoutes);

if (process.env.NODE_ENV === "production") {
  app.use(express.static(path.join(__dirname, "../frontend/dist")));

  app.get("*", (req, res) => {
    res.sendFile(path.join(__dirname, "../frontend", "dist", "index.html"));
  });
}

// Connect before listening so the API never accepts traffic it cannot serve.
await connectDB();

server.listen(PORT, () => {
  logger.info(`Server running on port ${PORT} (allowed origin: ${Origin})`);
});
