-- ASBooka: общая база для всех платформ.
-- Таблицы: профили, проекты и участники, задачи, заметки с вложениями,
-- календари, учётные записи CalDAV и события.

-- ---------------------------------------------------------------------------
-- Профили
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  phone text unique,             -- только цифры, например 79161234567
  yandex_id text unique,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Только цифры; российские 8XXXXXXXXXX и XXXXXXXXXX приводятся к 7XXXXXXXXXX.
create or replace function public.normalize_phone(p text)
returns text language plpgsql immutable as $$
declare
  d text := regexp_replace(coalesce(p, ''), '\D', '', 'g');
begin
  if char_length(d) = 11 and left(d, 1) = '8' then
    d := '7' || substr(d, 2);
  elsif char_length(d) = 10 and left(d, 1) = '9' then
    d := '7' || d;
  end if;
  return nullif(d, '');
end $$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Проекты
-- ---------------------------------------------------------------------------

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 200),
  description text not null default '',
  color bigint not null default 4282339765,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger projects_touch before update on public.projects
  for each row execute function public.touch_updated_at();

create type public.project_role as enum ('owner', 'editor', 'viewer');

create table public.project_members (
  project_id uuid not null references public.projects (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.project_role not null default 'editor',
  created_at timestamptz not null default now(),
  primary key (project_id, user_id)
);

create index project_members_user_idx on public.project_members (user_id);

-- Приглашения: по номеру телефона (ждут регистрации) или по коду.
create table public.project_invites (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  invited_by uuid not null default auth.uid() references auth.users (id) on delete cascade,
  phone text,
  code text unique,
  role public.project_role not null default 'editor',
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '14 days',
  accepted_by uuid references auth.users (id) on delete set null,
  accepted_at timestamptz,
  check (phone is not null or code is not null)
);

-- Владелец проекта автоматически становится участником.
create or replace function public.projects_add_owner()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.project_members (project_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict do nothing;
  return new;
end $$;

create trigger projects_add_owner after insert on public.projects
  for each row execute function public.projects_add_owner();

-- Проверки доступа. security definer, чтобы не зацикливать RLS.
create or replace function public.is_project_member(pid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.project_members
    where project_id = pid and user_id = auth.uid()
  )
$$;

create or replace function public.can_edit_project(pid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.project_members
    where project_id = pid and user_id = auth.uid() and role in ('owner', 'editor')
  )
$$;

create or replace function public.is_project_owner(pid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.project_members
    where project_id = pid and user_id = auth.uid() and role = 'owner'
  )
$$;

create or replace function public.shares_project_with(other uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.project_members a
    join public.project_members b on a.project_id = b.project_id
    where a.user_id = auth.uid() and b.user_id = other
  )
$$;

-- Новый пользователь: профиль и принятие приглашений по его телефону.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_phone text := public.normalize_phone(new.phone);
begin
  insert into public.profiles (id, display_name, phone, yandex_id)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', new.raw_user_meta_data ->> 'name', ''),
    v_phone,
    new.raw_app_meta_data ->> 'yandex_id'
  )
  on conflict (id) do nothing;

  if v_phone is not null then
    perform public.accept_phone_invites(new.id, v_phone);
  end if;
  return new;
end $$;

create or replace function public.accept_phone_invites(uid uuid, v_phone text)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.project_members (project_id, user_id, role)
  select i.project_id, uid, i.role
  from public.project_invites i
  where i.phone = v_phone and i.accepted_at is null and i.expires_at > now()
  on conflict do nothing;

  update public.project_invites
  set accepted_by = uid, accepted_at = now()
  where phone = v_phone and accepted_at is null and expires_at > now();
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Телефон, подтверждённый позже (например, у пользователя Яндекса).
create or replace function public.handle_user_phone_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_phone text := public.normalize_phone(new.phone);
begin
  if v_phone is distinct from public.normalize_phone(old.phone) then
    update public.profiles set phone = v_phone where id = new.id;
    if v_phone is not null then
      perform public.accept_phone_invites(new.id, v_phone);
    end if;
  end if;
  return new;
end $$;

create trigger on_auth_user_phone_changed after update of phone on auth.users
  for each row execute function public.handle_user_phone_change();

-- Пригласить по телефону: сразу добавляет зарегистрированного пользователя,
-- иначе оставляет приглашение до его регистрации.
create or replace function public.invite_to_project(pid uuid, p_phone text, p_role public.project_role default 'editor')
returns text language plpgsql security definer set search_path = public as $$
declare
  v_phone text := public.normalize_phone(p_phone);
  v_user uuid;
begin
  if not public.is_project_owner(pid) then
    raise exception 'Только владелец проекта может приглашать участников' using errcode = '42501';
  end if;
  if v_phone is null or char_length(v_phone) < 10 then
    raise exception 'Некорректный номер телефона' using errcode = '22023';
  end if;
  if p_role = 'owner' then
    p_role := 'editor';
  end if;

  select id into v_user from public.profiles where phone = v_phone;
  if v_user is not null then
    insert into public.project_members (project_id, user_id, role)
    values (pid, v_user, p_role)
    on conflict (project_id, user_id) do nothing;
    return 'added';
  end if;

  insert into public.project_invites (project_id, phone, role) values (pid, v_phone, p_role);
  return 'pending';
end $$;

-- Код приглашения, которым можно поделиться в мессенджере.
create or replace function public.create_invite_code(pid uuid, p_role public.project_role default 'editor')
returns text language plpgsql security definer set search_path = public as $$
declare
  v_code text;
begin
  if not public.is_project_owner(pid) then
    raise exception 'Только владелец проекта может приглашать участников' using errcode = '42501';
  end if;
  if p_role = 'owner' then
    p_role := 'editor';
  end if;
  v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
  insert into public.project_invites (project_id, code, role) values (pid, v_code, p_role);
  return v_code;
end $$;

create or replace function public.join_project_by_code(p_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_inv public.project_invites;
begin
  select * into v_inv from public.project_invites
  where code = upper(trim(p_code)) and expires_at > now()
  for update;
  if v_inv.id is null then
    raise exception 'Код приглашения не найден или устарел' using errcode = 'P0002';
  end if;

  insert into public.project_members (project_id, user_id, role)
  values (v_inv.project_id, auth.uid(), v_inv.role)
  on conflict (project_id, user_id) do nothing;

  update public.project_invites
  set accepted_by = auth.uid(), accepted_at = now()
  where id = v_inv.id and accepted_at is null;

  return v_inv.project_id;
end $$;

-- ---------------------------------------------------------------------------
-- Задачи
-- ---------------------------------------------------------------------------

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  project_id uuid references public.projects (id) on delete cascade,
  parent_id uuid references public.tasks (id) on delete cascade,
  assignee_id uuid references auth.users (id) on delete set null,
  title text not null check (char_length(title) between 1 and 500),
  notes text not null default '',
  is_done boolean not null default false,
  done_at timestamptz,
  due_at timestamptz,
  due_all_day boolean not null default false,
  remind_at timestamptz,
  urgency smallint not null default 2 check (urgency between 1 and 3),
  importance smallint not null default 2 check (importance between 1 and 3),
  position double precision not null default extract(epoch from now()),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index tasks_owner_idx on public.tasks (owner_id);
create index tasks_project_idx on public.tasks (project_id);
create index tasks_parent_idx on public.tasks (parent_id);

create or replace function public.tasks_before_write()
returns trigger language plpgsql as $$
declare
  v_parent_project uuid;
begin
  -- Подзадача всегда живёт в проекте родителя.
  if new.parent_id is not null then
    select project_id into v_parent_project from public.tasks where id = new.parent_id;
    new.project_id := v_parent_project;
  end if;
  if new.is_done and new.done_at is null then
    new.done_at := now();
  elsif not new.is_done then
    new.done_at := null;
  end if;
  new.updated_at := now();
  return new;
end $$;

create trigger tasks_before_write before insert or update on public.tasks
  for each row execute function public.tasks_before_write();

-- Перенос задачи в другой проект переносит и её подзадачи.
create or replace function public.tasks_cascade_project()
returns trigger language plpgsql as $$
begin
  if new.project_id is distinct from old.project_id then
    update public.tasks set project_id = new.project_id where parent_id = new.id;
  end if;
  return null;
end $$;

create trigger tasks_cascade_project after update of project_id on public.tasks
  for each row execute function public.tasks_cascade_project();

-- ---------------------------------------------------------------------------
-- Заметки и вложения
-- ---------------------------------------------------------------------------

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  project_id uuid references public.projects (id) on delete cascade,
  title text not null default '' check (char_length(title) <= 300),
  body text not null default '',
  is_pinned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index notes_owner_idx on public.notes (owner_id);
create index notes_project_idx on public.notes (project_id);

create trigger notes_touch before update on public.notes
  for each row execute function public.touch_updated_at();

create table public.note_attachments (
  id uuid primary key default gen_random_uuid(),
  note_id uuid not null references public.notes (id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  storage_path text not null unique,
  file_name text not null,
  mime_type text,
  size_bytes bigint not null check (size_bytes between 0 and 10485760),
  created_at timestamptz not null default now()
);

create index note_attachments_note_idx on public.note_attachments (note_id);

-- Не больше 5 файлов на заметку.
create or replace function public.note_attachments_limit()
returns trigger language plpgsql as $$
begin
  perform 1 from public.notes where id = new.note_id for update;
  if (select count(*) from public.note_attachments where note_id = new.note_id) >= 5 then
    raise exception 'К заметке можно прикрепить не больше 5 файлов' using errcode = '23514';
  end if;
  return new;
end $$;

create trigger note_attachments_limit before insert on public.note_attachments
  for each row execute function public.note_attachments_limit();

create or replace function public.can_read_note(nid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.notes n
    where n.id = nid
      and (n.owner_id = auth.uid() or (n.project_id is not null and public.is_project_member(n.project_id)))
  )
$$;

create or replace function public.can_edit_note(nid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.notes n
    where n.id = nid
      and (n.owner_id = auth.uid() or (n.project_id is not null and public.can_edit_project(n.project_id)))
  )
$$;

-- ---------------------------------------------------------------------------
-- Календари и события
-- ---------------------------------------------------------------------------

create table public.calendar_accounts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  provider text not null default 'yandex',
  server_url text not null default 'https://caldav.yandex.ru',
  username text not null,
  timezone text not null default 'Europe/Moscow',
  sync_interval_minutes integer not null default 30 check (sync_interval_minutes between 5 and 1440),
  two_way boolean not null default true,
  last_synced_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger calendar_accounts_touch before update on public.calendar_accounts
  for each row execute function public.touch_updated_at();

-- Пароли приложений хранятся отдельно и зашифрованными; клиент их не видит
-- (RLS включён, политик нет, читает только серверная функция).
create table public.calendar_account_secrets (
  account_id uuid primary key references public.calendar_accounts (id) on delete cascade,
  password_enc text not null
);

create table public.calendars (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  account_id uuid references public.calendar_accounts (id) on delete cascade,
  name text not null,
  color bigint not null default 4280391411,
  remote_url text,
  remote_ctag text,
  is_visible boolean not null default true,
  is_readonly boolean not null default false,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  unique (account_id, remote_url)
);

create index calendars_owner_idx on public.calendars (owner_id);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  calendar_id uuid not null references public.calendars (id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text not null default '',
  description text not null default '',
  location text not null default '',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  all_day boolean not null default false,  -- для all_day даты хранятся как полночь UTC
  rrule text,
  exdates timestamptz[] not null default '{}',
  recurrence_id timestamptz,                -- изменённый экземпляр повторяющегося события
  reminder_minutes integer check (reminder_minutes between 0 and 40320),
  uid text not null default gen_random_uuid()::text,
  remote_href text,
  remote_etag text,
  sync_state text not null default 'local' check (sync_state in ('local', 'synced', 'dirty')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at >= starts_at)
);

create index events_calendar_idx on public.events (calendar_id);
create index events_owner_idx on public.events (owner_id);
create index events_range_idx on public.events (starts_at, ends_at);
create index events_href_idx on public.events (calendar_id, remote_href);
create unique index events_uid_idx on public.events (calendar_id, uid, coalesce(recurrence_id, 'epoch'::timestamptz));

create or replace function public.calendar_writable(cid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.calendars c
    where c.id = cid and c.owner_id = auth.uid() and not c.is_readonly
  )
$$;

-- Правки из приложения в календаре CalDAV помечаются для выгрузки.
create or replace function public.events_before_write()
returns trigger language plpgsql as $$
declare
  v_remote boolean;
begin
  new.updated_at := now();
  if coalesce(auth.role(), '') = 'authenticated' then
    select c.account_id is not null into v_remote from public.calendars c where c.id = new.calendar_id;
    new.sync_state := case when v_remote then 'dirty' else 'local' end;
  end if;
  return new;
end $$;

create trigger events_before_write before insert or update on public.events
  for each row execute function public.events_before_write();

-- Каждому пользователю — личный календарь по умолчанию.
create or replace function public.profiles_default_calendar()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.calendars (owner_id, name, is_default) values (new.id, 'Мой календарь', true);
  return new;
end $$;

create trigger profiles_default_calendar after insert on public.profiles
  for each row execute function public.profiles_default_calendar();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.project_members enable row level security;
alter table public.project_invites enable row level security;
alter table public.tasks enable row level security;
alter table public.notes enable row level security;
alter table public.note_attachments enable row level security;
alter table public.calendar_accounts enable row level security;
alter table public.calendar_account_secrets enable row level security;
alter table public.calendars enable row level security;
alter table public.events enable row level security;

create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.shares_project_with(id));
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
-- Телефон и Яндекс ID меняет только сервер.
revoke update on public.profiles from authenticated;
grant update (display_name, avatar_url) on public.profiles to authenticated;

create policy projects_select on public.projects for select to authenticated
  using (owner_id = auth.uid() or public.is_project_member(id));
create policy projects_insert on public.projects for insert to authenticated
  with check (owner_id = auth.uid());
create policy projects_update on public.projects for update to authenticated
  using (public.can_edit_project(id)) with check (public.can_edit_project(id));
create policy projects_delete on public.projects for delete to authenticated
  using (owner_id = auth.uid());

create policy members_select on public.project_members for select to authenticated
  using (public.is_project_member(project_id));
create policy members_update on public.project_members for update to authenticated
  using (public.is_project_owner(project_id) and role <> 'owner')
  with check (public.is_project_owner(project_id) and role <> 'owner');
-- Владелец исключает участников, участник может выйти сам.
create policy members_delete on public.project_members for delete to authenticated
  using (role <> 'owner' and (user_id = auth.uid() or public.is_project_owner(project_id)));

create policy invites_select on public.project_invites for select to authenticated
  using (public.is_project_owner(project_id));
create policy invites_delete on public.project_invites for delete to authenticated
  using (public.is_project_owner(project_id));

create policy tasks_select on public.tasks for select to authenticated
  using (owner_id = auth.uid() or (project_id is not null and public.is_project_member(project_id)));
create policy tasks_insert on public.tasks for insert to authenticated
  with check (owner_id = auth.uid() and (project_id is null or public.can_edit_project(project_id)));
create policy tasks_update on public.tasks for update to authenticated
  using (owner_id = auth.uid() or (project_id is not null and public.can_edit_project(project_id)))
  with check (project_id is null and owner_id = auth.uid() or project_id is not null and public.can_edit_project(project_id));
create policy tasks_delete on public.tasks for delete to authenticated
  using (owner_id = auth.uid() or (project_id is not null and public.can_edit_project(project_id)));

create policy notes_select on public.notes for select to authenticated
  using (owner_id = auth.uid() or (project_id is not null and public.is_project_member(project_id)));
create policy notes_insert on public.notes for insert to authenticated
  with check (owner_id = auth.uid() and (project_id is null or public.can_edit_project(project_id)));
create policy notes_update on public.notes for update to authenticated
  using (owner_id = auth.uid() or (project_id is not null and public.can_edit_project(project_id)))
  with check (project_id is null and owner_id = auth.uid() or project_id is not null and public.can_edit_project(project_id));
create policy notes_delete on public.notes for delete to authenticated
  using (owner_id = auth.uid() or (project_id is not null and public.can_edit_project(project_id)));

create policy attachments_select on public.note_attachments for select to authenticated
  using (public.can_read_note(note_id));
create policy attachments_insert on public.note_attachments for insert to authenticated
  with check (owner_id = auth.uid() and public.can_edit_note(note_id)
              and storage_path like note_id::text || '/%');
create policy attachments_delete on public.note_attachments for delete to authenticated
  using (public.can_edit_note(note_id));

create policy accounts_select on public.calendar_accounts for select to authenticated
  using (owner_id = auth.uid());
create policy accounts_update on public.calendar_accounts for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy accounts_delete on public.calendar_accounts for delete to authenticated
  using (owner_id = auth.uid());
-- Создаёт учётную запись только функция caldav-connect (она проверяет пароль).
revoke update on public.calendar_accounts from authenticated;
grant update (sync_interval_minutes, two_way, timezone) on public.calendar_accounts to authenticated;

create policy calendars_select on public.calendars for select to authenticated
  using (owner_id = auth.uid());
create policy calendars_insert on public.calendars for insert to authenticated
  with check (owner_id = auth.uid() and account_id is null);
create policy calendars_update on public.calendars for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy calendars_delete on public.calendars for delete to authenticated
  using (owner_id = auth.uid() and account_id is null and not is_default);
revoke update on public.calendars from authenticated;
grant update (name, color, is_visible) on public.calendars to authenticated;

create policy events_select on public.events for select to authenticated
  using (owner_id = auth.uid());
create policy events_insert on public.events for insert to authenticated
  with check (owner_id = auth.uid() and public.calendar_writable(calendar_id));
create policy events_update on public.events for update to authenticated
  using (owner_id = auth.uid() and public.calendar_writable(calendar_id))
  with check (owner_id = auth.uid() and public.calendar_writable(calendar_id));
create policy events_delete on public.events for delete to authenticated
  using (owner_id = auth.uid() and public.calendar_writable(calendar_id));

grant execute on function public.invite_to_project(uuid, text, public.project_role) to authenticated;
grant execute on function public.create_invite_code(uuid, public.project_role) to authenticated;
grant execute on function public.join_project_by_code(text) to authenticated;
revoke execute on function public.accept_phone_invites(uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Realtime: все устройства видят изменения сразу
-- ---------------------------------------------------------------------------

alter publication supabase_realtime add table
  public.projects, public.project_members, public.tasks, public.notes,
  public.note_attachments, public.calendars, public.calendar_accounts, public.events;

-- ---------------------------------------------------------------------------
-- Хранилище вложений: <note_id>/<uuid>-<имя файла>, не больше 10 МБ
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit)
values ('note-attachments', 'note-attachments', false, 10485760)
on conflict (id) do update set file_size_limit = excluded.file_size_limit, public = false;

create or replace function public.storage_note_id(object_name text)
returns uuid language plpgsql immutable as $$
begin
  return split_part(object_name, '/', 1)::uuid;
exception when others then
  return null;
end $$;

create policy note_files_select on storage.objects for select to authenticated
  using (bucket_id = 'note-attachments' and public.can_read_note(public.storage_note_id(name)));
create policy note_files_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'note-attachments' and public.can_edit_note(public.storage_note_id(name)));
create policy note_files_delete on storage.objects for delete to authenticated
  using (bucket_id = 'note-attachments' and public.can_edit_note(public.storage_note_id(name)));
