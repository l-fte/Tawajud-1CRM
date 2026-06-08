-- ============================================================
-- تواجد CRM — Admin Migration
-- شغّل هذا الملف في SQL Editor داخل Supabase Dashboard
-- (شغّله بعد supabase-schema.sql)
-- ============================================================

-- 1. PROFILES TABLE — create if missing, add columns if missing
create table if not exists public.profiles (
  id uuid references auth.users(id) primary key,
  email text,
  full_name text,
  is_admin boolean default false,
  created_at timestamptz default now()
);

-- Add columns in case the table existed from Supabase default template
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists full_name text;
alter table public.profiles add column if not exists is_admin boolean default false;
alter table public.profiles add column if not exists created_at timestamptz default now();

-- 2. AUTO-CREATE PROFILE for new users
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 3. POPULATE profiles for existing users
insert into public.profiles (id, email, full_name)
select id, email, raw_user_meta_data ->> 'full_name' from auth.users
on conflict (id) do update set
  email = excluded.email,
  full_name = excluded.full_name;

-- 4. MAKE FIRST USER ADMIN
update public.profiles
set is_admin = true
where id = (select id from public.profiles order by created_at limit 1);

-- 5. ENABLE RLS on profiles
alter table public.profiles enable row level security;

-- IMPORTANT: drop any existing policies first to avoid conflicts
drop policy if exists "Profiles: view own or admin all" on public.profiles;
drop policy if exists "Profiles: select own" on public.profiles;
drop policy if exists "Profiles: select all for admins" on public.profiles;
drop policy if exists "Profiles: insert own" on public.profiles;
drop policy if exists "Profiles: update own" on public.profiles;

-- Helper function (security definer = bypasses RLS, breaking the recursion)
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and is_admin = true
  );
$$;

-- Regular users: see only their own profile
create policy "Profiles: select own"
  on public.profiles for select
  using (auth.uid() = id);

-- Admins: see all profiles (via security definer function — no recursion)
create policy "Profiles: select all for admins"
  on public.profiles for select
  using (public.is_admin());

create policy "Profiles: insert own"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Profiles: update own"
  on public.profiles for update
  using (auth.uid() = id);

-- 6. UPDATED RLS — leads: admin sees all
drop policy if exists "Users can view their own leads" on public.leads;
drop policy if exists "Leads: view own or admin all" on public.leads;
drop policy if exists "Leads: select own or admin all" on public.leads;

create policy "Leads: select own or admin all"
  on public.leads for select
  using (
    user_id = auth.uid()
    or public.is_admin()
  );

-- 7. UPDATED RLS — activities: admin sees all
drop policy if exists "Users can view their own activities" on public.activities;
drop policy if exists "Activities: view own or admin all" on public.activities;
drop policy if exists "Activities: select own or admin all" on public.activities;

create policy "Activities: select own or admin all"
  on public.activities for select
  using (
    user_id = auth.uid()
    or public.is_admin()
  );
