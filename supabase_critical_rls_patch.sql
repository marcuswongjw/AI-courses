-- ============================================================
-- CRITICAL RLS PATCH — run on EXISTING AI Course Audit projects
-- Fixes: open course writes, is_admin self-promotion, open audit reads
-- Safe to re-run.
-- ============================================================

-- Helper
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select is_admin from public.profiles where id = auth.uid()),
    false
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- Guard: cannot set is_admin unless already admin
create or replace function public.profiles_guard_is_admin()
returns trigger
language plpgsql
as $$
begin
  if TG_OP = 'UPDATE'
     and NEW.is_admin is distinct from OLD.is_admin
     and not public.is_admin() then
    raise exception 'Only an existing admin can change is_admin';
  end if;
  if TG_OP = 'INSERT' and NEW.is_admin = true and not public.is_admin() then
    NEW.is_admin := false;
  end if;
  return NEW;
end;
$$;

drop trigger if exists profiles_guard_is_admin on public.profiles;
create trigger profiles_guard_is_admin
  before insert or update on public.profiles
  for each row execute function public.profiles_guard_is_admin();

-- Guard: non-admins only touch courses.status
create or replace function public.courses_guard_non_admin()
returns trigger
language plpgsql
as $$
begin
  if public.is_admin() then
    return case when TG_OP = 'DELETE' then OLD else NEW end;
  end if;

  if TG_OP = 'INSERT' or TG_OP = 'DELETE' then
    raise exception 'Only admins can add or delete courses';
  end if;

  -- Allow status-only changes (claim/unclaim); block any other column edits
  if (to_jsonb(NEW) - 'status') is distinct from (to_jsonb(OLD) - 'status') then
    raise exception 'Only admins can edit course details';
  end if;

  return NEW;
end;
$$;

drop trigger if exists courses_guard_non_admin on public.courses;
create trigger courses_guard_non_admin
  before insert or update or delete on public.courses
  for each row execute function public.courses_guard_non_admin();

-- Replace policies
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
  for select to authenticated using (true);

create policy "profiles_insert" on public.profiles
  for insert to authenticated with check (auth.uid() = id and is_admin = false);

create policy "profiles_update_self" on public.profiles
  for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- COURSES
create policy "courses_select" on public.courses
  for select to authenticated using (true);

create policy "courses_insert" on public.courses
  for insert to authenticated with check (public.is_admin());

create policy "courses_update" on public.courses
  for update to authenticated using (true) with check (true);

create policy "courses_delete" on public.courses
  for delete to authenticated using (public.is_admin());

-- AVAILABILITY
create policy "availability_select" on public.availability
  for select to authenticated
  using (auth.uid() = user_id or public.is_admin());

create policy "availability_insert" on public.availability
  for insert to authenticated with check (auth.uid() = user_id);

create policy "availability_update" on public.availability
  for update to authenticated using (auth.uid() = user_id);

-- AUDITS (private evaluations)
create policy "audits_select" on public.audits
  for select to authenticated
  using (auth.uid() = user_id or public.is_admin());

create policy "audits_insert" on public.audits
  for insert to authenticated with check (auth.uid() = user_id);

create policy "audits_update" on public.audits
  for update to authenticated
  using (auth.uid() = user_id or public.is_admin());

create policy "audits_delete" on public.audits
  for delete to authenticated
  using (auth.uid() = user_id or public.is_admin());

-- Verify as a normal user in SQL (optional):
--   select public.is_admin();  -- should be false for non-admin
-- Admins still set is_admin in Table Editor (service role bypasses RLS/triggers? 
--   Table Editor as postgres/superuser bypasses; Auth users cannot self-promote.)
