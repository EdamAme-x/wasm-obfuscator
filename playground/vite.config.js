import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

const repoName = process.env.GITHUB_REPOSITORY
  ? process.env.GITHUB_REPOSITORY.split("/")[1]
  : "";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src")
    }
  },
  base: process.env.GITHUB_ACTIONS && repoName ? `/${repoName}/` : "/"
});
