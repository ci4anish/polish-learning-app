-- OCR history: stores each OCR request result per user
create table if not exists public.ocr_history (
  id            uuid        primary key default gen_random_uuid(),
  user_id       uuid        not null references auth.users(id) on delete cascade,
  detected_language text    not null,
  blocks        jsonb       not null,
  model         text        not null,
  provider      text        not null,
  created_at    timestamptz not null default now()
);

alter table public.ocr_history enable row level security;

-- Users can only read their own OCR history
create policy "Users can view own ocr history"
  on public.ocr_history for select
  using (auth.uid() = user_id);

-- Service role (server-side) inserts on behalf of users
create policy "Service role can insert ocr history"
  on public.ocr_history for insert
  with check (true);

-- Index for fast per-user queries sorted by time
create index if not exists ocr_history_user_id_created_at_idx
  on public.ocr_history (user_id, created_at desc);
