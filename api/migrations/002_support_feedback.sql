-- SaveFor support, contact and feature-request data model.
-- Run this migration in Supabase SQL Editor after the existing application schema.

begin;

create table if not exists public.support_channels (
  id uuid primary key default gen_random_uuid(),
  channel_key text not null unique check (channel_key = any (array['line'::text, 'facebook'::text, 'email'::text])),
  label text not null,
  address text not null,
  url text not null,
  icon_key text not null,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

insert into public.support_channels (channel_key, label, address, url, icon_key, sort_order)
values
  ('line', 'LINE Official', 'bs_boll', 'https://line.me/ti/p/~bs_boll', 'chat', 10),
  ('facebook', 'Facebook', 'https://www.facebook.com/worathon.namthong.2025/', 'https://www.facebook.com/worathon.namthong.2025/', 'facebook', 20),
  ('email', 'Email Support', 'support@savefor.app', 'mailto:support@savefor.app', 'email', 30)
on conflict (channel_key) do update
set label = excluded.label,
    address = excluded.address,
    url = excluded.url,
    icon_key = excluded.icon_key,
    sort_order = excluded.sort_order,
    updated_at = timezone('utc'::text, now());

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  ticket_type text not null check (ticket_type = any (array['bug'::text, 'contact'::text])),
  subject text not null check (char_length(btrim(subject)) between 3 and 160),
  status text not null default 'open' check (status = any (array['open'::text, 'in_progress'::text, 'resolved'::text, 'closed'::text])),
  priority text not null default 'normal' check (priority = any (array['low'::text, 'normal'::text, 'high'::text, 'urgent'::text])),
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  author_user_id uuid references auth.users(id) on delete set null,
  author_type text not null default 'user' check (author_type = any (array['user'::text, 'admin'::text, 'system'::text])),
  body text not null check (char_length(btrim(body)) between 1 and 10000),
  created_at timestamptz not null default timezone('utc'::text, now())
);

create table if not exists public.feature_requests (
  id uuid primary key default gen_random_uuid(),
  submitted_by uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 3 and 160),
  description text not null check (char_length(btrim(description)) between 1 and 10000),
  status text not null default 'submitted' check (status = any (array['submitted'::text, 'under_review'::text, 'planned'::text, 'in_progress'::text, 'released'::text, 'declined'::text])),
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

create table if not exists public.feature_request_votes (
  feature_request_id uuid not null references public.feature_requests(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default timezone('utc'::text, now()),
  primary key (feature_request_id, user_id)
);

create index if not exists support_tickets_user_created_idx
  on public.support_tickets (user_id, created_at desc);
create index if not exists support_messages_ticket_created_idx
  on public.support_messages (ticket_id, created_at asc);
create index if not exists feature_requests_submitted_by_created_idx
  on public.feature_requests (submitted_by, created_at desc);
create index if not exists feature_requests_status_created_idx
  on public.feature_requests (status, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists support_channels_set_updated_at on public.support_channels;
create trigger support_channels_set_updated_at
before update on public.support_channels
for each row execute function public.set_updated_at();

drop trigger if exists support_tickets_set_updated_at on public.support_tickets;
create trigger support_tickets_set_updated_at
before update on public.support_tickets
for each row execute function public.set_updated_at();

drop trigger if exists feature_requests_set_updated_at on public.feature_requests;
create trigger feature_requests_set_updated_at
before update on public.feature_requests
for each row execute function public.set_updated_at();

alter table public.support_channels enable row level security;
alter table public.support_tickets enable row level security;
alter table public.support_messages enable row level security;
alter table public.feature_requests enable row level security;
alter table public.feature_request_votes enable row level security;

drop policy if exists support_channels_read_active on public.support_channels;
create policy support_channels_read_active
on public.support_channels for select
to anon, authenticated
using (is_active = true);

drop policy if exists support_tickets_owner_read on public.support_tickets;
create policy support_tickets_owner_read
on public.support_tickets for select
to authenticated
using (user_id = auth.uid());

drop policy if exists support_tickets_owner_insert on public.support_tickets;
create policy support_tickets_owner_insert
on public.support_tickets for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists support_messages_owner_read on public.support_messages;
create policy support_messages_owner_read
on public.support_messages for select
to authenticated
using (exists (
  select 1
  from public.support_tickets ticket
  where ticket.id = support_messages.ticket_id
    and ticket.user_id = auth.uid()
));

drop policy if exists support_messages_owner_insert on public.support_messages;
create policy support_messages_owner_insert
on public.support_messages for insert
to authenticated
with check (
  author_user_id = auth.uid()
  and exists (
    select 1
    from public.support_tickets ticket
    where ticket.id = support_messages.ticket_id
      and ticket.user_id = auth.uid()
  )
);

drop policy if exists feature_requests_owner_read on public.feature_requests;
create policy feature_requests_owner_read
on public.feature_requests for select
to authenticated
using (submitted_by = auth.uid());

drop policy if exists feature_requests_owner_insert on public.feature_requests;
create policy feature_requests_owner_insert
on public.feature_requests for insert
to authenticated
with check (submitted_by = auth.uid());

drop policy if exists feature_request_votes_read on public.feature_request_votes;
create policy feature_request_votes_read
on public.feature_request_votes for select
to authenticated
using (user_id = auth.uid());

drop policy if exists feature_request_votes_insert on public.feature_request_votes;
create policy feature_request_votes_insert
on public.feature_request_votes for insert
to authenticated
with check (user_id = auth.uid());

commit;
