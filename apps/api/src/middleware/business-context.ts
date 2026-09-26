import type { MiddlewareHandler } from "hono";
import type { AppEnv } from "../types.js";

export const requireBusinessContext: MiddlewareHandler<AppEnv> = async (context, next) => {
  const organizationId = context.req.header("x-organization-id");
  const actorId = context.req.header("x-actor-id");

  if (!organizationId || !actorId) {
    return context.json(
      {
        error: "unauthorized",
        message: "x-organization-id と x-actor-id が必要です。",
      },
      401,
    );
  }

  context.set("organizationId", organizationId);
  context.set("actorId", actorId);
  await next();
};
