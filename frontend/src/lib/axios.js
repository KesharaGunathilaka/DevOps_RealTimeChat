import axios from "axios";

export const axiosInstance = axios.create({
  // Relative default keeps the built image host-agnostic: set VITE_API_BASE_URL
  // to point at a backend on a different origin.
  baseURL: import.meta.env.VITE_API_BASE_URL || "/api",
  withCredentials: true,
});
