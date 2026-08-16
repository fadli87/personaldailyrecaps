import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/daily_recap.dart';
import '../models/daily_order.dart';
import '../models/petty_cash_item.dart';
import 'local_db.dart';
import 'sync_service.dart';

class RecapService {
  // ---------- Daily Recap ----------

  Future<List<DailyRecap>> getRecaps({int limit = 60}) async {
    final db = await LocalDb.instance.database;
    final data = await db.query(
      'daily_recap_summary',
      orderBy: 'tanggal DESC',
      limit: limit,
    );
    return data.map((e) => DailyRecap.fromSummaryMap(e)).toList();
  }

  Future<DailyRecap?> getRecapByDate(DateTime date) async {
    final dateStr = date.toIso8601String().split('T').first;
    final db = await LocalDb.instance.database;
    final data = await db.query(
      'daily_recap_summary',
      where: 'tanggal = ?',
      whereArgs: [dateStr],
      limit: 1,
    );
    if (data.isEmpty) return null;
    return DailyRecap.fromSummaryMap(data.first);
  }

  /// Membuat rekap harian baru, mengembalikan id yang dibuat.
  Future<String> createRecap({
    required DateTime tanggal,
    required double cashAwal,
    required double saldoAwalApp,
    double saldoAwalGrabKredit = 0,
    double saldoAwalGrabTunai = 0,
    double saldoAwalGrabOvo = 0,
    double odoStart = 0,
    double odoEnd = 0,
    double fuelPricePerLiter = 10000,
    double kmlParameter = 45.5,
    String status = 'open',
    double saldoAkhirAppAktual = 0,
    double saldoAkhirGrabKreditAktual = 0,
    double saldoAkhirGrabTunaiAktual = 0,
    double saldoAkhirGrabOvoAktual = 0,
    String? catatan,
  }) async {
    final id = const Uuid().v4();
    final db = await LocalDb.instance.database;
    final dateStr = tanggal.toIso8601String().split('T').first;
    final nowStr = DateTime.now().toIso8601String();

    await db.insert('daily_recap', {
      'id': id,
      'tanggal': dateStr,
      'cash_awal': cashAwal,
      'saldo_awal_app': saldoAwalApp,
      'saldo_awal_grab_kredit': saldoAwalGrabKredit,
      'saldo_awal_grab_tunai': saldoAwalGrabTunai,
      'saldo_awal_grab_ovo': saldoAwalGrabOvo,
      'odo_start': odoStart,
      'odo_end': odoEnd,
      'fuel_price_per_liter': fuelPricePerLiter,
      'kml_parameter': kmlParameter,
      'status': status,
      'saldo_akhir_app_aktual': saldoAkhirAppAktual,
      'saldo_akhir_grab_kredit_aktual': saldoAkhirGrabKreditAktual,
      'saldo_akhir_grab_tunai_aktual': saldoAkhirGrabTunaiAktual,
      'saldo_akhir_grab_ovo_aktual': saldoAkhirGrabOvoAktual,
      'catatan': catatan,
      'created_at': nowStr,
      'updated_at': nowStr,
      'is_synced': 0,
    });

    _triggerSync();
    return id;
  }

