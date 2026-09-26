import type { Application, GameWorld, JobPosting } from "@paw-time/api-contracts";

const apiUrl = process.env.PAW_TIME_API_URL ?? "http://localhost:8787";
const organizationId = process.env.PAW_TIME_ORGANIZATION_ID ?? "org-komorebi";
const actorId = process.env.PAW_TIME_ACTOR_ID ?? "member-demo";

type ApiResponse<T> = { data: T };

async function getBusinessData<T>(path: string): Promise<T | null> {
  try {
    const response = await fetch(`${apiUrl}/v1/business${path}`, {
      headers: {
        "x-organization-id": organizationId,
        "x-actor-id": actorId,
      },
      cache: "no-store",
    });
    if (!response.ok) return null;
    const payload = (await response.json()) as ApiResponse<T>;
    return payload.data;
  } catch {
    return null;
  }
}

export function listJobs(): Promise<JobPosting[] | null> {
  return getBusinessData<JobPosting[]>("/jobs");
}

export function listApplications(): Promise<Application[] | null> {
  return getBusinessData<Application[]>("/applications");
}

export function getEmployerWorld(): Promise<GameWorld | null> {
  return getBusinessData<GameWorld>("/world");
}
