import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  static final LocalDb instance = LocalDb._();
  LocalDb._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(docsDir.path, 'sf_daily_recap.db');
    return await openDatabase(
      dbPath,
      version: 9,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE daily_recap (
            id TEXT PRIMARY KEY,
            tanggal TEXT UNIQUE,
            cash_awal REAL NOT NULL DEFAULT 0,
            saldo_awal_app REAL NOT NULL DEFAULT 0,
            saldo_awal_grab_kredit REAL NOT NULL DEFAULT 0,
            saldo_awal_grab_tunai REAL NOT NULL DEFAULT 0,
            saldo_awal_grab_ovo REAL NOT NULL DEFAULT 0,
            saldo_awal_mandiri REAL NOT NULL DEFAULT 0,
            saldo_awal_bca REAL NOT NULL DEFAULT 0,
            odo_start REAL NOT NULL DEFAULT 0,
            odo_end REAL NOT NULL DEFAULT 0,
            fuel_price_per_liter REAL NOT NULL DEFAULT 10000,
            kml_parameter REAL NOT NULL DEFAULT 45.5,
            status TEXT NOT NULL DEFAULT 'open',
            saldo_akhir_app_aktual REAL NOT NULL DEFAULT 0,
            saldo_akhir_grab_kredit_aktual REAL NOT NULL DEFAULT 0,
            saldo_akhir_grab_tunai_aktual REAL NOT NULL DEFAULT 0,
            saldo_akhir_grab_ovo_aktual REAL NOT NULL DEFAULT 0,
            saldo_akhir_mandiri_aktual REAL NOT NULL DEFAULT 0,
            saldo_akhir_bca_aktual REAL NOT NULL DEFAULT 0,
            catatan TEXT,
            created_at TEXT,
            updated_at TEXT,
            is_synced INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE daily_order (
            id TEXT PRIMARY KEY,
            daily_recap_id TEXT NOT NULL,
            urutan INTEGER NOT NULL,
            platform TEXT,
            keterangan TEXT,
            income REAL NOT NULL DEFAULT 0,
            deduct_cash_app REAL NOT NULL DEFAULT 0,
            cust_pay REAL NOT NULL DEFAULT 0,
            cust_change REAL NOT NULL DEFAULT 0,
            saldo_top_up REAL NOT NULL DEFAULT 0,
            expense REAL NOT NULL DEFAULT 0,
            is_fuel_expense INTEGER NOT NULL DEFAULT 0,
            wallet_type TEXT NOT NULL DEFAULT 'shopeefood',
            topup_source TEXT NOT NULL DEFAULT 'cash',
            remark TEXT,
            odometer REAL,
            created_at TEXT,
            is_synced INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE petty_cash_item (
            id TEXT PRIMARY KEY,
            daily_recap_id TEXT NOT NULL,
            denom TEXT NOT NULL,
            qty INTEGER NOT NULL DEFAULT 0,
            is_synced INTEGER NOT NULL DEFAULT 0,
            UNIQUE(daily_recap_id, denom)
          )
        ''');

        await db.execute('''
          CREATE TABLE daily_extra (
            daily_recap_id TEXT PRIMARY KEY,
            tip REAL NOT NULL DEFAULT 0,
            insentif REAL NOT NULL DEFAULT 0,
            tip_wallet_type TEXT,
            insentif_wallet_type TEXT,
            is_synced INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE pending_deletions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_name TEXT NOT NULL,
            record_id TEXT NOT NULL
          )
        ''');

        await _createSummaryView(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE daily_recap ADD COLUMN odo_start REAL NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE daily_recap ADD COLUMN odo_end REAL NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE daily_recap ADD COLUMN fuel_price_per_liter REAL NOT NULL DEFAULT 10000');
          await db.execute('ALTER TABLE daily_recap ADD COLUMN kml_parameter REAL NOT NULL DEFAULT 45.5');
          await db.execute('ALTER TABLE daily_order ADD COLUMN is_fuel_expense INTEGER NOT NULL DEFAULT 0');
        }

        if (oldVersion < 3) {
          await db.execute("ALTER TABLE daily_recap ADD COLUMN status TEXT NOT NULL DEFAULT 'open'");
          await db.execute("ALTER TABLE daily_recap ADD COLUMN saldo_akhir_app_aktual REAL NOT NULL DEFAULT 0");
        }

        if (oldVersion < 4) {
          await db.execute('ALTER TABLE daily_recap ADD COLUMN saldo_awal_grab_kredit REAL NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE daily_recap ADD COLUMN saldo_awal_grab_tunai REAL NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE daily_recap ADD COLUMN saldo_awal_grab_ovo REAL NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE daily_recap ADD COLUMN saldo_akhir_grab_kredit_aktual REAL NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE daily_recap ADD COLUMN saldo_akhir_grab_tunai_aktual REAL NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE daily_recap ADD COLUMN saldo_akhir_grab_ovo_aktual REAL NOT NULL DEFAULT 0');
          await db.execute("ALTER TABLE daily_order ADD COLUMN wallet_type TEXT NOT NULL DEFAULT 'shopeefood'");
        }

        if (oldVersion < 5) {
          await db.execute('ALTER TABLE daily_recap ADD COLUMN saldo_awal_mandiri REAL NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE daily_recap ADD COLUMN saldo_awal_bca REAL NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE daily_recap ADD COLUMN saldo_akhir_mandiri_aktual REAL NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE daily_recap ADD COLUMN saldo_akhir_bca_aktual REAL NOT NULL DEFAULT 0');
        }

        if (oldVersion < 6) {
          await db.execute("ALTER TABLE daily_order ADD COLUMN topup_source TEXT NOT NULL DEFAULT 'cash'");
        }

        if (oldVersion < 7) {
          await db.execute("ALTER TABLE daily_order ADD COLUMN odometer REAL");
        }

        if (oldVersion < 8) {
          // No table structure changes needed, view will be re-created below
        }

        if (oldVersion < 9) {
          await db.execute("ALTER TABLE daily_extra ADD COLUMN tip_wallet_type TEXT");
          await db.execute("ALTER TABLE daily_extra ADD COLUMN insentif_wallet_type TEXT");
        }

        // Selalu re-create view di onUpgrade untuk memastikan rumus terbaru terpakai
        await db.execute('DROP VIEW IF EXISTS daily_recap_summary');
        await _createSummaryView(db);
      },
    );
  }

  static Future<void> _createSummaryView(Database db) async {
    await db.execute('''
      CREATE VIEW daily_recap_summary AS
      SELECT
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
        COALESCE(o.total_income, 0) AS total_income,
        COALESCE(o.total_deduct_cash_app, 0) AS total_deduct_cash_app,
        COALESCE(o.total_cust_pay, 0) AS total_cust_pay,
        COALESCE(o.total_cust_change, 0) AS total_cust_change,
        COALESCE(o.total_saldo_top_up, 0) AS total_saldo_top_up,
        COALESCE(o.total_expense, 0) AS total_expense,
        COALESCE(pc.grand_total, 0) AS petty_cash_total,
        COALESCE(de.tip, 0) AS tip,
        COALESCE(de.insentif, 0) AS insentif,
        de.tip_wallet_type,
        de.insentif_wallet_type,
        -- Saldo akhir buku per wallet (Top Up dikurangi dari source wallet dan ditambah ke target wallet)
        dr.saldo_awal_app + COALESCE(o.inc_sf, 0) - COALESCE(o.exp_sf, 0) - COALESCE(o.ded_sf, 0) + COALESCE(o.top_sf, 0) - COALESCE(o.top_from_sf, 0) + (CASE WHEN de.tip_wallet_type = 'shopeefood' THEN de.tip ELSE 0 END) + (CASE WHEN de.insentif_wallet_type = 'shopeefood' THEN de.insentif ELSE 0 END) AS saldo_akhir_app,
        dr.saldo_awal_grab_kredit + COALESCE(o.inc_gk, 0) - COALESCE(o.exp_gk, 0) - COALESCE(o.ded_gk, 0) + COALESCE(o.top_gk, 0) - COALESCE(o.top_from_gk, 0) + (CASE WHEN de.tip_wallet_type = 'grab_kredit' THEN de.tip ELSE 0 END) + (CASE WHEN de.insentif_wallet_type = 'grab_kredit' THEN de.insentif ELSE 0 END) AS saldo_akhir_grab_kredit,
        dr.saldo_awal_grab_tunai + COALESCE(o.inc_gt, 0) - COALESCE(o.exp_gt, 0) - COALESCE(o.ded_gt, 0) + COALESCE(o.top_gt, 0) - COALESCE(o.top_from_gt, 0) + (CASE WHEN de.tip_wallet_type = 'grab_tunai' THEN de.tip ELSE 0 END) + (CASE WHEN de.insentif_wallet_type = 'grab_tunai' THEN de.insentif ELSE 0 END) AS saldo_akhir_grab_tunai,
        dr.saldo_awal_grab_ovo + COALESCE(o.inc_go, 0) - COALESCE(o.exp_go, 0) - COALESCE(o.ded_go, 0) + COALESCE(o.top_go, 0) - COALESCE(o.top_from_go, 0) + (CASE WHEN de.tip_wallet_type = 'grab_ovo' THEN de.tip ELSE 0 END) + (CASE WHEN de.insentif_wallet_type = 'grab_ovo' THEN de.insentif ELSE 0 END) AS saldo_akhir_grab_ovo,
        dr.saldo_awal_mandiri + COALESCE(o.inc_mandiri, 0) - COALESCE(o.exp_mandiri, 0) - COALESCE(o.ded_mandiri, 0) + COALESCE(o.top_mandiri, 0) - COALESCE(o.top_from_mandiri, 0) + (CASE WHEN de.tip_wallet_type = 'mandiri' THEN de.tip ELSE 0 END) + (CASE WHEN de.insentif_wallet_type = 'mandiri' THEN de.insentif ELSE 0 END) AS saldo_akhir_mandiri,
        dr.saldo_awal_bca + COALESCE(o.inc_bca, 0) - COALESCE(o.exp_bca, 0) - COALESCE(o.ded_bca, 0) + COALESCE(o.top_bca, 0) - COALESCE(o.top_from_bca, 0) + (CASE WHEN de.tip_wallet_type = 'bca' THEN de.tip ELSE 0 END) + (CASE WHEN de.insentif_wallet_type = 'bca' THEN de.insentif ELSE 0 END) AS saldo_akhir_bca,
        -- Kas akhir buku (Tunai) - hanya dikurangi top-up yang bersumber dari Cash (Alfamart/Indomaret/Tunai)
        dr.cash_awal + COALESCE(o.total_cust_pay, 0) - COALESCE(o.total_cust_change, 0) - COALESCE(o.top_from_cash, 0) + COALESCE(o.inc_cash, 0) - COALESCE(o.exp_cash, 0) + (CASE WHEN de.tip_wallet_type = 'cash' THEN de.tip ELSE 0 END) + (CASE WHEN de.insentif_wallet_type = 'cash' THEN de.insentif ELSE 0 END) AS cash_akhir,
        -- Net earning global
        COALESCE(o.total_income, 0) - COALESCE(o.total_expense, 0) + COALESCE(de.tip, 0) + COALESCE(de.insentif, 0) AS net_earning,
        -- Telemetry
        (dr.odo_end - dr.odo_start) AS jarak_tempuh,
        COALESCE(f.total_fuel_expense, 0) AS total_fuel_expense,
        CASE WHEN dr.fuel_price_per_liter > 0
             THEN COALESCE(f.total_fuel_expense, 0) / dr.fuel_price_per_liter
             ELSE 0 END AS liter_masuk,
        CASE WHEN dr.kml_parameter > 0
             THEN (dr.odo_end - dr.odo_start) / dr.kml_parameter
             ELSE 0 END AS liter_terpakai,
        -- Discrepancies
        COALESCE(pc.grand_total, 0) - (dr.cash_awal + COALESCE(o.total_cust_pay, 0) - COALESCE(o.total_cust_change, 0) - COALESCE(o.top_from_cash, 0) + COALESCE(o.inc_cash, 0) - COALESCE(o.exp_cash, 0) + (CASE WHEN de.tip_wallet_type = 'cash' THEN de.tip ELSE 0 END) + (CASE WHEN de.insentif_wallet_type = 'cash' THEN de.insentif ELSE 0 END)) AS cash_discrepancy,
        dr.saldo_akhir_app_aktual - (dr.saldo_awal_app + COALESCE(o.inc_sf, 0) - COALESCE(o.exp_sf, 0) - COALESCE(o.ded_sf, 0) + COALESCE(o.top_sf, 0) - COALESCE(o.top_from_sf, 0) + (CASE WHEN de.tip_wallet_type = 'shopeefood' THEN de.tip ELSE 0 END) + (CASE WHEN de.insentif_wallet_type = 'shopeefood' THEN de.insentif ELSE 0 END)) AS app_discrepancy,
        dr.saldo_akhir_grab_kredit_aktual - (dr.saldo_awal_grab_kredit + COALESCE(o.inc_gk, 0) - COALESCE(o.exp_gk, 0) - COALESCE(o.ded_gk, 0) + COALESCE(o.top_gk, 0) - COALESCE(o.top_from_gk, 0) + (CASE WHEN de.tip_wallet_type = 'grab_kredit' THEN de.tip ELSE 0 END) + (CASE WHEN de.insentif_wallet_type = 'grab_kredit' THEN de.insentif ELSE 0 END)) AS grab_kredit_discrepancy,
        dr.saldo_akhir_grab_tunai_aktual - (dr.saldo_awal_grab_tunai + COALESCE(o.inc_gt, 0) - COALESCE(o.exp_gt, 0) - COALESCE(o.ded_gt, 0) + COALESCE(o.top_gt, 0) - COALESCE(o.top_from_gt, 0) + (CASE WHEN de.tip_wallet_type = 'grab_tunai' THEN de.tip ELSE 0 END) + (CASE WHEN de.insentif_wallet_type = 'grab_tunai' THEN de.insentif ELSE 0 END)) AS grab_tunai_discrepancy,
        dr.saldo_akhir_grab_ovo_aktual - (dr.saldo_awal_grab_ovo + COALESCE(o.inc_go, 0) - COALESCE(o.exp_go, 0) - COALESCE(o.ded_go, 0) + COALESCE(o.top_go, 0) - COALESCE(o.top_from_go, 0) + (CASE WHEN de.tip_wallet_type = 'grab_ovo' THEN de.tip ELSE 0 END) + (CASE WHEN de.insentif_wallet_type = 'grab_ovo' THEN de.insentif ELSE 0 END)) AS grab_ovo_discrepancy,
        dr.saldo_akhir_mandiri_aktual - (dr.saldo_awal_mandiri + COALESCE(o.inc_mandiri, 0) - COALESCE(o.exp_mandiri, 0) - COALESCE(o.ded_mandiri, 0) + COALESCE(o.top_mandiri, 0) - COALESCE(o.top_from_mandiri, 0) + (CASE WHEN de.tip_wallet_type = 'mandiri' THEN de.tip ELSE 0 END) + (CASE WHEN de.insentif_wallet_type = 'mandiri' THEN de.insentif ELSE 0 END)) AS mandiri_discrepancy,
        dr.saldo_akhir_bca_aktual - (dr.saldo_awal_bca + COALESCE(o.inc_bca, 0) - COALESCE(o.exp_bca, 0) - COALESCE(o.ded_bca, 0) + COALESCE(o.top_bca, 0) - COALESCE(o.top_from_bca, 0) + (CASE WHEN de.tip_wallet_type = 'bca' THEN de.tip ELSE 0 END) + (CASE WHEN de.insentif_wallet_type = 'bca' THEN de.insentif ELSE 0 END)) AS bca_discrepancy
      FROM daily_recap dr
      LEFT JOIN (
        SELECT
          daily_recap_id,
          SUM(income) AS total_income,
          SUM(deduct_cash_app) AS total_deduct_cash_app,
          SUM(cust_pay) AS total_cust_pay,
          SUM(cust_change) AS total_cust_change,
          SUM(saldo_top_up) AS total_saldo_top_up,
          SUM(expense) AS total_expense,
          -- cash
          SUM(CASE WHEN wallet_type = 'cash' THEN income ELSE 0 END) AS inc_cash,
          SUM(CASE WHEN wallet_type = 'cash' THEN expense ELSE 0 END) AS exp_cash,
          -- shopeefood
          SUM(CASE WHEN wallet_type = 'shopeefood' THEN income ELSE 0 END) AS inc_sf,
          SUM(CASE WHEN wallet_type = 'shopeefood' THEN expense ELSE 0 END) AS exp_sf,
          SUM(CASE WHEN wallet_type = 'shopeefood' THEN deduct_cash_app ELSE 0 END) AS ded_sf,
          SUM(CASE WHEN wallet_type = 'shopeefood' THEN saldo_top_up ELSE 0 END) AS top_sf,
          -- grab_kredit
          SUM(CASE WHEN wallet_type = 'grab_kredit' THEN income ELSE 0 END) AS inc_gk,
          SUM(CASE WHEN wallet_type = 'grab_kredit' THEN expense ELSE 0 END) AS exp_gk,
          SUM(CASE WHEN wallet_type = 'grab_kredit' THEN deduct_cash_app ELSE 0 END) AS ded_gk,
          SUM(CASE WHEN wallet_type = 'grab_kredit' THEN saldo_top_up ELSE 0 END) AS top_gk,
          -- grab_tunai
          SUM(CASE WHEN wallet_type = 'grab_tunai' THEN income ELSE 0 END) AS inc_gt,
          SUM(CASE WHEN wallet_type = 'grab_tunai' THEN expense ELSE 0 END) AS exp_gt,
          SUM(CASE WHEN wallet_type = 'grab_tunai' THEN deduct_cash_app ELSE 0 END) AS ded_gt,
          SUM(CASE WHEN wallet_type = 'grab_tunai' THEN saldo_top_up ELSE 0 END) AS top_gt,
          -- grab_ovo
          SUM(CASE WHEN wallet_type = 'grab_ovo' THEN income ELSE 0 END) AS inc_go,
          SUM(CASE WHEN wallet_type = 'grab_ovo' THEN expense ELSE 0 END) AS exp_go,
          SUM(CASE WHEN wallet_type = 'grab_ovo' THEN deduct_cash_app ELSE 0 END) AS ded_go,
          SUM(CASE WHEN wallet_type = 'grab_ovo' THEN saldo_top_up ELSE 0 END) AS top_go,
          -- mandiri
          SUM(CASE WHEN wallet_type = 'mandiri' THEN income ELSE 0 END) AS inc_mandiri,
          SUM(CASE WHEN wallet_type = 'mandiri' THEN expense ELSE 0 END) AS exp_mandiri,
          SUM(CASE WHEN wallet_type = 'mandiri' THEN deduct_cash_app ELSE 0 END) AS ded_mandiri,
          SUM(CASE WHEN wallet_type = 'mandiri' THEN saldo_top_up ELSE 0 END) AS top_mandiri,
          -- bca
          SUM(CASE WHEN wallet_type = 'bca' THEN income ELSE 0 END) AS inc_bca,
          SUM(CASE WHEN wallet_type = 'bca' THEN expense ELSE 0 END) AS exp_bca,
          SUM(CASE WHEN wallet_type = 'bca' THEN deduct_cash_app ELSE 0 END) AS ded_bca,
          SUM(CASE WHEN wallet_type = 'bca' THEN saldo_top_up ELSE 0 END) AS top_bca,
          -- top up sources
          SUM(CASE WHEN topup_source = 'cash' THEN saldo_top_up ELSE 0 END) AS top_from_cash,
          SUM(CASE WHEN topup_source = 'shopeefood' THEN saldo_top_up ELSE 0 END) AS top_from_sf,
          SUM(CASE WHEN topup_source = 'grab_kredit' THEN saldo_top_up ELSE 0 END) AS top_from_gk,
          SUM(CASE WHEN topup_source = 'grab_tunai' THEN saldo_top_up ELSE 0 END) AS top_from_gt,
          SUM(CASE WHEN topup_source = 'grab_ovo' THEN saldo_top_up ELSE 0 END) AS top_from_go,
          SUM(CASE WHEN topup_source = 'mandiri' THEN saldo_top_up ELSE 0 END) AS top_from_mandiri,
          SUM(CASE WHEN topup_source = 'bca' THEN saldo_top_up ELSE 0 END) AS top_from_bca
        FROM daily_order
        GROUP BY daily_recap_id
      ) o ON o.daily_recap_id = dr.id
      LEFT JOIN (
        SELECT daily_recap_id, SUM(expense) AS total_fuel_expense
        FROM daily_order
        WHERE is_fuel_expense = 1
        GROUP BY daily_recap_id
      ) f ON f.daily_recap_id = dr.id
      LEFT JOIN (
        SELECT daily_recap_id, SUM(CAST(denom AS REAL) * qty) AS grand_total
        FROM petty_cash_item
        GROUP BY daily_recap_id
      ) pc ON pc.daily_recap_id = dr.id
      LEFT JOIN daily_extra de ON de.daily_recap_id = dr.id
    ''');
  }
}
