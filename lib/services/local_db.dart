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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE daily_recap (
            id TEXT PRIMARY KEY,
            tanggal TEXT UNIQUE,
            cash_awal REAL NOT NULL DEFAULT 0,
            saldo_awal_app REAL NOT NULL DEFAULT 0,
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
            remark TEXT,
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

        await db.execute('''
          CREATE VIEW daily_recap_summary AS
          SELECT
            dr.id,
            dr.tanggal,
            dr.cash_awal,
            dr.saldo_awal_app,
            COALESCE(o.total_income, 0) AS total_income,
            COALESCE(o.total_deduct_cash_app, 0) AS total_deduct_cash_app,
            COALESCE(o.total_cust_pay, 0) AS total_cust_pay,
            COALESCE(o.total_cust_change, 0) AS total_cust_change,
            COALESCE(o.total_saldo_top_up, 0) AS total_saldo_top_up,
            COALESCE(o.total_expense, 0) AS total_expense,
            COALESCE(pc.grand_total, 0) AS petty_cash_total,
            COALESCE(de.tip, 0) AS tip,
            COALESCE(de.insentif, 0) AS insentif,
            dr.saldo_awal_app + COALESCE(o.total_income, 0) - COALESCE(o.total_expense, 0) AS saldo_akhir_app,
            dr.cash_awal + COALESCE(o.total_cust_pay, 0) - COALESCE(o.total_cust_change, 0) - COALESCE(o.total_saldo_top_up, 0) AS cash_akhir,
            COALESCE(o.total_income, 0) - COALESCE(o.total_expense, 0) AS net_earning
          FROM daily_recap dr
          LEFT JOIN (
            SELECT
              daily_recap_id,
              SUM(income) AS total_income,
              SUM(deduct_cash_app) AS total_deduct_cash_app,
              SUM(cust_pay) AS total_cust_pay,
              SUM(cust_change) AS total_cust_change,
              SUM(saldo_top_up) AS total_saldo_top_up,
              SUM(expense) AS total_expense
            FROM daily_order
            GROUP BY daily_recap_id
          ) o ON o.daily_recap_id = dr.id
          LEFT JOIN (
            SELECT daily_recap_id, SUM(CAST(denom AS REAL) * qty) AS grand_total
            FROM petty_cash_item
            GROUP BY daily_recap_id
          ) pc ON pc.daily_recap_id = dr.id
          LEFT JOIN daily_extra de ON de.daily_recap_id = dr.id
        ''');
      },
    );
  }
}
