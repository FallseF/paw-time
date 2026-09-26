// Telemetry storage adapters. The API picks one at startup (createTelemetryStore):
//   - BlobTelemetryStore when BLOB_READ_WRITE_TOKEN is set (Vercel Blob, private store)
//   - MemoryTelemetryStore otherwise (local dev, tests)
// PostgresTelemetryStore implements infra/database/migrations/0002_telemetry.sql and
// takes any driver's query function, so Neon/Supabase/pg can be plugged in.
import type { TelemetryEvent } from "@paw-time/api-contracts";
import { del, get, list, put } from "@vercel/blob";

export type StoredBatch = {
  install_id: string;
  /** Server receive time, ms. */
  received: number;
  events: TelemetryEvent[];
};

export type TelemetryStoreKind = "memory" | "blob" | "postgres";

export interface TelemetryStore {
  readonly kind: TelemetryStoreKind;
  append(batch: StoredBatch): Promise<void>;
  readAll(): Promise<StoredBatch[]>;
  /** Batches received at or after sinceMs (used by the Live now feed). */
  readSince(sinceMs: number): Promise<StoredBatch[]>;
  /** Delete-on-request. Returns the number of removed batches/rows. */
  deleteInstall(installId: string): Promise<number>;
}

export class MemoryTelemetryStore implements TelemetryStore {
  readonly kind = "memory" as const;
  private batches: StoredBatch[] = [];

  async append(batch: StoredBatch) {
    this.batches.push(batch);
  }
  async readAll() {
    return this.batches.slice();
  }
  async readSince(sinceMs: number) {
    return this.batches.filter((b) => b.received >= sinceMs);
  }
  async deleteInstall(installId: string) {
    const before = this.batches.length;
    this.batches = this.batches.filter((b) => b.install_id !== installId);
    return before - this.batches.length;
  }
}

// Layout: ev/<UTC yyyymmddhh>/<install_id>-<received_ms>-<rand>.json
// Hour folders let the feed list only the last hour or two.
const BLOB_PREFIX = "ev/";
const hourKey = (ms: number) => new Date(ms).toISOString().slice(0, 13).replace(/[-T]/g, "");

export class BlobTelemetryStore implements TelemetryStore {
  readonly kind = "blob" as const;
  // Blob objects are immutable, so a pathname -> batch cache is safe per warm instance.
  private cache = new Map<string, StoredBatch>();

  async append(batch: StoredBatch) {
    const rand = Math.random().toString(36).slice(2, 10);
    const path = `${BLOB_PREFIX}${hourKey(batch.received)}/${batch.install_id}-${batch.received}-${rand}.json`;
    await put(path, JSON.stringify(batch), { access: "private", contentType: "application/json", addRandomSuffix: false });
  }

  async readAll() {
    const paths = await this.listPaths(BLOB_PREFIX);
    const batches = await this.load(paths);
    const live = new Set(paths);
    for (const key of this.cache.keys()) if (!live.has(key)) this.cache.delete(key);
    return batches;
  }

  async readSince(sinceMs: number) {
    const hours = new Set<string>();
    for (let ms = sinceMs; ms <= Date.now() + 3_600_000; ms += 3_600_000) hours.add(hourKey(ms));
    const paths = (await Promise.all([...hours].map((h) => this.listPaths(`${BLOB_PREFIX}${h}/`)))).flat();
    return (await this.load(paths)).filter((b) => b.received >= sinceMs);
  }

  async deleteInstall(installId: string) {
    const paths = (await this.listPaths(BLOB_PREFIX)).filter((p) => p.split("/")[2]?.startsWith(`${installId}-`));
    if (paths.length) await del(paths);
    for (const p of paths) this.cache.delete(p);
    return paths.length;
  }

  private async listPaths(prefix: string): Promise<string[]> {
    const paths: string[] = [];
    let cursor: string | undefined;
    do {
      const page = await list(cursor ? { prefix, cursor, limit: 1000 } : { prefix, limit: 1000 });
      for (const b of page.blobs) paths.push(b.pathname);
      cursor = page.hasMore ? page.cursor : undefined;
    } while (cursor);
    return paths;
  }

  private async load(paths: string[]): Promise<StoredBatch[]> {
    const missing = paths.filter((p) => !this.cache.has(p));
    const CONCURRENCY = 16;
    for (let i = 0; i < missing.length; i += CONCURRENCY) {
      await Promise.all(
        missing.slice(i, i + CONCURRENCY).map(async (p) => {
          const res = await get(p, { access: "private" });
          if (!res || res.statusCode !== 200) return;
          this.cache.set(p, JSON.parse(await new Response(res.stream).text()) as StoredBatch);
        }),
      );
    }
    return paths.map((p) => this.cache.get(p)).filter((b): b is StoredBatch => !!b);
  }
}

/** Minimal driver contract: parameterised SQL with $1..$n placeholders. */
export type SqlQuery = (text: string, params: unknown[]) => Promise<{ rows: Record<string, unknown>[] }>;

/** One row per event in public.telemetry_events (see migration 0002). Not exercised against a live DB yet. */
export class PostgresTelemetryStore implements TelemetryStore {
  readonly kind = "postgres" as const;
  constructor(private readonly query: SqlQuery) {}

  async append(batch: StoredBatch) {
    if (!batch.events.length) return;
    const values: string[] = [];
    const params: unknown[] = [];
    batch.events.forEach((e, i) => {
      const o = i * 5;
      values.push(`($${o + 1}::uuid, to_timestamp($${o + 2}), to_timestamp($${o + 3}::double precision / 1000), $${o + 4}, $${o + 5}::jsonb)`);
      params.push(batch.install_id, e.t, batch.received, e.type, JSON.stringify(e.props));
    });
    await this.query(
      `insert into public.telemetry_events (install_id, occurred_at, received_at, event_type, props) values ${values.join(", ")}`,
      params,
    );
  }

  async readAll() {
    return this.select("", []);
  }

  async readSince(sinceMs: number) {
    return this.select("where received_at >= to_timestamp($1::double precision / 1000)", [sinceMs]);
  }

  async deleteInstall(installId: string) {
    const res = await this.query("delete from public.telemetry_events where install_id = $1::uuid returning 1", [installId]);
    return res.rows.length;
  }

  private async select(where: string, params: unknown[]): Promise<StoredBatch[]> {
    const res = await this.query(
      `select install_id::text as install_id, extract(epoch from occurred_at)::bigint as t,
              (extract(epoch from received_at) * 1000)::bigint as received, event_type, props
         from public.telemetry_events ${where} order by received_at, id`,
      params,
    );
    // Rows are regrouped into one-event batches; aggregation only needs install_id + event.
    return res.rows.map((r) => ({
      install_id: String(r.install_id),
      received: Number(r.received),
      events: [{ t: Number(r.t), type: r.event_type as TelemetryEvent["type"], props: (r.props ?? {}) as TelemetryEvent["props"] }],
    }));
  }
}

export function createTelemetryStore(env: NodeJS.ProcessEnv = process.env): TelemetryStore {
  if (env.BLOB_READ_WRITE_TOKEN) return new BlobTelemetryStore();
  return new MemoryTelemetryStore();
}

let current: TelemetryStore | null = null;

export function telemetryStore(): TelemetryStore {
  current ??= createTelemetryStore();
  return current;
}

/** Swap the store (tests, or wiring a Postgres driver at startup). */
export function setTelemetryStore(store: TelemetryStore) {
  current = store;
}
