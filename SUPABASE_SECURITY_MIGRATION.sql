-- SignalX Phase 6 - Security migration (requires Supabase Auth)
-- Do NOT run this until the Flutter app sends an authenticated Supabase session.

alter table packages add column if not exists owner_id uuid references auth.users(id);
alter table towers add column if not exists owner_id uuid references auth.users(id);
alter table subscribers add column if not exists owner_id uuid references auth.users(id);
alter table payments add column if not exists owner_id uuid references auth.users(id);

alter table packages enable row level security;
alter table towers enable row level security;
alter table subscribers enable row level security;
alter table payments enable row level security;

drop policy if exists allow_all on packages;
drop policy if exists allow_all on towers;
drop policy if exists allow_all on subscribers;
drop policy if exists allow_all on payments;

create policy packages_owner_select on packages for select using (owner_id = auth.uid());
create policy packages_owner_insert on packages for insert with check (owner_id = auth.uid());
create policy packages_owner_update on packages for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy packages_owner_delete on packages for delete using (owner_id = auth.uid());

create policy towers_owner_select on towers for select using (owner_id = auth.uid());
create policy towers_owner_insert on towers for insert with check (owner_id = auth.uid());
create policy towers_owner_update on towers for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy towers_owner_delete on towers for delete using (owner_id = auth.uid());

create policy subscribers_owner_select on subscribers for select using (owner_id = auth.uid());
create policy subscribers_owner_insert on subscribers for insert with check (owner_id = auth.uid());
create policy subscribers_owner_update on subscribers for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy subscribers_owner_delete on subscribers for delete using (owner_id = auth.uid());

create policy payments_owner_select on payments for select using (owner_id = auth.uid());
create policy payments_owner_insert on payments for insert with check (owner_id = auth.uid());
create policy payments_owner_update on payments for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy payments_owner_delete on payments for delete using (owner_id = auth.uid());

-- Backfill owner_id for existing rows manually before enabling production use.
