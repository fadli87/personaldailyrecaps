-- =========================================================
-- SF Daily Recap — Supabase schema
-- Run this in Supabase SQL Editor (or via `supabase db push`)
-- =========================================================

-- Denominasi uang yang dipakai untuk breakdown petty cash
create type denom_value as enum ('100000','50000','20000','10000','5000','2000','1000','500','200','100');

-- 1. Rekap harian (satu baris per hari)
create table if not exists daily_recap (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tanggal date not null unique,
  cash_awal numeric(14,2) not null default 0,
  saldo_awal_app numeric(14,2) not null default 0, -- ShopeeFood
  saldo_awal_grab_kredit numeric(14,2) not null default 0,
  saldo_awal_grab_tunai numeric(14,2) not null default 0,
  saldo_awal_grab_ovo numeric(14,2) not null default 0,
  saldo_awal_mandiri numeric(14,2) not null default 0,
  saldo_awal_bca numeric(14,2) not null default 0,
  odo_start numeric(14,2) not null default 0,
  odo_end numeric(14,2) not null default 0,
  fuel_price_per_liter numeric(14,2) not null default 10000,
  kml_parameter numeric(10,2) not null default 45.5,
  status text not null default 'open',
  saldo_akhir_app_aktual numeric(14,2) not null default 0, -- ShopeeFood
  saldo_akhir_grab_kredit_aktual numeric(14,2) not null default 0,
  saldo_akhir_grab_tunai_aktual numeric(14,2) not null default 0,
  saldo_akhir_grab_ovo_aktual numeric(14,2) not null default 0,
  saldo_akhir_mandiri_aktual numeric(14,2) not null default 0,
  saldo_akhir_bca_aktual numeric(14,2) not null default 0,
  catatan text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. Order / transaksi dalam satu hari
create table if not exists daily_order (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  daily_recap_id uuid not null references daily_recap(id) on delete cascade,
  urutan int not null default 1,           -- Order 1, Order 2, dst
  platform text,                            -- Tokopedia, TikTok Shop, Etsy, GoFood, dll (opsional)
  keterangan text,
  income numeric(14,2) not null default 0,
  deduct_cash_app numeric(14,2) not null default 0,
  cust_pay numeric(14,2) not null default 0,
  cust_change numeric(14,2) not null default 0,
  saldo_top_up numeric(14,2) not null default 0,
  expense numeric(14,2) not null default 0,
  is_fuel_expense boolean not null default false,
  wallet_type text not null default 'shopeefood',
  topup_source text not null default 'cash',
  remark text,
  odometer numeric(14,2),
  created_at timestamptz not null default now()
);

-- 3. Breakdown petty cash per hari
create table if not exists petty_cash_item (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  daily_recap_id uuid not null references daily_recap(id) on delete cascade,
  denom denom_value not null,
  qty int not null default 0,
  unique (daily_recap_id, denom)
);

-- 4. Tip & insentif per hari (angka tunggal, dari file contoh #2)
create table if not exists daily_extra (
  daily_recap_id uuid primary key references daily_recap(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tip numeric(14,2) not null default 0,
  insentif numeric(14,2) not null default 0,
  tip_wallet_type text,
  insentif_wallet_type text
);

-- 5. Pengisian BBM (Fuel Fillings)
create table if not exists fuel_fillings (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
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

-- =========================================================
-- View rekap otomatis: saldo akhir, net earning, dsb
-- =========================================================
create or replace view daily_recap_summary with (security_invoker = true) as
select
  dr.id,
  dr.tanggal,
  dr.cash_awal,
  dr.saldo_awal_app,
  dr.saldo_awal_grab_kredit,
  dr.saldo_awal_grab_tunai,
  dr.saldo_awal_grab_ovo,
  dr.saldo_awal_mandiri,
  dr.saldo_awal_bca,
  dr.odo_start,
  dr.odo_end,
  dr.fuel_price_per_liter,
  dr.kml_parameter,
  dr.status,
  dr.saldo_akhir_app_aktual,
  dr.saldo_akhir_grab_kredit_aktual,
  dr.saldo_akhir_grab_tunai_aktual,
  dr.saldo_akhir_grab_ovo_aktual,
  dr.saldo_akhir_mandiri_aktual,
  dr.saldo_akhir_bca_aktual,
  coalesce(o.total_income, 0)          as total_income,
  coalesce(o.total_deduct_cash_app, 0) as total_deduct_cash_app,
  coalesce(o.total_cust_pay, 0)        as total_cust_pay,
  coalesce(o.total_cust_change, 0)     as total_cust_change,
  coalesce(o.total_saldo_top_up, 0)    as total_saldo_top_up,
  coalesce(o.total_expense, 0)         as total_expense,
  coalesce(pc.grand_total, 0)          as petty_cash_total,
  coalesce(de.tip, 0)                  as tip,
  coalesce(de.insentif, 0)             as insentif,
  de.tip_wallet_type,
  de.insentif_wallet_type,
  -- Saldo akhir buku per wallet
  dr.saldo_awal_app + coalesce(o.inc_sf, 0) - coalesce(o.exp_sf, 0) - coalesce(o.ded_sf, 0) + coalesce(o.top_sf, 0) - coalesce(o.top_from_sf, 0) + (case when de.tip_wallet_type = 'shopeefood' then de.tip else 0 end) + (case when de.insentif_wallet_type = 'shopeefood' then de.insentif else 0 end) as saldo_akhir_app,
  dr.saldo_awal_grab_kredit + coalesce(o.inc_gk, 0) - coalesce(o.exp_gk, 0) - coalesce(o.ded_gk, 0) + coalesce(o.top_gk, 0) - coalesce(o.top_from_gk, 0) + (case when de.tip_wallet_type = 'grab_kredit' then de.tip else 0 end) + (case when de.insentif_wallet_type = 'grab_kredit' then de.insentif else 0 end) as saldo_akhir_grab_kredit,
  dr.saldo_awal_grab_tunai + coalesce(o.inc_gt, 0) - coalesce(o.exp_gt, 0) - coalesce(o.ded_gt, 0) + coalesce(o.top_gt, 0) - coalesce(o.top_from_gt, 0) + (case when de.tip_wallet_type = 'grab_tunai' then de.tip else 0 end) + (case when de.insentif_wallet_type = 'grab_tunai' then de.insentif else 0 end) as saldo_akhir_grab_tunai,
  dr.saldo_awal_grab_ovo + coalesce(o.inc_go, 0) - coalesce(o.exp_go, 0) - coalesce(o.ded_go, 0) + coalesce(o.top_go, 0) - coalesce(o.top_from_go, 0) + (case when de.tip_wallet_type = 'grab_ovo' then de.tip else 0 end) + (case when de.insentif_wallet_type = 'grab_ovo' then de.insentif else 0 end) as saldo_akhir_grab_ovo,
  dr.saldo_awal_mandiri + coalesce(o.inc_mandiri, 0) - coalesce(o.exp_mandiri, 0) - coalesce(o.ded_mandiri, 0) + coalesce(o.top_mandiri, 0) - coalesce(o.top_from_mandiri, 0) + (case when de.tip_wallet_type = 'mandiri' then de.tip else 0 end) + (case when de.insentif_wallet_type = 'mandiri' then de.insentif else 0 end) as saldo_akhir_mandiri,
  dr.saldo_awal_bca + coalesce(o.inc_bca, 0) - coalesce(o.exp_bca, 0) - coalesce(o.ded_bca, 0) + coalesce(o.top_bca, 0) - coalesce(o.top_from_bca, 0) + (case when de.tip_wallet_type = 'bca' then de.tip else 0 end) + (case when de.insentif_wallet_type = 'bca' then de.insentif else 0 end) as saldo_akhir_bca,
  -- Kas akhir buku (Tunai) - hanya dikurangi top-up yang bersumber dari Cash
  dr.cash_awal + coalesce(o.total_cust_pay, 0) - coalesce(o.total_cust_change, 0) - coalesce(o.top_from_cash, 0) + coalesce(o.inc_cash, 0) - coalesce(o.exp_cash, 0) + (case when de.tip_wallet_type = 'cash' then de.tip else 0 end) + (case when de.insentif_wallet_type = 'cash' then de.insentif else 0 end) as cash_akhir,
  -- Net earning global
  coalesce(o.total_income, 0) - coalesce(o.total_expense, 0) + coalesce(de.tip, 0) + coalesce(de.insentif, 0) as net_earning,
  -- Telemetry & BBM
  (dr.odo_end - dr.odo_start) as jarak_tempuh,
  coalesce(f.total_fuel_expense, 0) as total_fuel_expense,
  case when dr.fuel_price_per_liter > 0
       then coalesce(f.total_fuel_expense, 0) / dr.fuel_price_per_liter
       else 0 end as liter_masuk,
  case when dr.kml_parameter > 0
       then (dr.odo_end - dr.odo_start) / dr.kml_parameter
       else 0 end as liter_terpakai,
  -- Discrepancies
  (coalesce(pc.grand_total, 0) - (dr.cash_awal + coalesce(o.total_cust_pay, 0) - coalesce(o.total_cust_change, 0) - coalesce(o.top_from_cash, 0) + coalesce(o.inc_cash, 0) - coalesce(o.exp_cash, 0) + (case when de.tip_wallet_type = 'cash' then de.tip else 0 end) + (case when de.insentif_wallet_type = 'cash' then de.insentif else 0 end))) as cash_discrepancy,
  dr.saldo_akhir_app_aktual - (dr.saldo_awal_app + coalesce(o.inc_sf, 0) - coalesce(o.exp_sf, 0) - coalesce(o.ded_sf, 0) + coalesce(o.top_sf, 0) - coalesce(o.top_from_sf, 0) + (case when de.tip_wallet_type = 'shopeefood' then de.tip else 0 end) + (case when de.insentif_wallet_type = 'shopeefood' then de.insentif else 0 end)) as app_discrepancy,
  dr.saldo_akhir_grab_kredit_aktual - (dr.saldo_awal_grab_kredit + coalesce(o.inc_gk, 0) - coalesce(o.exp_gk, 0) - coalesce(o.ded_gk, 0) + coalesce(o.top_gk, 0) - coalesce(o.top_from_gk, 0) + (case when de.tip_wallet_type = 'grab_kredit' then de.tip else 0 end) + (case when de.insentif_wallet_type = 'grab_kredit' then de.insentif else 0 end)) as grab_kredit_discrepancy,
  dr.saldo_akhir_grab_tunai_aktual - (dr.saldo_awal_grab_tunai + coalesce(o.inc_gt, 0) - coalesce(o.exp_gt, 0) - coalesce(o.ded_gt, 0) + coalesce(o.top_gt, 0) - coalesce(o.top_from_gt, 0) + (case when de.tip_wallet_type = 'grab_tunai' then de.tip else 0 end) + (case when de.insentif_wallet_type = 'grab_tunai' then de.insentif else 0 end)) as grab_tunai_discrepancy,
  dr.saldo_akhir_grab_ovo_aktual - (dr.saldo_awal_grab_ovo + coalesce(o.inc_go, 0) - coalesce(o.exp_go, 0) - coalesce(o.ded_go, 0) + coalesce(o.top_go, 0) - coalesce(o.top_from_go, 0) + (case when de.tip_wallet_type = 'grab_ovo' then de.tip else 0 end) + (case when de.insentif_wallet_type = 'grab_ovo' then de.insentif else 0 end)) as grab_ovo_discrepancy,
  dr.saldo_akhir_mandiri_aktual - (dr.saldo_awal_mandiri + coalesce(o.inc_mandiri, 0) - coalesce(o.exp_mandiri, 0) - coalesce(o.ded_mandiri, 0) + coalesce(o.top_mandiri, 0) - coalesce(o.top_from_mandiri, 0) + (case when de.tip_wallet_type = 'mandiri' then de.tip else 0 end) + (case when de.insentif_wallet_type = 'mandiri' then de.insentif else 0 end)) as mandiri_discrepancy,
  dr.saldo_akhir_bca_aktual - (dr.saldo_awal_bca + coalesce(o.inc_bca, 0) - coalesce(o.exp_bca, 0) - coalesce(o.ded_bca, 0) + coalesce(o.top_bca, 0) - coalesce(o.top_from_bca, 0) + (case when de.tip_wallet_type = 'bca' then de.tip else 0 end) + (case when de.insentif_wallet_type = 'bca' then de.insentif else 0 end)) as bca_discrepancy
from daily_recap dr
left join (
  select
    daily_recap_id,
    sum(income) as total_income,
    sum(deduct_cash_app) as total_deduct_cash_app,
    sum(cust_pay) as total_cust_pay,
    sum(cust_change) as total_cust_change,
    sum(saldo_top_up) as total_saldo_top_up,
    sum(expense) as total_expense,
    -- cash
    sum(case when wallet_type = 'cash' then income else 0 end) as inc_cash,
    sum(case when wallet_type = 'cash' then expense else 0 end) as exp_cash,
    -- shopeefood
    sum(case when wallet_type = 'shopeefood' then income else 0 end) as inc_sf,
    sum(case when wallet_type = 'shopeefood' then expense else 0 end) as exp_sf,
    sum(case when wallet_type = 'shopeefood' then deduct_cash_app else 0 end) as ded_sf,
    sum(case when wallet_type = 'shopeefood' then saldo_top_up else 0 end) as top_sf,
    -- grab_kredit
    sum(case when wallet_type = 'grab_kredit' then income else 0 end) as inc_gk,
    sum(case when wallet_type = 'grab_kredit' then expense else 0 end) as exp_gk,
    sum(case when wallet_type = 'grab_kredit' then deduct_cash_app else 0 end) as ded_gk,
    sum(case when wallet_type = 'grab_kredit' then saldo_top_up else 0 end) as top_gk,
    -- grab_tunai
    sum(case when wallet_type = 'grab_tunai' then income else 0 end) as inc_gt,
    sum(case when wallet_type = 'grab_tunai' then expense else 0 end) as exp_gt,
    sum(case when wallet_type = 'grab_tunai' then deduct_cash_app else 0 end) as ded_gt,
    sum(case when wallet_type = 'grab_tunai' then saldo_top_up else 0 end) as top_gt,
    -- grab_ovo
    sum(case when wallet_type = 'grab_ovo' then income else 0 end) as inc_go,
    sum(case when wallet_type = 'grab_ovo' then expense else 0 end) as exp_go,
    sum(case when wallet_type = 'grab_ovo' then deduct_cash_app else 0 end) as ded_go,
    sum(case when wallet_type = 'grab_ovo' then saldo_top_up else 0 end) as top_go,
    -- mandiri
    sum(case when wallet_type = 'mandiri' then income else 0 end) as inc_mandiri,
    sum(case when wallet_type = 'mandiri' then expense else 0 end) as exp_mandiri,
    sum(case when wallet_type = 'mandiri' then deduct_cash_app else 0 end) as ded_mandiri,
    sum(case when wallet_type = 'mandiri' then saldo_top_up else 0 end) as top_mandiri,
    -- bca
    sum(case when wallet_type = 'bca' then income else 0 end) as inc_bca,
    sum(case when wallet_type = 'bca' then expense else 0 end) as exp_bca,
    sum(case when wallet_type = 'bca' then deduct_cash_app else 0 end) as ded_bca,
    sum(case when wallet_type = 'bca' then saldo_top_up else 0 end) as top_bca,
    -- top up sources
    sum(case when topup_source = 'cash' then saldo_top_up else 0 end) as top_from_cash,
    sum(case when topup_source = 'shopeefood' then saldo_top_up else 0 end) as top_from_sf,
    sum(case when topup_source = 'grab_kredit' then saldo_top_up else 0 end) as top_from_gk,
    sum(case when topup_source = 'grab_tunai' then saldo_top_up else 0 end) as top_from_gt,
    sum(case when topup_source = 'grab_ovo' then saldo_top_up else 0 end) as top_from_go,
    sum(case when topup_source = 'mandiri' then saldo_top_up else 0 end) as top_from_mandiri,
    sum(case when topup_source = 'bca' then saldo_top_up else 0 end) as top_from_bca
  from daily_order
  group by daily_recap_id
) o on o.daily_recap_id = dr.id
left join (
  select daily_recap_id, sum(expense) as total_fuel_expense
  from daily_order
  where is_fuel_expense = true
  group by daily_recap_id
) f on f.daily_recap_id = dr.id
left join (
  select daily_recap_id, sum(denom::text::numeric * qty) as grand_total
  from petty_cash_item
  group by daily_recap_id
) pc on pc.daily_recap_id = dr.id
left join daily_extra de on de.daily_recap_id = dr.id;

-- =========================================================
-- Row Level Security — personal single-user app (owner_only, non-anonymous).
-- =========================================================
alter table daily_recap enable row level security;
alter table daily_order enable row level security;
alter table petty_cash_item enable row level security;
alter table daily_extra enable row level security;
alter table fuel_fillings enable row level security;

create policy owner_only on daily_recap for all to authenticated
  using ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);

create policy owner_only on daily_order for all to authenticated
  using ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);

create policy owner_only on petty_cash_item for all to authenticated
  using ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);

create policy owner_only on daily_extra for all to authenticated
  using ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);

create policy owner_only on fuel_fillings for all to authenticated
  using ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);

-- PENTING: setiap create or replace view menghapus opsi security_invoker;
-- selalu akhiri dengan alter view ... set (security_invoker = true);
alter view daily_recap_summary set (security_invoker = true);

-- Trigger untuk update `updated_at` otomatis
create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_daily_recap_updated_at
  before update on daily_recap
  for each row execute function set_updated_at();
