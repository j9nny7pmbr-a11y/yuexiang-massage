-- Run in Supabase SQL editor. Change the admin email below before deploying.
create extension if not exists pgcrypto;
create table public.staff (id uuid primary key default gen_random_uuid(), name_zh text not null, name_en text not null, active boolean not null default true);
create table public.services (id uuid primary key default gen_random_uuid(), name_zh text not null, name_en text not null, duration_minutes integer not null check(duration_minutes in (30,60,90,120)), price numeric(10,2) not null check(price>=0), active boolean not null default true);
create table public.bookings (id uuid primary key default gen_random_uuid(), service_id uuid not null references public.services(id), staff_id uuid not null references public.staff(id), start_at timestamptz not null, end_at timestamptz not null, customer_name text not null, customer_phone text not null, status text not null default 'pending' check(status in ('pending','confirmed','cancelled')), created_at timestamptz not null default now(), check(end_at>start_at));
create table public.admin_users (user_id uuid primary key references auth.users(id) on delete cascade);
create index bookings_staff_start_idx on public.bookings(staff_id,start_at);
create index bookings_start_idx on public.bookings(start_at);
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.admin_users where user_id=auth.uid()) $$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;
alter table public.staff enable row level security;
alter table public.services enable row level security;
alter table public.bookings enable row level security;
alter table public.admin_users enable row level security;
create policy "staff visible" on public.staff for select to anon,authenticated using(active or public.is_admin());
create policy "services visible" on public.services for select to anon,authenticated using(active or public.is_admin());
create policy "admin staff write" on public.staff for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin services write" on public.services for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin bookings read" on public.bookings for select to authenticated using(public.is_admin());
create policy "admin bookings update" on public.bookings for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin users self read" on public.admin_users for select to authenticated using(user_id=auth.uid());
-- Public bookings use a validated RPC: do not expose raw booking inserts or customer PII.
create or replace function public.create_booking(p_service_id uuid,p_staff_id uuid,p_start_at timestamptz,p_customer_name text,p_customer_phone text)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_duration int; v_end timestamptz; v_id uuid; v_local timestamp;
begin
  if length(trim(p_customer_name)) not between 1 and 100 or length(trim(p_customer_phone)) not between 7 and 30 then raise exception 'Invalid contact information'; end if;
  select duration_minutes into v_duration from public.services where id=p_service_id and active;
  if v_duration is null or not exists(select 1 from public.staff where id=p_staff_id and active) then raise exception 'Invalid service or staff'; end if;
  v_end:=p_start_at+make_interval(mins=>v_duration);
  v_local:=p_start_at at time zone 'America/Los_Angeles';
  if p_start_at<=now() or p_start_at>now()+interval '60 days' or v_local::time < time '10:00' or (v_end at time zone 'America/Los_Angeles')::date <> v_local::date or (v_end at time zone 'America/Los_Angeles')::time > time '22:00' then raise exception 'Outside booking hours'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_staff_id::text,0));
  if exists(select 1 from public.bookings where staff_id=p_staff_id and status<>'cancelled' and start_at<v_end and end_at>p_start_at) then raise exception 'Time slot already booked'; end if;
  insert into public.bookings(service_id,staff_id,start_at,end_at,customer_name,customer_phone) values(p_service_id,p_staff_id,p_start_at,v_end,trim(p_customer_name),trim(p_customer_phone)) returning id into v_id;
  return v_id;
end $$;
revoke all on function public.create_booking(uuid,uuid,timestamptz,text,text) from public;
grant execute on function public.create_booking(uuid,uuid,timestamptz,text,text) to anon,authenticated;
insert into public.staff(name_zh,name_en) values ('技师 A','Therapist A'),('技师 B','Therapist B'),('技师 C','Therapist C');
insert into public.services(name_zh,name_en,duration_minutes,price) values ('全身按摩','Full Body Massage',60,70),('足底按摩','Foot Massage',30,40),('精油按摩','Aromatherapy Massage',60,85),('深层按摩','Deep Tissue Massage',90,120);
-- After creating the owner account in Supabase Authentication, run:
-- insert into public.admin_users(user_id) select id from auth.users where email='OWNER_EMAIL@example.com';
