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

-- 6. Grant basic API privileges (needed for RLS to evaluate policies for anon/authenticated roles)
grant select, insert, update, delete on public.profiles to anon, authenticated, service_role;

-- 7. Secure function to check username existence (bypasses RLS select blocks securely)
create or replace function public.check_username_exists(username_to_check text)
returns boolean as $$
begin
  return exists (
    select 1 from public.profiles where lower(username) = lower(username_to_check)
  );
end;
$$ language plpgsql security definer;

-- Grant execute permission on the check function to anonymous/authenticated API users
grant execute on function public.check_username_exists(text) to anon, authenticated;
