import axios from "axios";

export const axiosInstance = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || "http://13.61.12.132:5000/api",
  withCredentials: true,
});
