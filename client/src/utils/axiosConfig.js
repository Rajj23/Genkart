import axios from "axios";

export const axiosConfig = {
  withCredentials: true,
};

const apiBaseUrl = process.env.NEXT_PUBLIC_API || "http://localhost:5560/api";

export const axiosInstance = axios.create({
  baseURL: apiBaseUrl,
  withCredentials: true,
 
});