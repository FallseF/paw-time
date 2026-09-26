import { PGlite } from "@electric-sql/pglite";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { PostgresTelemetryStore } from "../src/modules/telemetry/store.js";

// Runs migration 0002 on an in-process Postgres (PGlite) and exercises the adapter.
test("PostgresTelemetryStore round-trips against migration 0002", async () => {
  const db = new PGlite();
  const sql = await readFile(new URL("../../../infra/database/migrations/0002_telemetry.sql", import.meta.url), "utf8");
  await db.exec(sql);
  const store = new PostgresTelemetryStore(async (text, params) => ({ rows: (await db.query<Record<string, unknown>>(text, params)).rows }));

  const a = randomUUID();
  const b = randomUUID();
  const now = Date.now();
  const t = Math.floor(now / 1000);
  await store.append({ install_id: a, received: now - 3_600_000, events: [{ t: t - 3600, type: "app_open", props: { day_type: "off" } }] });
  await store.append({
    install_id: b,
    received: now,
    events: [
      { t, type: "job_accept", props: { role: "register", invited: true, shop_id: "cafe_komorebi" } },
      { t, type: "review_submitted", props: { tags: ["friendly"], stars: 5 } },
    ],
  });

  const all = await store.readAll();
  assert.equal(all.length, 3);
  assert.deepEqual(all[1]?.events[0], { t, type: "job_accept", props: { role: "register", invited: true, shop_id: "cafe_komorebi" } });
  assert.equal((await store.readSince(now - 60_000)).length, 2);

  await assert.rejects(db.query("update public.telemetry_events set event_type = 'x'"), /append-only/);

  assert.equal(await store.deleteInstall(b), 2);
  assert.deepEqual((await store.readAll()).map((x) => x.install_id), [a]);
  await db.close();
});
