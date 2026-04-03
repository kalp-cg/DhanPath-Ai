-- DhanPath SaaS dynamic schema (no static/mock data)
-- Run in Supabase SQL editor.

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  name text,
  created_at timestamptz not null default now()
);

create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text unique,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.family_members (
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin','member')),
  status text not null default 'accepted' check (status in ('pending','accepted','active','removed')),
  joined_at timestamptz not null default now(),
  primary key (family_id, user_id)
);

create table if not exists public.family_invitations (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  invited_email text not null,
  token uuid not null unique default gen_random_uuid(),
  invited_by uuid not null references auth.users(id) on delete cascade,
  accepted_by uuid references auth.users(id) on delete set null,
  status text not null default 'pending' check (status in ('pending','accepted','expired','revoked')),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  year int not null,
  month int not null check (month between 1 and 12),
  monthly_budget numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

create unique index if not exists budgets_family_year_month_uniq
  on public.budgets(family_id, year, month);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  amount numeric(12,2) not null,
  type text not null check (type in ('debit','credit')),
  category text not null default 'Uncategorized',
  merchant text,
  source text not null default 'manual' check (source in ('sms','manual','vision','voice')),
  txn_time timestamptz not null,
  client_txn_id text not null,
  transaction_hash text,
  created_at timestamptz not null default now()
);

create unique index if not exists tx_family_user_client_uniq
  on public.transactions(family_id, user_id, client_txn_id);

create index if not exists tx_family_time_idx
  on public.transactions(family_id, txn_time desc);

create index if not exists invite_email_status_idx
  on public.family_invitations(invited_email, status, expires_at);

alter table public.profiles enable row level security;
alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.family_invitations enable row level security;
alter table public.budgets enable row level security;
alter table public.transactions enable row level security;

drop policy if exists "profiles_self" on public.profiles;
create policy "profiles_self" on public.profiles
for select using (auth.uid() = id);

drop policy if exists "families_member_select" on public.families;
create policy "families_member_select" on public.families
for select using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = families.id
      and fm.user_id = auth.uid()
      and fm.status in ('accepted','active')
  )
);

drop policy if exists "members_self_select" on public.family_members;
create policy "members_self_select" on public.family_members
for select using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.family_members me
    where me.family_id = family_members.family_id
      and me.user_id = auth.uid()
      and me.status in ('accepted','active')
  )
);

drop policy if exists "invitations_for_email" on public.family_invitations;
create policy "invitations_for_email" on public.family_invitations
for select using (lower(invited_email) = lower(auth.email()));

drop policy if exists "transactions_member_select" on public.transactions;
create policy "transactions_member_select" on public.transactions
for select using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = transactions.family_id
      and fm.user_id = auth.uid()
      and fm.status in ('accepted','active')
  )
);
