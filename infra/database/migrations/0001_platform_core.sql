-- Paw Time platform core schema for PostgreSQL/Supabase.
-- API access uses a server-side database role. RLS is enabled without public
-- policies so browser and game clients cannot query these tables directly.

create extension if not exists pgcrypto;

create type public.organization_role as enum (
  'organization_admin',
  'store_manager',
  'recruiter',
  'attendance_operator',
  'viewer'
);
create type public.job_posting_status as enum ('draft', 'published', 'closed');
create type public.application_status as enum ('applied', 'selected', 'rejected', 'withdrawn');
create type public.shift_status as enum (
  'scheduled', 'checked_in', 'checked_out', 'completed', 'no_show', 'disputed'
);
create type public.attendance_event_kind as enum ('check_in', 'check_out');
create type public.actor_kind as enum ('worker', 'employer', 'system');
create type public.world_owner_kind as enum ('worker', 'organization');
create type public.world_kind as enum ('worker_island', 'employer_house');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.organization_role not null,
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);

create table public.worker_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  timezone text not null default 'Asia/Tokyo',
  address jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.job_postings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete restrict,
  title text not null check (char_length(title) between 1 and 120),
  description text not null default '',
  role text not null,
  hourly_wage integer not null check (hourly_wage >= 0),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  capacity integer not null check (capacity between 1 and 1000),
  status public.job_posting_status not null default 'draft',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table public.applications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  job_posting_id uuid not null references public.job_postings(id) on delete cascade,
  worker_id uuid not null references auth.users(id) on delete cascade,
  status public.application_status not null default 'applied',
  applied_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references auth.users(id),
  decision_note text,
  unique (job_posting_id, worker_id)
);

create table public.shifts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete restrict,
  job_posting_id uuid not null references public.job_postings(id) on delete restrict,
  application_id uuid not null unique references public.applications(id) on delete restrict,
  worker_id uuid not null references auth.users(id) on delete restrict,
  scheduled_start_at timestamptz not null,
  scheduled_end_at timestamptz not null,
  status public.shift_status not null default 'scheduled',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (scheduled_end_at > scheduled_start_at)
);

create table public.attendance_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  shift_id uuid not null references public.shifts(id) on delete cascade,
  kind public.attendance_event_kind not null,
  recorded_at timestamptz not null,
  source public.actor_kind not null,
  actor_id uuid references auth.users(id),
  client_request_id text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (organization_id, client_request_id)
);

create table public.attendance_corrections (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  shift_id uuid not null references public.shifts(id) on delete cascade,
  attendance_event_id uuid references public.attendance_events(id) on delete restrict,
  requested_by uuid not null references auth.users(id),
  approved_by uuid references auth.users(id),
  corrected_at timestamptz not null,
  reason text not null,
  created_at timestamptz not null default now()
);

create table public.evaluations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  shift_id uuid not null references public.shifts(id) on delete cascade,
  author_id uuid not null references auth.users(id),
  subject_type text not null check (subject_type in ('worker', 'store')),
  subject_id uuid not null,
  rating smallint not null check (rating between 1 and 5),
  tags text[] not null default '{}',
  comment text,
  submitted_at timestamptz not null default now(),
  unique (shift_id, author_id, subject_type, subject_id)
);

create table public.game_worlds (
  id uuid primary key default gen_random_uuid(),
  owner_type public.world_owner_kind not null,
  owner_id uuid not null,
  kind public.world_kind not null,
  level integer not null default 1 check (level >= 1),
  experience integer not null default 0 check (experience >= 0),
  layout jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_type, owner_id, kind)
);

create table public.game_inventory (
  world_id uuid not null references public.game_worlds(id) on delete cascade,
  item_code text not null,
  quantity integer not null default 0 check (quantity >= 0),
  updated_at timestamptz not null default now(),
  primary key (world_id, item_code)
);

create table public.reward_grants (
  id uuid primary key default gen_random_uuid(),
  world_id uuid not null references public.game_worlds(id) on delete cascade,
  event_key text not null unique,
  reward_code text not null,
  experience integer not null default 0 check (experience >= 0),
  payload jsonb not null default '{}'::jsonb,
  granted_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  organization_id uuid references public.organizations(id) on delete cascade,
  actor_id uuid references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id text not null,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

create index job_postings_public_search_idx
  on public.job_postings (status, starts_at)
  where status = 'published';
create index applications_organization_status_idx
  on public.applications (organization_id, status, applied_at desc);
create index shifts_organization_start_idx
  on public.shifts (organization_id, scheduled_start_at);
create index shifts_worker_start_idx
  on public.shifts (worker_id, scheduled_start_at);
create index attendance_events_shift_time_idx
  on public.attendance_events (shift_id, recorded_at);
create index evaluations_subject_idx
  on public.evaluations (subject_type, subject_id, submitted_at desc);
create index audit_logs_entity_idx
  on public.audit_logs (entity_type, entity_id, created_at desc);

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.worker_profiles enable row level security;
alter table public.stores enable row level security;
alter table public.job_postings enable row level security;
alter table public.applications enable row level security;
alter table public.shifts enable row level security;
alter table public.attendance_events enable row level security;
alter table public.attendance_corrections enable row level security;
alter table public.evaluations enable row level security;
alter table public.game_worlds enable row level security;
alter table public.game_inventory enable row level security;
alter table public.reward_grants enable row level security;
alter table public.audit_logs enable row level security;
