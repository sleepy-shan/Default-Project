-- Dartotsu Web — initial Supabase schema
--
-- Apply with `supabase db push` (or paste into the SQL editor) before
-- building the app with SUPABASE_URL / SUPABASE_ANON_KEY.
--
-- Every table holding user data has Row Level Security enabled so a
-- signed-in user can only read/write their own rows.

-- ---------------------------------------------------------------- profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  email text,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles are self-readable" on public.profiles;
create policy "profiles are self-readable"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "profiles are self-writable" on public.profiles;
create policy "profiles are self-writable"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "profiles are self-updatable" on public.profiles;
create policy "profiles are self-updatable"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ------------------------------------------------------- user_media_lists
-- Personal tracking entries. Metadata (title, cover, total) is
-- denormalized from AniList at save time, which is enough to render the
-- list without duplicating the third-party catalog.
create table if not exists public.user_media_lists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  media_id integer not null,
  media_type text not null check (media_type in ('ANIME', 'MANGA')),
  title text not null,
  cover_url text,
  total_units integer check (total_units is null or total_units >= 0),
  status text not null check (status in ('CURRENT', 'PLANNING', 'COMPLETED', 'PAUSED', 'DROPPED')),
  progress integer not null default 0 check (progress >= 0),
  score integer check (score is null or (score between 0 and 10)),
  notes text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, media_id, media_type)
);

create index if not exists user_media_lists_user_idx
  on public.user_media_lists (user_id, updated_at desc);

alter table public.user_media_lists enable row level security;

drop policy if exists "own list rows" on public.user_media_lists;
create policy "own list rows"
  on public.user_media_lists for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Keep updated_at fresh on every write.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists user_media_lists_touch_updated_at on public.user_media_lists;
create trigger user_media_lists_touch_updated_at
  before update on public.user_media_lists
  for each row execute function public.touch_updated_at();

-- ----------------------------------------------------------- user_settings
create table if not exists public.user_settings (
  user_id uuid primary key references auth.users on delete cascade,
  theme text not null default 'system' check (theme in ('system', 'light', 'dark')),
  language text not null default 'en',
  preferences jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.user_settings enable row level security;

drop policy if exists "own settings" on public.user_settings;
create policy "own settings"
  on public.user_settings for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
