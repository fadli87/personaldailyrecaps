-- =========================================================
-- SF Daily Recap — Supabase schema
-- Run this in Supabase SQL Editor (or via `supabase db push`)
-- =========================================================

-- Denominasi uang yang dipakai untuk breakdown petty cash
create type denom_value as enum ('100000','50000','20000','10000','5000','2000','1000','500','200','100');

-- 1. Rekap harian (satu baris per hari)
create table if not exists daily_recap (
  id uuid primary key default gen_random_uuid(),
  tanggal date not null unique,
  cash_awal numeric(14,2) not null default 0,
  saldo_awal_app numeric(14,2) not null default 0,
  catatan text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. Order / transaksi dalam satu hari
create table if not exists daily_order (
  id uuid primary key default gen_random_uuid(),
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
  remark text,
  created_at timestamptz not null default now()
);

-- 3. Breakdown petty cash per hari
create table if not exists petty_cash_item (
  id uuid primary key default gen_random_uuid(),
  daily_recap_id uuid not null references daily_recap(id) on delete cascade,
  denom denom_value not null,
  qty int not null default 0,
  unique (daily_recap_id, denom)
);

-- 4. Tip & insentif per hari (angka tunggal, dari file contoh #2)
create table if not exists daily_extra (
  daily_recap_id uuid primary key references daily_recap(id) on delete cascade,
  tip numeric(14,2) not null default 0,
  insentif numeric(14,2) not null default 0
);

-- =========================================================
-- View rekap otomatis: saldo akhir, net earning, dsb
-- (menggantikan rumus Excel Cash Akhir / Net Earning / Saldo Akhir App)
-- =========================================================
create or replace view daily_recap_summary as
select
  dr.id,
  dr.tanggal,
  dr.cash_awal,
  dr.saldo_awal_app,
  coalesce(o.total_income, 0)          as total_income,
  coalesce(o.total_deduct_cash_app, 0) as total_deduct_cash_app,
  coalesce(o.total_cust_pay, 0)        as total_cust_pay,
  coalesce(o.total_cust_change, 0)     as total_cust_change,
  coalesce(o.total_saldo_top_up, 0)    as total_saldo_top_up,
  coalesce(o.total_expense, 0)         as total_expense,
  coalesce(pc.grand_total, 0)          as petty_cash_total,
  coalesce(de.tip, 0)                  as tip,
  coalesce(de.insentif, 0)             as insentif,
  -- Saldo Akhir App = Saldo Awal App + Income - Expense (mengikuti pola file contoh)
  dr.saldo_awal_app + coalesce(o.total_income, 0) - coalesce(o.total_expense, 0) as saldo_akhir_app,
  -- Cash Akhir = Cash Awal + Cust Pay - Cust Change - Saldo Top Up (uang tunai yang berpindah)
  dr.cash_awal + coalesce(o.total_cust_pay, 0) - coalesce(o.total_cust_change, 0) - coalesce(o.total_saldo_top_up, 0) as cash_akhir,
  -- Net Earning = Income - Expense
  coalesce(o.total_income, 0) - coalesce(o.total_expense, 0) as net_earning
from daily_recap dr
left join (
  select
    daily_recap_id,
    sum(income) as total_income,
    sum(deduct_cash_app) as total_deduct_cash_app,
    sum(cust_pay) as total_cust_pay,
    sum(cust_change) as total_cust_change,
    sum(saldo_top_up) as total_saldo_top_up,
    sum(expense) as total_expense
  from daily_order
  group by daily_recap_id
) o on o.daily_recap_id = dr.id
left join (
  select daily_recap_id, sum(denom::text::numeric * qty) as grand_total
  from petty_cash_item
  group by daily_recap_id
) pc on pc.daily_recap_id = dr.id
left join daily_extra de on de.daily_recap_id = dr.id;

-- =========================================================
-- Row Level Security — personal single-user app.
-- Simplest: allow all for authenticated user (adjust if you add multi-user later)
-- =========================================================
alter table daily_recap enable row level security;
alter table daily_order enable row level security;
alter table petty_cash_item enable row level security;
alter table daily_extra enable row level security;

create policy "allow all for authenticated" on daily_recap
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "allow all for authenticated" on daily_order
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "allow all for authenticated" on petty_cash_item
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "allow all for authenticated" on daily_extra
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

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
