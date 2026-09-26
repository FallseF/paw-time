import assert from "node:assert/strict";
import test from "node:test";
import { app } from "../src/app.js";

test("health endpoint reports ready", async () => {
  const response = await app.request("/health");
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: "ok", service: "paw-time-api" });
});

test("business routes require organization context", async () => {
  const response = await app.request("/v1/business/jobs");
  assert.equal(response.status, 401);
});

test("business routes isolate jobs by organization", async () => {
  const response = await app.request("/v1/business/jobs", {
    headers: {
      "x-organization-id": "org-komorebi",
      "x-actor-id": "member-demo",
    },
  });
  assert.equal(response.status, 200);
  const body = (await response.json()) as { data: Array<{ organizationId: string }> };
  assert.ok(body.data.length > 0);
  assert.ok(body.data.every((job) => job.organizationId === "org-komorebi"));
});

test("selection creates a shift and attendance derives punctuality", async () => {
  const workerId = "worker-attendance-test";
  const applicationResponse = await app.request("/v1/worker/applications", {
    method: "POST",
    headers: { "content-type": "application/json", "x-user-id": workerId },
    body: JSON.stringify({
      jobPostingId: "job-komorebi-20261003",
      workerDisplayName: "勤怠テスト",
    }),
  });
  assert.equal(applicationResponse.status, 201);
  const applicationBody = (await applicationResponse.json()) as { data: { id: string } };

  const businessHeaders = {
    "content-type": "application/json",
    "x-organization-id": "org-komorebi",
    "x-actor-id": "member-demo",
  };
  const decisionResponse = await app.request(
    `/v1/business/applications/${applicationBody.data.id}/decision`,
    {
      method: "POST",
      headers: businessHeaders,
      body: JSON.stringify({ decision: "selected" }),
    },
  );
  assert.equal(decisionResponse.status, 200);

  const shiftsResponse = await app.request("/v1/business/shifts", {
    headers: businessHeaders,
  });
  const shiftsBody = (await shiftsResponse.json()) as {
    data: Array<{ id: string; workerId: string }>;
  };
  const shift = shiftsBody.data.find((candidate) => candidate.workerId === workerId);
  assert.ok(shift);

  const checkInResponse = await app.request(
    `/v1/business/shifts/${shift.id}/attendance`,
    {
      method: "POST",
      headers: businessHeaders,
      body: JSON.stringify({
        kind: "check_in",
        recordedAt: "2026-10-03T10:10:00+09:00",
        clientRequestId: "attendance-test-check-in",
      }),
    },
  );
  assert.equal(checkInResponse.status, 201);

  const summaryResponse = await app.request(
    `/v1/business/shifts/${shift.id}/attendance-summary`,
    { headers: businessHeaders },
  );
  assert.equal(summaryResponse.status, 200);
  const summaryBody = (await summaryResponse.json()) as {
    data: { punctuality: string; minutesLate: number };
  };
  assert.equal(summaryBody.data.punctuality, "late");
  assert.equal(summaryBody.data.minutesLate, 10);
});
