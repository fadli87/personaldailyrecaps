-- =====================================================================
-- FASE 1A — tambahan aman (boleh dijalankan kapan saja, data lama tidak berubah)
-- =====================================================================

-- 1. Tabel fuel_fillings di server (sebelumnya hanya ada di SQLite lokal)
create table if not exists fuel_fillings (
  id uuid primary key,
  daily_recap_id uuid not null references daily_recap(id) on delete cascade,
  tanggal date not null,
  liter numeric(10,2) not null,
  harga_per_liter numeric(14,2) not null default 0,
  total_biaya numeric(14,2) not null default 0,
  odometer numeric(14,2),
  catatan text,
  created_at timestamptz not null default now()
);
create index if not exists idx_fuel_fillings_recap on fuel_fillings(daily_recap_id);
create index if not exists idx_fuel_fillings_tanggal on fuel_fillings(tanggal);
alter table fuel_fillings enable row level security;

-- 2. Kolom pemilik data (user_id) di semua tabel lama
alter table daily_recap      add column if not exists user_id uuid references auth.users(id) on delete cascade default auth.uid();
alter table daily_order      add column if not exists user_id uuid references auth.users(id) on delete cascade default auth.uid();
alter table petty_cash_item  add column if not exists user_id uuid references auth.users(id) on delete cascade default auth.uid();
alter table daily_extra      add column if not exists user_id uuid references auth.users(id) on delete cascade default auth.uid();
alter table fuel_fillings    add column if not exists user_id uuid references auth.users(id) on delete cascade default auth.uid();
