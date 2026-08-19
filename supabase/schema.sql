create extension if not exists pgcrypto;
create table if not exists public.student_pathways(id uuid primary key default gen_random_uuid(),student_name text,grade text,academic_year text default '2026–2027',form_data jsonb not null default '{}'::jsonb,status text not null default 'draft' check(status in('draft','submitted','reviewed')),submitted_at timestamptz not null default now(),updated_at timestamptz not null default now());
alter table public.student_pathways enable row level security;
grant insert on table public.student_pathways to anon;
drop policy if exists "Allow anonymous questionnaire submissions" on public.student_pathways;
create policy "Allow anonymous questionnaire submissions" on public.student_pathways for insert to anon with check(status='submitted');
-- Public visitors may submit but cannot read responses. Review data in Supabase.
