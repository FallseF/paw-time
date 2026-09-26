-- Pseudonymous product telemetry from the worker game (see docs/architecture/insights.md).
-- Append-only: rows are never updated. The only delete path is "delete on request"
-- by install_id. No account ids, names, free text or locations are stored; props
-- are validated against the allowlist in packages/api-contracts before insert.

create table public.telemetry_events (
  id bigint generated always as identity primary key,
  install_id uuid not null,
  occurred_at timestamptz not null,
  received_at timestamptz not null default now(),
  event_type text not null check (event_type ~ '^[a-z_]{1,40}$'),
  props jsonb not null default '{}'::jsonb check (jsonb_typeof(props) = 'object' and pg_column_size(props) <= 2048)
);

-- Live now feed and time-window aggregates.
create index telemetry_events_received_at_idx on public.telemetry_events (received_at);
create index telemetry_events_type_occurred_idx on public.telemetry_events (event_type, occurred_at);
-- Per-install retention/cohorts and delete-on-request.
create index telemetry_events_install_occurred_idx on public.telemetry_events (install_id, occurred_at);
-- Per-shop post-shift signals.
create index telemetry_events_shop_idx on public.telemetry_events ((props->>'shop_id'), occurred_at)
  where props ? 'shop_id';

-- Only the server-side API role reads or writes; no public policies.
alter table public.telemetry_events enable row level security;

-- Append-only guard: block updates at the database level.
create function public.telemetry_events_no_update() returns trigger
language plpgsql as $$
begin
  raise exception 'telemetry_events is append-only';
end;
$$;

create trigger telemetry_events_no_update
  before update on public.telemetry_events
  for each row execute function public.telemetry_events_no_update();
