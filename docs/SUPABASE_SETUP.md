# Setting up the Supabase backend (one-time)

You only do this once for the whole team. The output is a `SUPABASE_URL` and `SUPABASE_ANON_KEY` that everyone pastes into their `.env`.

## 1. Create the project

1. Go to [supabase.com](https://supabase.com) and sign in with GitHub.
2. New project → Name: `venn` → Pick a strong database password (save it in 1Password). Pick a region close to most users.
3. Wait ~2 minutes for provisioning.

## 2. Find your keys

Project settings → API → copy:

- **Project URL** → this is `EXPO_PUBLIC_SUPABASE_URL`.
- **anon / public** key → this is `EXPO_PUBLIC_SUPABASE_ANON_KEY`. Safe to ship to clients.
- **service_role** key → server-side only. **Never** put this in the mobile app.

## 3. Share the keys with your team securely

- Use a password manager (1Password shared vault is ideal).
- **Do NOT** paste them in Slack, email, or any file inside the repo.
- The anon key is technically "safe" to expose, but keep it out of public channels anyway.

## 4. Create the starter tables

SQL Editor → New query → paste and run:

```sql
-- Profiles (extends Supabase's built-in auth.users)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text,
  avatar_url text,
  bio text,
  created_at timestamptz not null default now()
);

-- Posts
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  caption text not null,
  media_url text,
  like_count integer not null default 0,
  comment_count integer not null default 0,
  created_at timestamptz not null default now()
);

create index posts_created_at_idx on public.posts (created_at desc);
create index posts_author_id_idx on public.posts (author_id);

-- Row-level security: the golden rule of Supabase.
alter table public.profiles enable row level security;
alter table public.posts enable row level security;

-- Anyone can read profiles and posts.
create policy "profiles_select_all" on public.profiles for select using (true);
create policy "posts_select_all" on public.posts for select using (true);

-- Users can only insert/update their own profile.
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

-- Users can only insert posts as themselves, and only edit/delete their own.
create policy "posts_insert_own" on public.posts for insert with check (auth.uid() = author_id);
create policy "posts_update_own" on public.posts for update using (auth.uid() = author_id);
create policy "posts_delete_own" on public.posts for delete using (auth.uid() = author_id);
```

## 5. Test it

Back in the mobile app:

```bash
cd apps/mobile
cp .env.example .env
# paste the URL and anon key into .env
npm run mobile
```

Open the app in Expo Go, go to Profile → Sign in → Create account. If it succeeds and you see yourself in Supabase → Authentication → Users, the wiring is correct.

## Next steps (not today)

- Add a `storage` bucket for post media. Supabase → Storage → New bucket → `post-media`.
- Add realtime subscriptions for the feed.
- Add indexes and RLS policies for comments, likes, follows when you implement those.
