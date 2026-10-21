-- =====================================================================
-- FASE 2 — tabel baru: rekening, kendaraan, transaksi (ledger), servis
-- Uang di tabel baru = BILANGAN BULAT RUPIAH (bigint), bukan numeric/REAL.
-- Semua tabel punya user_id (diisi otomatis auth.uid()), RLS pemilik saja, dan soft delete (deleted_at).
-- Butuh fungsi set_updated_at() yang sudah ada di supabase/schema.sql.
-- =====================================================================

create table if not exists accounts (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  kind text not null check (kind in ('cash','bank','ewallet')),
  opening_balance bigint not null default 0,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists vehicles (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,                       -- contoh: 'Aerox', 'Jupiter Z'
  plate_hint text,                          -- opsional, JANGAN simpan plat lengkap
  odo_initial numeric(12,1) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- BBM bisa ditautkan ke motor (relasi ke ledger hanya lewat transactions.fuel_filling_id, supaya tidak melingkar)
alter table fuel_fillings add column if not exists vehicle_id uuid references vehicles(id) on delete set null;

-- Satu baris per motor per hari: odometer akhir + pembagian km per aktivitas
create table if not exists vehicle_logs (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  tanggal date not null,
  odo_end numeric(12,1) not null,
  km_kanvasing numeric(10,1) not null default 0 check (km_kanvasing >= 0),
  km_ojol      numeric(10,1) not null default 0 check (km_ojol >= 0),
  km_pribadi   numeric(10,1) not null default 0 check (km_pribadi >= 0),
  jam_online_ojol numeric(5,2),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (vehicle_id, tanggal)
);

-- Ledger: pemasukan, pengeluaran, transfer
--   pool  = kas mana (utama = kanvasing, tambahan = ojol)
--   account_id = disimpan di rekening mana (sumber, untuk transfer)
--   status 'pending' = komisi belum cair (tidak masuk saldo sampai jadi 'cleared')
--   activity 'kendaraan' = biaya motor bersama, dialokasikan ke kanvasing/ojol/pribadi menurut km (dihitung di app)
create table if not exists transactions (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tanggal date not null,
  kind text not null check (kind in ('income','expense','transfer')),
  amount bigint not null check (amount > 0),
  account_id uuid not null references accounts(id),
  to_account_id uuid references accounts(id),
  pool text not null default 'utama' check (pool in ('utama','tambahan')),
  to_pool text check (to_pool in ('utama','tambahan')),
  activity text not null default 'kanvasing' check (activity in ('kanvasing','ojol','pribadi','kendaraan')),
  category text,
  vehicle_id uuid references vehicles(id),
  fuel_filling_id uuid references fuel_fillings(id) on delete set null,
  status text not null default 'cleared' check (status in ('cleared','pending')),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint tx_transfer_shape check (
    (kind = 'transfer' and to_account_id is not null and to_pool is not null
       and (to_account_id <> account_id or to_pool <> pool))
    or (kind <> 'transfer' and to_account_id is null and to_pool is null)
  ),
  constraint tx_transfer_cleared check (kind <> 'transfer' or status = 'cleared')
);
create index if not exists idx_tx_tanggal on transactions(tanggal) where deleted_at is null;
create index if not exists idx_tx_account on transactions(account_id);
create index if not exists idx_logs_vehicle_tanggal on vehicle_logs(vehicle_id, tanggal);

-- Item servis berkala. Interval DIISI USER (dari buku servis / Yamaha Motor On); app tidak menebak angka.
create table if not exists service_items (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  name text not null,
  interval_km int check (interval_km is null or interval_km > 0),
  interval_days int check (interval_days is null or interval_days > 0),
  last_service_date date,
  last_service_odo numeric(12,1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint si_has_interval check (interval_km is not null or interval_days is not null)
);

create table if not exists service_records (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  service_item_id uuid references service_items(id) on delete set null,
  tanggal date not null,
  odometer numeric(12,1),
  cost bigint not null default 0 check (cost >= 0),
  shop text,
  note text,
  transaction_id uuid references transactions(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Trigger updated_at
create trigger trg_accounts_updated_at before update on accounts for each row execute function set_updated_at();
create trigger trg_vehicles_updated_at before update on vehicles for each row execute function set_updated_at();
create trigger trg_vehicle_logs_updated_at before update on vehicle_logs for each row execute function set_updated_at();
create trigger trg_transactions_updated_at before update on transactions for each row execute function set_updated_at();
create trigger trg_service_items_updated_at before update on service_items for each row execute function set_updated_at();
create trigger trg_service_records_updated_at before update on service_records for each row execute function set_updated_at();

-- RLS
alter table accounts enable row level security;
alter table vehicles enable row level security;
alter table vehicle_logs enable row level security;
alter table transactions enable row level security;
alter table service_items enable row level security;
alter table service_records enable row level security;
create policy owner_only on accounts for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
create policy owner_only on vehicles for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
create policy owner_only on vehicle_logs for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
create policy owner_only on transactions for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
create policy owner_only on service_items for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
create policy owner_only on service_records for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);

-- Saldo per rekening (hanya transaksi 'cleared' dan belum dihapus)
create or replace view v_account_balance with (security_invoker = true) as
with mv as (
  select account_id as acc, case kind when 'income' then amount else -amount end as delta
    from transactions where deleted_at is null and status = 'cleared'
  union all
  select to_account_id, amount
    from transactions where deleted_at is null and status = 'cleared' and kind = 'transfer'
)
select a.id as account_id, a.user_id, a.name, a.kind, a.opening_balance,
       (a.opening_balance + coalesce(sum(mv.delta), 0))::bigint as balance
from accounts a
left join mv on mv.acc = a.id
where a.deleted_at is null
group by a.id;

-- Saldo per kas (utama / tambahan). Transfer memindahkan dari pool ke to_pool.
create or replace view v_pool_balance with (security_invoker = true) as
with mv as (
  select user_id, pool, case kind when 'income' then amount else -amount end as delta
    from transactions where deleted_at is null and status = 'cleared'
  union all
  select user_id, to_pool, amount
    from transactions where deleted_at is null and status = 'cleared' and kind = 'transfer'
)
select user_id, pool, sum(delta)::bigint as balance
from mv group by user_id, pool;
