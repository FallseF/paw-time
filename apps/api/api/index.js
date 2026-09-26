// Vercel Node.js function: serves the whole Hono app (vercel.json rewrites every path here).
// Plain JS on purpose: it imports the tsup bundle, which already inlines the TS-source
// workspace package @paw-time/api-contracts that Node can't load from node_modules.
import { handle } from "@hono/node-server/vercel";
import { app } from "../dist/app.js";

export default handle(app);
