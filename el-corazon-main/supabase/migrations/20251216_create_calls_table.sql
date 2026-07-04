-- Table de signalisation d'appels (Agora) : appel entrant/sortant + états
-- À appliquer dans Supabase SQL Editor ou via migrations.

create extension if not exists "pgcrypto";

create table if not exists public.calls (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  channel_id text not null,
  caller_id uuid not null,
  callee_id uuid not null,
  call_type text not null default 'audio',
  status text not null default 'ringing', -- ringing | accepted | declined | ended | missed
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists calls_order_id_idx on public.calls(order_id);
create index if not exists calls_callee_status_idx on public.calls(callee_id, status);

-- RLS (à adapter selon votre modèle users/public.users)
alter table public.calls enable row level security;

-- Autoriser lecture/écriture uniquement pour caller/callee (si auth.uid() correspond)
create policy "calls_select_participants"
on public.calls for select
using (auth.uid() = caller_id or auth.uid() = callee_id);

create policy "calls_insert_participants"
on public.calls for insert
with check (auth.uid() = caller_id);

create policy "calls_update_participants"
on public.calls for update
using (auth.uid() = caller_id or auth.uid() = callee_id)
with check (auth.uid() = caller_id or auth.uid() = callee_id);

-- Trigger updated_at
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists calls_set_updated_at on public.calls;
create trigger calls_set_updated_at
before update on public.calls
for each row execute function public.set_updated_at();


