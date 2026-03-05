import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";
import { moonbitObfuscateApiPlugin } from "./scripts/moonbit-obfuscate-api.mjs";

const repoName = process.env.GITHUB_REPOSITORY
  ? process.env.GITHUB_REPOSITORY.split("/")[1]
  : "";

export default defineConfig({
  plugins: [react(), moonbitObfuscateApiPlugin()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src")
    }
  },
  base: process.env.GITHUB_ACTIONS && repoName ? `/${repoName}/` : "/"
});
