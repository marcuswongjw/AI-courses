-- ============================================================
-- AI Course Audit Tracker — Supabase Schema
-- Run this entire file in the Supabase SQL Editor
-- ============================================================

-- ---- TABLES ----

create table if not exists public.profiles (
  id          uuid references auth.users on delete cascade primary key,
  full_name   text not null default '',
  is_admin    boolean not null default false,
  created_at  timestamptz not null default now()
);

create table if not exists public.courses (
  id          uuid default gen_random_uuid() primary key,
  tgs_number  text,
  name        text not null,
  pick        integer check (pick in (1, 2, 3)),
  archetype   text,
  status      text not null default 'Unassigned'
                check (status in ('Unassigned','Claimed','Confirmed','Completed')),
  next_run     text,
  course_fee   text,
  recommended  boolean not null default false,
  created_at   timestamptz not null default now()
);

create table if not exists public.availability (
  id          uuid default gen_random_uuid() primary key,
  user_id     uuid references public.profiles(id) on delete cascade not null,
  days        text[] not null default '{}',
  updated_at  timestamptz not null default now(),
  unique(user_id)
);

create table if not exists public.audits (
  id             uuid default gen_random_uuid() primary key,
  course_id      uuid references public.courses(id) on delete cascade not null,
  user_id        uuid references public.profiles(id) on delete cascade not null,
  preferred_date text,
  confirmed      boolean not null default false,
  responses      jsonb not null default '{}'::jsonb,
  submitted_at   timestamptz,
  created_at     timestamptz not null default now(),
  unique(course_id, user_id)
);

-- ---- PROFILE AUTO-CREATE TRIGGER ----

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---- ROW LEVEL SECURITY ----

alter table public.profiles    enable row level security;
alter table public.courses     enable row level security;
alter table public.availability enable row level security;
alter table public.audits      enable row level security;

-- Drop existing policies (safe to re-run)
do $$ declare r record;
begin
  for r in select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('profiles','courses','availability','audits')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- PROFILES
create policy "profiles_select" on public.profiles
  for select using (true);

create policy "profiles_insert" on public.profiles
  for insert with check (auth.uid() = id);

create policy "profiles_update" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- COURSES
create policy "courses_select" on public.courses
  for select using (true);

create policy "courses_insert" on public.courses
  for insert to authenticated with check (true);

create policy "courses_update" on public.courses
  for update to authenticated using (true) with check (true);

-- AVAILABILITY
create policy "availability_select" on public.availability
  for select using (true);

create policy "availability_insert" on public.availability
  for insert to authenticated with check (auth.uid() = user_id);

create policy "availability_update" on public.availability
  for update to authenticated using (auth.uid() = user_id);

-- AUDITS
create policy "audits_select" on public.audits
  for select using (true);

create policy "audits_insert" on public.audits
  for insert to authenticated with check (auth.uid() = user_id);

-- Users can update own audits; admins can update any audit (for confirm flow)
create policy "audits_update" on public.audits
  for update to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.profiles
      where id = auth.uid() and is_admin = true
    )
  );

create policy "audits_delete" on public.audits
  for delete to authenticated using (auth.uid() = user_id);

-- ---- SEED: 35 COURSES ----

insert into public.courses (tgs_number, name, pick, archetype, next_run, course_fee, status) values

-- === TIER 1 ===
('TGS-2024051374',
 'NUS: (Generative) AI for Business Leaders',
 1, 'AI Fluent Biz Leaders',
 '15-16 Jun', '$600', 'Unassigned'),

('TGS-2024049683',
 'NP: Empowering Your Workforce with Generative AI',
 1, 'AI Fluent Biz Leaders',
 '11–12 May, 13–14 May, 18–19 May, 20–21 May', '$228', 'Unassigned'),

('TGS-2025054901',
 'SUTD: From AI Awareness to Application',
 1, 'AI Literate Workers',
 '30 Apr, 12 May', '$300', 'Unassigned'),

('TGS-2025054902',
 'SUTD: From AI Strategy to Solutioning',
 1, 'AI Fluent Workers',
 '12 May', '$300', 'Unassigned'),

('TGS-2023021482',
 'RP: Mastering Prompt Engineering for Generative AI',
 1, 'AI Literate Workers',
 '3 May, 9 May, 10 May, 16 May, 17 May, 23 May', '$105', 'Unassigned'),

('TGS-2022014977',
 'Tertiary Infotech: Python Text Mining and Analytics',
 1, 'AI Fluent Workers',
 '1-4 May, 16-17 May, 29 May–1 Jun', '$360', 'Unassigned'),

('TGS-2023035856',
 'NTUC: SkillsFuture for Digital Workplace 2.0 (2 days)',
 1, 'AI Literate Workers',
 '2-3 May', '$225', 'Unassigned'),

