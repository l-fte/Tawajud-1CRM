-- ============================================================
-- تواجد CRM — Supabase Schema
-- شغّل هذا الملف في SQL Editor داخل Supabase Dashboard
-- ============================================================

-- 1. LEADS TABLE (العملاء)
create table if not exists public.leads (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) not null default auth.uid(),
  name text not null,
  phone text not null,
  title text default '',
  company text default '',
  sector text default '',
  employees int,
  branches int default 1,
  current_sys text default '',
  disc text default '',
  stage text default 'lead',
  decision text default '',
  priority text default 'med',
  pain text default '',
  pain_level int default 5,
  conviction int default 5,
  objection text default '',
  pay_pref text default '',
  notes text default '',
  followups jsonb default '[]'::jsonb,
  history jsonb default '[]'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2. ACTIVITIES TABLE (النشاطات العامة)
create table if not exists public.activities (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) not null default auth.uid(),
  msg text not null,
  type text default 'note',
  created_at timestamptz default now()
);

-- 3. ENABLE ROW LEVEL SECURITY
alter table public.leads enable row level security;
alter table public.activities enable row level security;

-- 4. RLS POLICIES — كل مستخدم يشوف بس بياناته
drop policy if exists "Users can view their own leads" on public.leads;
create policy "Users can view their own leads"
  on public.leads for select
  using (auth.uid() = user_id);

drop policy if exists "Users can create their own leads" on public.leads;
create policy "Users can create their own leads"
  on public.leads for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own leads" on public.leads;
create policy "Users can update their own leads"
  on public.leads for update
  using (auth.uid() = user_id);

drop policy if exists "Users can delete their own leads" on public.leads;
create policy "Users can delete their own leads"
  on public.leads for delete
  using (auth.uid() = user_id);

drop policy if exists "Users can view their own activities" on public.activities;
create policy "Users can view their own activities"
  on public.activities for select
  using (auth.uid() = user_id);

drop policy if exists "Users can create their own activities" on public.activities;
create policy "Users can create their own activities"
  on public.activities for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own activities" on public.activities;
create policy "Users can delete their own activities"
  on public.activities for delete
  using (auth.uid() = user_id);

-- 5. INDEXES للسرعة
create index if not exists idx_leads_user on public.leads(user_id);
create index if not exists idx_leads_stage on public.leads(stage);
create index if not exists idx_leads_priority on public.leads(priority);
create index if not exists idx_activities_user on public.activities(user_id);
create index if not exists idx_activities_created on public.activities(created_at desc);

-- 6. AUTO UPDATE updated_at
create extension if not exists moddatetime schema extensions;

drop trigger if exists handle_updated_at on public.leads;
create trigger handle_updated_at before update on public.leads
  for each row execute function moddatetime(updated_at);

-- 7. ENABLE REALTIME (optional — للتحديث المباشر)
do $$
begin
  alter publication supabase_realtime add table public.leads;
exception when unique_violation then null;
end;
$$;
do $$
begin
  alter publication supabase_realtime add table public.activities;
exception when unique_violation then null;
end;
$$;
