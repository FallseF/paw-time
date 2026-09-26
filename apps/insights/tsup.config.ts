import { defineConfig } from "tsup";

// Static site: public/ is copied as-is, src/main.ts is bundled (with chart.js) to dist/assets/app.js.
export default defineConfig({
  entry: { "assets/app": "src/main.ts" },
  format: ["iife"],
  platform: "browser",
  target: "es2020",
  outDir: "dist",
  clean: true,
  minify: true,
  sourcemap: true,
  publicDir: "public",
  noExternal: [/.*/],
});