('TGS-2023021351',
 'SMU: Tapping into the Future of Business Writing with ChatGPT',
 1, 'AI Literate Workers',
 '11-12 Jun', '$600', 'Unassigned'),

-- === TIER 2 ===
('TGS-2023020641',
 'NYP: Apply Generative AI for your Industry',
 2, 'AI Fluent Workers',
 '1-2 Jul', '$157.50', 'Unassigned'),

('TGS-2023037568',
 'SP: Building a Low-Code Application With Generative AI',
 2, 'AI Fluent Workers',
 '11 Jul', '$138', 'Unassigned'),

('TGS-2025055121',
 'ITE: CoC in Fundamentals of AI Applications',
 2, 'AI Literate Workers',
 '9 Jul', '$93', 'Unassigned'),

('TGS-2023020640',
 'NYP: Demystify Generative Artificial Intelligence',
 2, 'AI Literate Workers',
 '29 May, 26 Jun, 24 Jul', '$90', 'Unassigned'),

('TGS-2024051951',
 'Eon Consulting: Effective Email Writing with Generative AI',
 2, 'AI Literate Workers',
 '7 Jul', '$185', 'Unassigned'),

('TGS-2023037496',
 'JCI: SkillsFuture for Digital Workplace 2.0 Generic',
 2, 'AI Literate Workers',
 '7-8 May, 25-26 May, 29-30 Jun', '$159', 'Unassigned'),

('TGS-2025053099',
 'SP: Transforming Workforce Learning and Performance with GenAI',
 2, 'AI Fluent Biz Leaders',
 '16 Jun, 23 Jun, 23 Aug', '$144', 'Unassigned'),

-- === TIER 3 ===
('TGS-2024048183',
 'NUS: AI to Supercharge Products & Workflows',
 3, 'AI Fluent Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2025056194',
 'NUS: ChatGPT Begins With Me',
 3, 'AI Literate Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2024042330',
 'ITE: CoC in Introduction to Generative AI',
 3, 'AI Literate Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2023039709',
 'SUSS: Content Creation & Storytelling using Generative AI',
 3, 'AI Literate Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2023037589',
 'Tertiary Infotech: Create Engaging Content with Generative AI',
 3, 'AI Literate Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2024051901',
 'NTUC: Designing and Implementing a Microsoft Azure AI Solution',
 3, 'AI Fluent Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2023037807',
 'NYP: Digital Transformation: SkillsFuture for Digital Workplace 2.0',
 3, 'AI Literate Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2023039891',
 'Impact Management Seminars: Drive Productivity with Technology',
 3, 'AI Literate Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2024049182',
 'Tertiary Infotech: Driving Digital Transformation with Microsoft 365 Copilot',
 3, 'AI Fluent Biz Leaders',
 'TBC', '—', 'Unassigned'),

('TGS-2025058665',
 'NTU: Finance, AI and Analytics for Management',
 3, 'AI Fluent Biz Leaders',
 '7-10 Jul', '$2100', 'Unassigned'),

('TGS-2023040707',
 'NP: Generative AI for Productivity',
 3, 'AI Literate Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2023038832',
 'SIT: Generative Artificial Intelligence Fundamentals',
 3, 'AI Literate Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2024048928',
 'SMU: Introduction to Deep Learning',
 3, 'AI Fluent Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2021002592',
 'RP: Introduction to Speech Recognition Technology',
 3, 'AI Fluent Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2025059874',
 'Korn Ferry: Leveraging AI for Effective People Management',
 3, 'AI Fluent Biz Leaders',
 'TBC', '—', 'Unassigned'),

('TGS-2023025967',
 'TP: Machine Learning in Practice',
 3, 'AI Fluent Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2025057921',
 'Ascendo Academy: SkillsFuture Digital Workplace 2.0 (1 day)',
 3, 'AI Literate Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2023040688',
 'Eduquest International Institute: SkillsFuture for Digital Workplace 2.0',
 3, 'AI Literate Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2023038595',
 'Capelle Consulting: SkillsFuture for Digital Workplace 2.0 (2 Days)',
 3, 'AI Literate Workers',
 'TBC', '—', 'Unassigned'),

('TGS-2024048398',
 'SUTD: Strategic Design, AI and Technology Integration for Executives',
 3, 'AI Fluent Biz Leaders',
 'TBC', '—', 'Unassigned');

-- ============================================================
-- MIGRATION: if you ran the schema before the "recommended" column
-- was added, run this once to add it to an existing database:
--   alter table public.courses
--     add column if not exists recommended boolean not null default false;
-- ============================================================

-- ============================================================
-- DONE. Verify with:
--   select count(*) from courses;   -- should be 35
--   select count(*) from profiles;  -- should be 0 (fills on signup)
-- ============================================================
