create extension if not exists pgcrypto;
create table if not exists public.student_pathways(id uuid primary key default gen_random_uuid(),student_name text,grade text,academic_year text default '2026–2027',form_data jsonb not null default '{}'::jsonb,status text not null default 'draft' check(status in('draft','submitted','reviewed')),submitted_at timestamptz not null default now(),updated_at timestamptz not null default now());
alter table public.student_pathways enable row level security;
grant insert on table public.student_pathways to anon;
drop policy if exists "Allow anonymous questionnaire submissions" on public.student_pathways;
create policy "Allow anonymous questionnaire submissions" on public.student_pathways for insert to anon with check(status='submitted');
grant select on table public.student_pathways to authenticated;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admin_users enable row level security;
grant select on table public.admin_users to authenticated;

drop policy if exists "Admins can see own membership" on public.admin_users;
create policy "Admins can see own membership" on public.admin_users
for select to authenticated using (user_id = auth.uid());

drop policy if exists "Admins can read submissions" on public.student_pathways;
create policy "Admins can read submissions" on public.student_pathways
for select to authenticated using (
  exists (select 1 from public.admin_users where user_id = auth.uid())
);

-- Public visitors can submit but cannot read, edit, or delete responses.
-- After creating your Supabase Auth user, authorize it once with:
-- insert into public.admin_users(user_id)
-- select id from auth.users where email = 'YOUR_ADMIN_EMAIL';