  Future<void> updateRecapHeader({
    required String id,
    required double cashAwal,
    required double saldoAwalApp,
    double saldoAwalGrabKredit = 0,
    double saldoAwalGrabTunai = 0,
    double saldoAwalGrabOvo = 0,
    double odoStart = 0,
    double odoEnd = 0,
    double fuelPricePerLiter = 10000,
    double kmlParameter = 45.5,
    String status = 'open',
    double saldoAkhirAppAktual = 0,
    double saldoAkhirGrabKreditAktual = 0,
    double saldoAkhirGrabTunaiAktual = 0,
    double saldoAkhirGrabOvoAktual = 0,
    String? catatan,
  }) async {
    final db = await LocalDb.instance.database;
    final nowStr = DateTime.now().toIso8601String();

    await db.update(
      'daily_recap',
      {
        'cash_awal': cashAwal,
        'saldo_awal_app': saldoAwalApp,
        'saldo_awal_grab_kredit': saldoAwalGrabKredit,
        'saldo_awal_grab_tunai': saldoAwalGrabTunai,
        'saldo_awal_grab_ovo': saldoAwalGrabOvo,
        'odo_start': odoStart,
        'odo_end': odoEnd,
        'fuel_price_per_liter': fuelPricePerLiter,
        'kml_parameter': kmlParameter,
        'status': status,
        'saldo_akhir_app_aktual': saldoAkhirAppAktual,
        'saldo_akhir_grab_kredit_aktual': saldoAkhirGrabKreditAktual,
        'saldo_akhir_grab_tunai_aktual': saldoAkhirGrabTunaiAktual,
        'saldo_akhir_grab_ovo_aktual': saldoAkhirGrabOvoAktual,
        'catatan': catatan,
        'updated_at': nowStr,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    _triggerSync();
  }

  Future<void> deleteRecap(String id) async {
    final db = await LocalDb.instance.database;

    // Tambah ke antrean penghapusan
    await db.insert('pending_deletions', {
      'table_name': 'daily_recap',
      'record_id': id,
    });

    await db.delete('daily_recap', where: 'id = ?', whereArgs: [id]);

    _triggerSync();
  }

  // ---------- Orders ----------

  Future<List<DailyOrder>> getOrders(String dailyRecapId) async {
    final db = await LocalDb.instance.database;
    final data = await db.query(
      'daily_order',
      where: 'daily_recap_id = ?',
      whereArgs: [dailyRecapId],
      orderBy: 'urutan',
    );
    return data.map((e) => DailyOrder.fromMap(e)).toList();
  }

  Future<void> upsertOrder(DailyOrder order) async {
    final db = await LocalDb.instance.database;
    final nowStr = DateTime.now().toIso8601String();

    if (order.id == null) {
      final newId = const Uuid().v4();
      final data = order.toInsertMap()
        ..['id'] = newId
        ..['created_at'] = nowStr
        ..['is_synced'] = 0;
      await db.insert('daily_order', data);
    } else {
      final data = order.toInsertMap()
        ..['id'] = order.id
        ..['is_synced'] = 0;
      await db.update(
        'daily_order',
        data,
        where: 'id = ?',
        whereArgs: [order.id!],
      );
    }

    _triggerSync();
  }

  Future<void> deleteOrder(String id) async {
    final db = await LocalDb.instance.database;

    await db.insert('pending_deletions', {
      'table_name': 'daily_order',
      'record_id': id,
    });

    await db.delete('daily_order', where: 'id = ?', whereArgs: [id]);

    _triggerSync();
  }

  // ---------- Petty Cash ----------

  Future<List<PettyCashItem>> getPettyCash(String dailyRecapId) async {
    final db = await LocalDb.instance.database;
    final data = await db.query(
      'petty_cash_item',
      where: 'daily_recap_id = ?',
      whereArgs: [dailyRecapId],
    );
    final rows = data.map((e) => PettyCashItem.fromMap(e)).toList();

    return pettyCashDenoms.map((d) {
      return rows.firstWhere(
        (r) => r.denom == d,
        orElse: () => PettyCashItem(denom: d, qty: 0),
      );
    }).toList();
  }

  Future<void> savePettyCash(String dailyRecapId, List<PettyCashItem> items) async {
    final db = await LocalDb.instance.database;

    for (final item in items) {
      // Dapatkan id item petty cash jika sudah ada agar tidak ganti UUID baru terus-menerus
      final existing = await db.query(
        'petty_cash_item',
        where: 'daily_recap_id = ? AND denom = ?',
        whereArgs: [dailyRecapId, item.denom.toString()],
      );
      final id = existing.isNotEmpty ? existing.first['id'] as String : const Uuid().v4();

      final data = item.toInsertMap(dailyRecapId)
        ..['id'] = id
        ..['is_synced'] = 0;

      await db.insert(
        'petty_cash_item',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    _triggerSync();
  }

  // ---------- Tip & Insentif ----------

  Future<void> saveExtra(String dailyRecapId, {required double tip, required double insentif}) async {
    final db = await LocalDb.instance.database;

    await db.insert(
      'daily_extra',
      {
        'daily_recap_id': dailyRecapId,
        'tip': tip,
        'insentif': insentif,
        'is_synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _triggerSync();
  }

  // ---------- Dashboard Data ----------

  Future<Map<String, double>> getPlatformIncomeDistribution() async {
    final db = await LocalDb.instance.database;
    final data = await db.rawQuery('''
      SELECT platform, SUM(income) as total_income
      FROM daily_order
      WHERE platform IS NOT NULL AND platform != '' AND income > 0
      GROUP BY platform
      ORDER BY total_income DESC
    ''');
    
    final result = <String, double>{};
    for (final row in data) {
      final platform = row['platform'] as String;
      final income = (row['total_income'] as num?)?.toDouble() ?? 0.0;
      result[platform] = income;
    }
    return result;
  }

  // ---------- Helper ----------

  void _triggerSync() {
    // Jalankan sinkronisasi secara asynchronous di background
    Future.microtask(() => SyncService.sync());
  }

  // ---------- Periodic Queries for Reports & Exports ----------

  Future<List<DailyRecap>> getRecapsInPeriod(DateTime start, DateTime end) async {
    final startStr = start.toIso8601String().split('T').first;
    final endStr = end.toIso8601String().split('T').first;
    final db = await LocalDb.instance.database;
    final data = await db.query(
      'daily_recap_summary',
      where: 'tanggal BETWEEN ? AND ?',
      whereArgs: [startStr, endStr],
      orderBy: 'tanggal DESC',
    );
    return data.map((e) => DailyRecap.fromSummaryMap(e)).toList();
  }

  Future<Map<String, double>> getPlatformIncomeDistributionInPeriod(DateTime start, DateTime end) async {
    final startStr = start.toIso8601String().split('T').first;
    final endStr = end.toIso8601String().split('T').first;
    final db = await LocalDb.instance.database;
    final data = await db.rawQuery('''
      SELECT o.platform, SUM(o.income) as total_income
      FROM daily_order o
      INNER JOIN daily_recap r ON o.daily_recap_id = r.id
      WHERE r.tanggal BETWEEN ? AND ? 
        AND o.platform IS NOT NULL 
        AND o.platform != '' 
        AND o.income > 0
      GROUP BY o.platform
      ORDER BY total_income DESC
    ''', [startStr, endStr]);
    
    final result = <String, double>{};
    for (final row in data) {
      final platform = row['platform'] as String;
      final income = (row['total_income'] as num?)?.toDouble() ?? 0.0;
      result[platform] = income;
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getRawOrdersInPeriod(DateTime start, DateTime end) async {
    final startStr = start.toIso8601String().split('T').first;
    final endStr = end.toIso8601String().split('T').first;
    final db = await LocalDb.instance.database;
    return await db.rawQuery('''
      SELECT o.*, r.tanggal as recap_tanggal
      FROM daily_order o
      INNER JOIN daily_recap r ON o.daily_recap_id = r.id
      WHERE r.tanggal BETWEEN ? AND ?
      ORDER BY r.tanggal DESC, o.urutan ASC
    ''', [startStr, endStr]);
  }
}
