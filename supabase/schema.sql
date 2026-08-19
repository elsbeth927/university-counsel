create extension if not exists pgcrypto;

create table if not exists public.student_pathways(id uuid primary key default gen_random_uuid(),student_name text,grade text,academic_year text default '2026–2027',form_data jsonb not null default '{}'::jsonb,status text not null default 'draft' check(status in('draft','submitted','reviewed')),submitted_at timestamptz not null default now(),updated_at timestamptz not null default now());
alter table public.student_pathways add column if not exists application_number text;
alter table public.student_pathways add column if not exists last_step smallint not null default 0;

update public.student_pathways set application_number='RB26-'||upper(substr(encode(gen_random_bytes(10),'hex'),1,5))||'-'||upper(substr(encode(gen_random_bytes(10),'hex'),1,5))||'-'||upper(substr(encode(gen_random_bytes(10),'hex'),1,5))||'-'||upper(substr(encode(gen_random_bytes(10),'hex'),1,5)) where application_number is null;
create unique index if not exists student_pathways_application_number_key on public.student_pathways(application_number);
alter table public.student_pathways alter column application_number set not null;
alter table public.student_pathways enable row level security;

revoke all on table public.student_pathways from anon;
grant select on table public.student_pathways to authenticated;
drop policy if exists "Allow anonymous questionnaire submissions" on public.student_pathways;

create table if not exists public.admin_users(user_id uuid primary key references auth.users(id) on delete cascade,created_at timestamptz not null default now());
alter table public.admin_users enable row level security;
grant select on table public.admin_users to authenticated;
drop policy if exists "Admins can see own membership" on public.admin_users;
create policy "Admins can see own membership" on public.admin_users for select to authenticated using(user_id=auth.uid());
drop policy if exists "Admins can read submissions" on public.student_pathways;
create policy "Admins can read submissions" on public.student_pathways for select to authenticated using(exists(select 1 from public.admin_users where user_id=auth.uid()));

create or replace function public.create_pathway_application(p_student_name text,p_grade text,p_academic_year text,p_form_data jsonb,p_last_step integer default 0,p_status text default 'draft') returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare v_number text;v_random text;
begin
  if p_status not in('draft','submitted') then raise exception 'Invalid status';end if;
  loop
    v_random:=upper(encode(gen_random_bytes(10),'hex'));
    v_number:='RB26-'||substr(v_random,1,5)||'-'||substr(v_random,6,5)||'-'||substr(v_random,11,5)||'-'||substr(v_random,16,5);
    begin
      insert into public.student_pathways(application_number,student_name,grade,academic_year,form_data,last_step,status,submitted_at,updated_at) values(v_number,nullif(p_student_name,''),nullif(p_grade,''),coalesce(p_academic_year,'2026–2027'),coalesce(p_form_data,'{}'::jsonb),greatest(0,least(4,p_last_step)),p_status,now(),now());
      return v_number;
    exception when unique_violation then null;end;
  end loop;
end;$$;

create or replace function public.load_pathway_application(p_application_number text) returns table(application_number text,student_name text,grade text,academic_year text,form_data jsonb,last_step smallint,status text,updated_at timestamptz) language sql security definer set search_path=public,pg_temp as $$
  select s.application_number,s.student_name,s.grade,s.academic_year,s.form_data,s.last_step,s.status,s.updated_at from public.student_pathways s where s.application_number=upper(trim(p_application_number)) limit 1;
$$;

create or replace function public.save_pathway_application(p_application_number text,p_student_name text,p_grade text,p_academic_year text,p_form_data jsonb,p_last_step integer default 0,p_status text default 'draft') returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if p_status not in('draft','submitted') then raise exception 'Invalid status';end if;
  update public.student_pathways set student_name=nullif(p_student_name,''),grade=nullif(p_grade,''),academic_year=coalesce(p_academic_year,'2026–2027'),form_data=coalesce(p_form_data,'{}'::jsonb),last_step=greatest(0,least(4,p_last_step)),status=p_status,submitted_at=case when p_status='submitted' then now() else submitted_at end,updated_at=now() where application_number=upper(trim(p_application_number));
  return found;
end;$$;

-- Apply permissions dynamically so Supabase resolves the functions only after
-- the CREATE FUNCTION statements above have completed.
do $permissions$
begin
  execute 'revoke all on function public.create_pathway_application(text,text,text,jsonb,integer,text) from public';
  execute 'revoke all on function public.load_pathway_application(text) from public';
  execute 'revoke all on function public.save_pathway_application(text,text,text,jsonb,integer,text) from public';
  execute 'grant execute on function public.create_pathway_application(text,text,text,jsonb,integer,text) to anon,authenticated';
  execute 'grant execute on function public.load_pathway_application(text) to anon,authenticated';
  execute 'grant execute on function public.save_pathway_application(text,text,text,jsonb,integer,text) to anon,authenticated';
end;
$permissions$;

-- Public users can access only a record whose complete, unguessable application number they possess.
-- After creating your Supabase Auth user, authorize it once with:
-- insert into public.admin_users(user_id) select id from auth.users where email='YOUR_ADMIN_EMAIL';
