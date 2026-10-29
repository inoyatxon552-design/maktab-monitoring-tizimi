-- MONITORING TIZIMI: Supabase schema
-- SQL Editor ga to'liq joylashtirib Run bosing. Mavjud jadvalga zararli DROP ishlatilmaydi.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '',
 role text not null default 'student' check(role in ('admin','student')),
 created_at timestamptz not null default now()
);
create table if not exists public.students (
 id uuid primary key default gen_random_uuid(),
 class_name text not null check(class_name in ('1-sinf','2-sinf','3-sinf','4-sinf','5-sinf','6-sinf','7-sinf','8-sinf','9-sinf','10-sinf','11-sinf')),
 full_name text not null, created_at timestamptz not null default now(), unique(class_name,full_name)
);
create table if not exists public.subjects(id uuid primary key default gen_random_uuid(),name text not null unique,created_at timestamptz not null default now());
create table if not exists public.monitoring_tests(
 id uuid primary key default gen_random_uuid(),class_name text not null,
 quarter smallint not null check(quarter between 1 and 4),block smallint not null check(block between 1 and 3),
 access_code_hash text not null,duration_seconds integer not null default 5400 check(duration_seconds between 60 and 86400),
 is_active boolean not null default true,created_at timestamptz not null default now(),unique(class_name,quarter,block)
);
create table if not exists public.test_subjects(
 test_id uuid not null references public.monitoring_tests(id) on delete cascade,
 subject_id uuid not null references public.subjects(id) on delete restrict,
 position smallint not null check(position between 1 and 3),primary key(test_id,position),unique(test_id,subject_id)
);
create table if not exists public.questions(
 id uuid primary key default gen_random_uuid(),subject_id uuid not null references public.subjects(id) on delete cascade,
 question_text text not null,options jsonb not null check(jsonb_typeof(options)='array' and jsonb_array_length(options)>=2),
 correct_option smallint not null check(correct_option>=0),is_active boolean not null default true,created_at timestamptz not null default now()
);
create table if not exists public.test_attempts(
 id uuid primary key default gen_random_uuid(),test_id uuid not null references public.monitoring_tests(id) on delete restrict,
 student_id uuid not null references public.students(id) on delete restrict,started_at timestamptz not null default now(),
 submitted_at timestamptz,status text not null default 'in_progress' check(status in ('in_progress','submitted','timed_out')),
 total_correct smallint,total_wrong smallint,total_score numeric(5,2),created_at timestamptz not null default now()
);
create table if not exists public.test_answers(
 id uuid primary key default gen_random_uuid(),attempt_id uuid not null references public.test_attempts(id) on delete cascade,
 question_id uuid not null references public.questions(id) on delete restrict,selected_option smallint not null check(selected_option>=0),
 is_correct boolean not null,mark smallint not null check(mark in (0,1)),subject_score numeric(5,2),unique(attempt_id,question_id)
);
create table if not exists public.results(
 id uuid primary key default gen_random_uuid(),attempt_id uuid not null unique references public.test_attempts(id) on delete cascade,
 class_name text not null,student_full_name text not null,quarter smallint not null,block smallint not null,
 subject_results jsonb not null default '[]'::jsonb,total_correct smallint not null default 0,total_wrong smallint not null default 0,
 total_score numeric(5,2) not null default 0,submitted_at timestamptz not null default now()
);
create table if not exists public.officials(
 id uuid primary key default gen_random_uuid(),role_title text not null check(role_title in ('Monitoring raisi','Kotibi','1-a’zo','2-a’zo','3-a’zo','4-a’zo')),
 full_name text not null default '',position smallint not null unique check(position between 1 and 6),updated_at timestamptz not null default now()
);
insert into public.officials(role_title,full_name,position) values
('Monitoring raisi','',1),('Kotibi','',2),('1-a’zo','',3),('2-a’zo','',4),('3-a’zo','',5),('4-a’zo','',6)
on conflict(position) do nothing;

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin');
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.subjects enable row level security;
alter table public.monitoring_tests enable row level security;
alter table public.test_subjects enable row level security;
alter table public.questions enable row level security;
alter table public.test_attempts enable row level security;
alter table public.test_answers enable row level security;
alter table public.results enable row level security;
alter table public.officials enable row level security;

drop policy if exists "profile read own or admin" on public.profiles;
create policy "profile read own or admin" on public.profiles for select to authenticated using(public.is_admin() or id=(select auth.uid()));
drop policy if exists "admin manage profiles" on public.profiles;
create policy "admin manage profiles" on public.profiles for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "admin manage students" on public.students;
create policy "admin manage students" on public.students for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "admin manage subjects" on public.subjects;
create policy "admin manage subjects" on public.subjects for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "admin manage tests" on public.monitoring_tests;
create policy "admin manage tests" on public.monitoring_tests for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "admin manage test subjects" on public.test_subjects;
create policy "admin manage test subjects" on public.test_subjects for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "admin manage questions" on public.questions;
create policy "admin manage questions" on public.questions for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "admin read attempts" on public.test_attempts;
create policy "admin read attempts" on public.test_attempts for select to authenticated using(public.is_admin());
drop policy if exists "admin read answers" on public.test_answers;
create policy "admin read answers" on public.test_answers for select to authenticated using(public.is_admin());
drop policy if exists "admin read results" on public.results;
create policy "admin read results" on public.results for select to authenticated using(public.is_admin());
drop policy if exists "admin manage officials" on public.officials;
create policy "admin manage officials" on public.officials for all to authenticated using(public.is_admin()) with check(public.is_admin());

revoke all on public.profiles,public.students,public.subjects,public.monitoring_tests,public.test_subjects,public.questions,public.test_attempts,public.test_answers,public.results,public.officials from anon,authenticated;
grant select,insert,update,delete on public.profiles,public.students,public.subjects,public.monitoring_tests,public.test_subjects,public.questions,public.officials to authenticated;
grant select on public.test_attempts,public.test_answers,public.results to authenticated;

-- Test javoblarini o'quvchi brauzeriga ochadigan RLS policy ataylab yo'q.
