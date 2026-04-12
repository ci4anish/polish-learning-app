-- Chat threads: tracks each AI tutor conversation
create table if not exists public.chat_threads (
  id              uuid        primary key default gen_random_uuid(),
  user_id         uuid        not null references auth.users(id) on delete cascade,
  selected_text   text        not null,
  context_block   text,
  source_language text,
  created_at      timestamptz not null default now()
);

alter table public.chat_threads enable row level security;

create policy "Users can view own chat threads"
  on public.chat_threads for select
  using (auth.uid() = user_id);

create policy "Service role can insert chat threads"
  on public.chat_threads for insert
  with check (true);

create index if not exists chat_threads_user_id_created_at_idx
  on public.chat_threads (user_id, created_at desc);

-- Chat messages: stores conversation history per thread
create table if not exists public.chat_messages (
  id          uuid        primary key default gen_random_uuid(),
  thread_id   uuid        not null references public.chat_threads(id) on delete cascade,
  role        text        not null check (role in ('user', 'assistant')),
  content     text        not null,
  created_at  timestamptz not null default now()
);

alter table public.chat_messages enable row level security;

create policy "Users can view own chat messages"
  on public.chat_messages for select
  using (
    exists (
      select 1 from public.chat_threads
      where chat_threads.id = chat_messages.thread_id
        and chat_threads.user_id = auth.uid()
    )
  );

create policy "Service role can insert chat messages"
  on public.chat_messages for insert
  with check (true);

create index if not exists chat_messages_thread_created_at_idx
  on public.chat_messages (thread_id, created_at);
