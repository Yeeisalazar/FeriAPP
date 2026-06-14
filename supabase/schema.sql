-- FeriAPP schema base + panel privado de administracion.
-- Se puede ejecutar varias veces sin romper por policies existentes.

create extension if not exists pgcrypto;

-- ── Tablas principales ──────────────────────────────────────────────────────
create table if not exists public.perfiles (
  id uuid references auth.users(id) on delete cascade primary key,
  nombre_usuario text,
  email_contacto text,
  nombre_emprendimiento text,
  tipo text,
  canal_principal text,
  es_premium boolean default false,
  es_admin boolean default false,
  api_key_ia text,
  created_at timestamptz default now()
);

alter table public.perfiles add column if not exists es_admin boolean default false;
alter table public.perfiles add column if not exists api_key_ia text;
alter table public.perfiles add column if not exists nombre_usuario text;
alter table public.perfiles add column if not exists email_contacto text;

create table if not exists public.productos (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  nombre text not null,
  precio integer not null,
  costo integer,
  sin_costo boolean default false,
  emoji text default '📦',
  color text default '#E8D5C4',
  activo boolean default true,
  created_at timestamptz default now()
);

create table if not exists public.ventas (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  fecha date not null,
  canal text,
  items jsonb not null,
  created_at timestamptz default now()
);

create table if not exists public.sobrantes (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  fecha date not null,
  items jsonb not null,
  created_at timestamptz default now()
);

-- ── Datos de negocio para la dueña de FeriAPP ───────────────────────────────
create table if not exists public.admin_users (
  user_id uuid references auth.users(id) on delete cascade primary key,
  created_at timestamptz default now()
);

create table if not exists public.usage_events (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade,
  event_name text not null,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

create table if not exists public.recomendaciones (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  tipo text not null,
  titulo text,
  mensaje text not null,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

create table if not exists public.suscripciones (
  user_id uuid references auth.users(id) on delete cascade primary key,
  plan text default 'libre',
  estado text default 'activo',
  precio_clp integer,
  started_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Funcion segura para policies admin.
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.admin_users
    where user_id = auth.uid()
  );
$$;

-- Perfil automatico al crear usuario OAuth/email.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.perfiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── RLS ─────────────────────────────────────────────────────────────────────
alter table public.perfiles enable row level security;
alter table public.productos enable row level security;
alter table public.ventas enable row level security;
alter table public.sobrantes enable row level security;
alter table public.admin_users enable row level security;
alter table public.usage_events enable row level security;
alter table public.recomendaciones enable row level security;
alter table public.suscripciones enable row level security;

-- Elimina policies antiguas o duplicadas de tus queries previas.
drop policy if exists "usuarios propios" on public.perfiles;
drop policy if exists "usuarios propios" on public.productos;
drop policy if exists "usuarios propios" on public.ventas;
drop policy if exists "usuarios propios" on public.sobrantes;
drop policy if exists "own_perfil" on public.perfiles;
drop policy if exists "own_productos" on public.productos;
drop policy if exists "own_ventas" on public.ventas;
drop policy if exists "own_sobrantes" on public.sobrantes;

drop policy if exists "perfiles_select_own_or_admin" on public.perfiles;
drop policy if exists "perfiles_insert_own_or_admin" on public.perfiles;
drop policy if exists "perfiles_update_own_or_admin" on public.perfiles;
drop policy if exists "productos_own_or_admin" on public.productos;
drop policy if exists "ventas_own_or_admin" on public.ventas;
drop policy if exists "sobrantes_own_or_admin" on public.sobrantes;
drop policy if exists "usage_events_own_or_admin" on public.usage_events;
drop policy if exists "recomendaciones_own_or_admin" on public.recomendaciones;
drop policy if exists "suscripciones_own_or_admin" on public.suscripciones;
drop policy if exists "admin_users_admin_only" on public.admin_users;

create policy "perfiles_select_own_or_admin"
on public.perfiles for select to authenticated
using (auth.uid() = id or public.is_admin());

create policy "perfiles_insert_own_or_admin"
on public.perfiles for insert to authenticated
with check (auth.uid() = id or public.is_admin());

create policy "perfiles_update_own_or_admin"
on public.perfiles for update to authenticated
using (auth.uid() = id or public.is_admin())
with check (auth.uid() = id or public.is_admin());

create policy "productos_own_or_admin"
on public.productos for all to authenticated
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

create policy "ventas_own_or_admin"
on public.ventas for all to authenticated
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

create policy "sobrantes_own_or_admin"
on public.sobrantes for all to authenticated
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

create policy "usage_events_own_or_admin"
on public.usage_events for all to authenticated
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

create policy "recomendaciones_own_or_admin"
on public.recomendaciones for all to authenticated
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

create policy "suscripciones_own_or_admin"
on public.suscripciones for all to authenticated
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

create policy "admin_users_admin_only"
on public.admin_users for select to authenticated
using (public.is_admin());

-- Ejecuta esto una vez, cambiando el email por el tuyo:
-- insert into public.admin_users (user_id)
-- select id from auth.users where email = 'TU_EMAIL@gmail.com'
-- on conflict (user_id) do nothing;
--
-- update public.perfiles
-- set es_admin = true
-- where id in (select user_id from public.admin_users);
