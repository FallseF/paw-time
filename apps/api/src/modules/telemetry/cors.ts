// Origins allowed to call the telemetry and insights endpoints from a browser.
// Extra origins can be added with TELEMETRY_ALLOWED_ORIGINS (comma separated).
// paw-time-play is the public game; obake-breakroom-b-sleep is its earlier URL, kept for old links.
const DEFAULT_ORIGINS = ["https://paw-time-play.vercel.app", "https://obake-breakroom-b-sleep.vercel.app"];
const LOCAL_RE = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

export function allowedOrigin(origin: string, env: NodeJS.ProcessEnv = process.env): string | null {
  if (!origin) return null;
  const extra = (env.TELEMETRY_ALLOWED_ORIGINS ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  if (DEFAULT_ORIGINS.includes(origin) || extra.includes(origin) || LOCAL_RE.test(origin)) return origin;
  return null;
}
