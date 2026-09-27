import { defineConfig } from "tsup";

export default defineConfig({
  // app.ts is also emitted so the Vercel function (api/index.js) can import the bundled app.
  entry: ["src/index.ts", "src/app.ts"],
  format: ["esm"],
  dts: true,
  outDir: "dist",
  clean: true,
  noExternal: ["@paw-time/api-contracts", "@paw-time/shop-console"],
});
