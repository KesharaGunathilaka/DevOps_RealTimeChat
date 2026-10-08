import mongoose from "mongoose";
import logger from "../utils/logger.js";

export const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGO);
    logger.info(`MongoDB connected: ${conn.connection.host}`);
  } catch (error) {
    // Exit rather than continue: a running API with no database serves nothing
    // but 500s, which is harder to diagnose than a container that fails to start.
    logger.error(`MongoDB connection failed: ${error.message}`);
    process.exit(1);
  }
};
