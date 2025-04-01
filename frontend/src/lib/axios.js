import axios from "axios";

export const axiosInstance = axios.create({
  baseURL: "http://13.61.12.132:5000/api",
  withCredentials: true,
});
