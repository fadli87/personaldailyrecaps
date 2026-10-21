// GENERATED dari panduan Agy — skema SQLite v11 untuk modul Keuangan & Kendaraan.
// Dipakai oleh LocalDb (onCreate dan onUpgrade oldVersion < 11) dan oleh test/ledger_db_test.dart.
// sqflite hanya menjalankan SATU statement per execute(), karena itu berupa daftar.

const List<String> ledgerSchemaStatements = <String>[
  r'''
CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('cash','bank','ewallet')),
  opening_balance INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  is_synced INTEGER NOT NULL DEFAULT 0
)
''',
  r'''
CREATE TABLE IF NOT EXISTS vehicles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  plate_hint TEXT,
  odo_initial REAL NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  is_synced INTEGER NOT NULL DEFAULT 0
)
''',
  r'''
CREATE TABLE IF NOT EXISTS vehicle_logs (
  id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  tanggal TEXT NOT NULL,
  odo_end REAL NOT NULL,
  km_kanvasing REAL NOT NULL DEFAULT 0 CHECK (km_kanvasing >= 0),
  km_ojol REAL NOT NULL DEFAULT 0 CHECK (km_ojol >= 0),
  km_pribadi REAL NOT NULL DEFAULT 0 CHECK (km_pribadi >= 0),
  jam_online_ojol REAL,
  note TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  is_synced INTEGER NOT NULL DEFAULT 0,
  UNIQUE (vehicle_id, tanggal)
)
''',
  r'''
CREATE TABLE IF NOT EXISTS transactions (
  id TEXT PRIMARY KEY,
  tanggal TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('income','expense','transfer')),
  amount INTEGER NOT NULL CHECK (amount > 0),
  account_id TEXT NOT NULL,
  to_account_id TEXT,
  pool TEXT NOT NULL DEFAULT 'utama' CHECK (pool IN ('utama','tambahan')),
  to_pool TEXT CHECK (to_pool IN ('utama','tambahan')),
  activity TEXT NOT NULL DEFAULT 'kanvasing' CHECK (activity IN ('kanvasing','ojol','pribadi','kendaraan')),
  category TEXT,
  vehicle_id TEXT,
  fuel_filling_id TEXT,
  status TEXT NOT NULL DEFAULT 'cleared' CHECK (status IN ('cleared','pending')),
  note TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  is_synced INTEGER NOT NULL DEFAULT 0,
  CHECK (
    (kind = 'transfer' AND to_account_id IS NOT NULL AND to_pool IS NOT NULL
       AND (to_account_id <> account_id OR to_pool <> pool))
    OR (kind <> 'transfer' AND to_account_id IS NULL AND to_pool IS NULL)
  ),
  CHECK (kind <> 'transfer' OR status = 'cleared')
)
''',
  r'''
CREATE INDEX IF NOT EXISTS idx_tx_tanggal ON transactions(tanggal)
''',
  r'''
CREATE INDEX IF NOT EXISTS idx_tx_account ON transactions(account_id)
''',
  r'''
CREATE TABLE IF NOT EXISTS service_items (
  id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  name TEXT NOT NULL,
  interval_km INTEGER CHECK (interval_km IS NULL OR interval_km > 0),
  interval_days INTEGER CHECK (interval_days IS NULL OR interval_days > 0),
  last_service_date TEXT,
  last_service_odo REAL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  is_synced INTEGER NOT NULL DEFAULT 0,
  CHECK (interval_km IS NOT NULL OR interval_days IS NOT NULL)
)
''',
  r'''
CREATE TABLE IF NOT EXISTS service_records (
  id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  service_item_id TEXT,
  tanggal TEXT NOT NULL,
  odometer REAL,
  cost INTEGER NOT NULL DEFAULT 0 CHECK (cost >= 0),
  shop TEXT,
  note TEXT,
  transaction_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  is_synced INTEGER NOT NULL DEFAULT 0
)
''',
  r'''
DROP VIEW IF EXISTS v_account_balance
''',
  r'''
CREATE VIEW v_account_balance AS
WITH mv AS (
  SELECT account_id AS acc, CASE kind WHEN 'income' THEN amount ELSE -amount END AS delta
    FROM transactions WHERE deleted_at IS NULL AND status = 'cleared'
  UNION ALL
  SELECT to_account_id, amount
    FROM transactions WHERE deleted_at IS NULL AND status = 'cleared' AND kind = 'transfer'
)
SELECT a.id AS account_id, a.name, a.kind, a.opening_balance,
       a.opening_balance + COALESCE(SUM(mv.delta), 0) AS balance
FROM accounts a
LEFT JOIN mv ON mv.acc = a.id
WHERE a.deleted_at IS NULL
GROUP BY a.id
''',
  r'''
DROP VIEW IF EXISTS v_pool_balance
''',
  r'''
CREATE VIEW v_pool_balance AS
WITH mv AS (
  SELECT pool, CASE kind WHEN 'income' THEN amount ELSE -amount END AS delta
    FROM transactions WHERE deleted_at IS NULL AND status = 'cleared'
  UNION ALL
  SELECT to_pool, amount
    FROM transactions WHERE deleted_at IS NULL AND status = 'cleared' AND kind = 'transfer'
)
SELECT pool, SUM(delta) AS balance FROM mv GROUP BY pool
''',
];
