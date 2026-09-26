// Local dev: rebuilds on change (tsup --watch), serves dist/ and proxies /v1/* to the API
// (PAW_TIME_API_URL, default http://localhost:8787), mirroring the vercel.json rewrite.
import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, join, normalize } from "node:path";

const PORT = Number(process.env.PORT ?? 3100);
const API = (process.env.PAW_TIME_API_URL ?? "http://localhost:8787").replace(/\/$/, "");
const DIST = join(import.meta.dirname, "..", "dist");
const TYPES: Record<string, string> = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".css": "text/css", ".map": "application/json" };

spawn("pnpm", ["exec", "tsup", "--watch"], { stdio: "inherit", cwd: join(import.meta.dirname, "..") });

createServer(async (req, res) => {
  const url = new URL(req.url ?? "/", "http://localhost");
  if (url.pathname.startsWith("/v1/")) {
    const upstream = await fetch(API + url.pathname + url.search).catch(() => null);
    res.writeHead(upstream?.status ?? 502, { "content-type": upstream?.headers.get("content-type") ?? "text/plain" });
    res.end(upstream ? Buffer.from(await upstream.arrayBuffer()) : "API unreachable");
    return;
  }
  let path = normalize(url.pathname).replace(/^(\.\.[/\\])+/, "");
  if (path === "/") path = "/index.html";
  if (!extname(path)) path += ".html";
  try {
    const body = await readFile(join(DIST, path));
    res.writeHead(200, { "content-type": TYPES[extname(path)] ?? "application/octet-stream" });
    res.end(body);
  } catch {
    res.writeHead(404).end("not found");
  }
}).listen(PORT, () => console.log(`Insights on http://localhost:${PORT} (API ${API})`));
