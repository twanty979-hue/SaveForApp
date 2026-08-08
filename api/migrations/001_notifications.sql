create table if not exists public.fcm_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  token text not null unique,
  platform text not null default 'android',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists fcm_tokens_user_id_idx
  on public.fcm_tokens (user_id);

create table if not exists public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  notification_key text not null unique,
  type text not null,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  sent_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists notification_deliveries_user_sent_idx
  on public.notification_deliveries (user_id, sent_at desc);

create index if not exists notification_deliveries_user_unread_idx
  on public.notification_deliveries (user_id)
  where read_at is null;

alter table public.fcm_tokens enable row level security;
alter table public.notification_deliveries enable row level security;

comment on table public.fcm_tokens is
  'Private FCM device tokens managed only by the SaveFor API service role.';
comment on table public.notification_deliveries is
  'Notification inbox and delivery deduplication managed by the SaveFor API.';
