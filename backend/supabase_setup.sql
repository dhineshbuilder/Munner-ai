-- SQL Setup for Munner-Ai (முன்னேறு AI) Supabase Database
-- Run this in the SQL Editor of your Supabase project dashboard.

-- 1. Create profiles table
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  username text unique not null,
  age integer not null check (age > 0 and age < 120),
  height float not null check (height > 30 and height < 300), -- in cm
  weight float not null check (weight > 10 and weight < 500), -- in kg
  phone_number text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Create updated_at trigger helper
create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$ language plpgsql;

-- 3. Set trigger on profiles
drop trigger if exists on_profiles_updated on public.profiles;
create trigger on_profiles_updated
  before update on public.profiles
  for each row execute procedure public.handle_updated_at();

-- 4. Enable Row Level Security
alter table public.profiles enable row level security;

-- 5. Define access policies
drop policy if exists "Users can view their own profile" on public.profiles;
create policy "Users can view their own profile" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile" on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile" on public.profiles
  for update using (auth.uid() = id);

-- 6. Grant basic API privileges
grant select, insert, update, delete on public.profiles to anon, authenticated, service_role;

-- 7. Secure function to check username existence
create or replace function public.check_username_exists(username_to_check text)
returns boolean as $$
begin
  return exists (
    select 1 from public.profiles where lower(username) = lower(username_to_check)
  );
end;
$$ language plpgsql security definer;

grant execute on function public.check_username_exists(text) to anon, authenticated, service_role;

-- 8. Secure function to upsert profile (allows backend to save verified profile securely)
create or replace function public.upsert_profile(
  p_id uuid,
  p_username text,
  p_age integer,
  p_height float,
  p_weight float,
  p_phone_number text
)
returns json as $$
declare
  v_result json;
begin
  insert into public.profiles (id, username, age, height, weight, phone_number, updated_at)
  values (p_id, p_username, p_age, p_height, p_weight, p_phone_number, timezone('utc'::text, now()))
  on conflict (id) do update set
    username = excluded.username,
    age = excluded.age,
    height = excluded.height,
    weight = excluded.weight,
    phone_number = excluded.phone_number,
    updated_at = timezone('utc'::text, now())
  returning to_json(profiles.*) into v_result;
  
  return v_result;
end;
$$ language plpgsql security definer;

grant execute on function public.upsert_profile to anon, authenticated, service_role;

-- 9. Secure function to get profile by user ID
create or replace function public.get_profile_by_id(p_id uuid)
returns json as $$
declare
  v_result json;
begin
  select to_json(p.*) into v_result
  from public.profiles p
  where p.id = p_id;
  
  return v_result;
end;
$$ language plpgsql security definer;

grant execute on function public.get_profile_by_id to anon, authenticated, service_role;
