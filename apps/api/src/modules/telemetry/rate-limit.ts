// Best-effort sliding-window limiter per warm instance. Stops runaway client
// loops; not a security boundary (a shared store would be needed for that).
export class RateLimiter {
  private readonly windows = new Map<string, number[]>();

  allow(key: string, limit: number, windowMs: number, now = Date.now()): boolean {
    const hits = (this.windows.get(key) ?? []).filter((t) => now - t < windowMs);
    const ok = hits.length < limit;
    if (ok) hits.push(now);
    this.windows.set(key, hits);
    if (this.windows.size > 5000) {
      for (const [k, v] of this.windows) if (!v.some((t) => now - t < windowMs)) this.windows.delete(k);
    }
    return ok;
  }

  reset() {
    this.windows.clear();
  }
}

export const telemetryLimiter = new RateLimiter();
