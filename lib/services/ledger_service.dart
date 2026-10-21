import 'package:sqflite/sqflite.dart';
import '../logic/ledger_math.dart';
import '../models/account.dart';
import '../models/fuel_filling.dart';
import '../models/ledger_transaction.dart';
import '../models/service_item.dart';
import '../models/service_record.dart';
import '../models/vehicle.dart';
import '../models/vehicle_log.dart';
import 'local_db.dart';
import 'sync_service.dart';

class AccountBalanceInfo {
  final String accountId;
  final String name;
  final String kind;
  final int openingBalance;
  final int balance;

  const AccountBalanceInfo({
    required this.accountId,
    required this.name,
    required this.kind,
    required this.openingBalance,
    required this.balance,
  });

  factory AccountBalanceInfo.fromMap(Map<String, dynamic> map) {
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;
    return AccountBalanceInfo(
      accountId: map['account_id'] as String,
      name: map['name'] as String,
      kind: map['kind'] as String,
      openingBalance: i(map['opening_balance']),
      balance: i(map['balance']),
    );
  }
}

class ServiceItemEvaluation {
  final ServiceItem item;
  final ServiceDue due;

  const ServiceItemEvaluation({
    required this.item,
    required this.due,
  });

  bool get isUrgent =>
      due.status == ServiceStatus.overdue || due.status == ServiceStatus.soon;

  ServiceStatus get status => due.status;
  double? get remainingKm => due.remainingKm;
  int? get remainingDays => due.remainingDays;
}

class LedgerService {
  // =========================================================================
  // AKUN & KAS
  // =========================================================================

  Future<List<Account>> getAccounts({bool activeOnly = false}) async {
    final db = await LocalDb.instance.database;
    final where = activeOnly
        ? 'deleted_at IS NULL AND is_active = 1'
        : 'deleted_at IS NULL';
    final rows = await db.query(
      'accounts',
      where: where,
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map((r) => Account.fromMap(r)).toList();
  }

  Future<Account?> getAccountById(String id) async {
    final db = await LocalDb.instance.database;
    final rows = await db.query(
      'accounts',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Account.fromMap(rows.first);
  }

  Future<void> saveAccount(Account account) async {
    final db = await LocalDb.instance.database;
    final existing =
        await db.query('accounts', where: 'id = ?', whereArgs: [account.id]);
    final now = DateTime.now();
    final data = account.toMap()
      ..['updated_at'] = now.toIso8601String()
      ..['is_synced'] = 0;

    if (existing.isEmpty) {
      await db.insert('accounts', data);
    } else {
      await db
          .update('accounts', data, where: 'id = ?', whereArgs: [account.id]);
    }
    Future.microtask(() => SyncService.sync());
  }

  Future<void> archiveAccount(String id, {bool isActive = false}) async {
    final db = await LocalDb.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'accounts',
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': now,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    Future.microtask(() => SyncService.sync());
  }

  Future<void> deleteAccount(String id) async {
    final db = await LocalDb.instance.database;
    final txCount = Sqflite.firstIntValue(await db.rawQuery(
          '''
      SELECT COUNT(*) FROM transactions 
      WHERE (account_id = ? OR to_account_id = ?) AND deleted_at IS NULL
      ''',
          [id, id],
        )) ??
        0;

    if (txCount > 0) {
      throw StateError(
          'Rekening yang memiliki riwayat transaksi tidak dapat dihapus. Silakan arsipkan rekening.');
    }

    final now = DateTime.now().toIso8601String();
    await db.update(
      'accounts',
      {
        'deleted_at': now,
        'updated_at': now,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    Future.microtask(() => SyncService.sync());
  }

  Future<List<AccountBalanceInfo>> getAccountBalances() async {
    final db = await LocalDb.instance.database;
    final rows = await db.query('v_account_balance');
    return rows.map((r) => AccountBalanceInfo.fromMap(r)).toList();
  }

  Future<Map<String, int>> getPoolBalances() async {
    final db = await LocalDb.instance.database;
    final rows = await db.query('v_pool_balance');
    final result = <String, int>{'utama': 0, 'tambahan': 0};
    for (final r in rows) {
      final pool = r['pool'] as String?;
      final balance = (r['balance'] as num?)?.toInt() ?? 0;
      if (pool != null) result[pool] = balance;
    }
    return result;
  }

  // =========================================================================
  // TRANSAKSI (LEDGER)
  // =========================================================================

  void _validateTransaction(LedgerTransaction tx) {
    if (tx.amount <= 0) {
      throw ArgumentError('Nominal transaksi harus lebih besar dari 0');
    }
    if (!['income', 'expense', 'transfer'].contains(tx.kind)) {
      throw ArgumentError(
          'Jenis transaksi tidak valid (harus income, expense, atau transfer)');
    }
    if (!['utama', 'tambahan'].contains(tx.pool)) {
      throw ArgumentError('Kas tidak valid (harus utama atau tambahan)');
    }
    if (!['kanvasing', 'ojol', 'pribadi', 'kendaraan'].contains(tx.activity)) {
      throw ArgumentError('Aktivitas tidak valid');
    }
    if (!['cleared', 'pending'].contains(tx.status)) {
      throw ArgumentError('Status transaksi tidak valid');
    }

    if (tx.kind == 'transfer') {
      if (tx.toAccountId == null || tx.toPool == null) {
        throw ArgumentError(
            'Transfer wajib memiliki rekening tujuan dan kas tujuan');
      }
      if (tx.status != 'cleared') {
        throw ArgumentError('Transaksi transfer harus berstatus cleared');
      }
      if (tx.toAccountId == tx.accountId && tx.toPool == tx.pool) {
        throw ArgumentError(
            'Rekening dan kas tujuan tidak boleh sama persis dengan sumber');
      }
    } else {
      if (tx.toAccountId != null || tx.toPool != null) {
        throw ArgumentError(
            'Transaksi non-transfer tidak boleh memiliki rekening atau kas tujuan');
      }
    }
  }

  Future<void> addTransaction(LedgerTransaction tx) async {
    _validateTransaction(tx);
    final db = await LocalDb.instance.database;
    final data = tx.toMap()..['is_synced'] = 0;
    await db.insert('transactions', data);
    Future.microtask(() => SyncService.sync());
  }

  Future<void> updateTransaction(LedgerTransaction tx) async {
    _validateTransaction(tx);
    final db = await LocalDb.instance.database;
    final now = DateTime.now().toIso8601String();
    final data = tx.toMap()
      ..['updated_at'] = now
      ..['is_synced'] = 0;
    await db.update('transactions', data, where: 'id = ?', whereArgs: [tx.id]);
    Future.microtask(() => SyncService.sync());
  }

  Future<void> softDeleteTransaction(String id) async {
    final db = await LocalDb.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'transactions',
      {
        'deleted_at': now,
        'updated_at': now,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    Future.microtask(() => SyncService.sync());
  }

  Future<void> markCleared(String id) async {
    final db = await LocalDb.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'transactions',
      {
        'status': 'cleared',
        'updated_at': now,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    Future.microtask(() => SyncService.sync());
  }

  Future<List<LedgerTransaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? accountId,
    String? pool,
    String? activity,
    String? kind,
    String? status,
    String? vehicleId,
    int? limit,
  }) async {
    final db = await LocalDb.instance.database;
    final whereClauses = <String>['deleted_at IS NULL'];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('tanggal >= ?');
      whereArgs.add(startDate.toIso8601String().split('T').first);
    }
    if (endDate != null) {
      whereClauses.add('tanggal <= ?');
      whereArgs.add(endDate.toIso8601String().split('T').first);
    }
    if (accountId != null) {
      whereClauses.add('(account_id = ? OR to_account_id = ?)');
      whereArgs.add(accountId);
      whereArgs.add(accountId);
    }
    if (pool != null) {
      whereClauses.add('(pool = ? OR to_pool = ?)');
      whereArgs.add(pool);
      whereArgs.add(pool);
    }
    if (activity != null) {
      whereClauses.add('activity = ?');
      whereArgs.add(activity);
    }
    if (kind != null) {
      whereClauses.add('kind = ?');
      whereArgs.add(kind);
    }
    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }
    if (vehicleId != null) {
      whereClauses.add('vehicle_id = ?');
      whereArgs.add(vehicleId);
    }

    final rows = await db.query(
      'transactions',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'tanggal DESC, created_at DESC',
      limit: limit,
    );
    return rows.map((r) => LedgerTransaction.fromMap(r)).toList();
  }

  Future<int> reconcile(String accountId, int actualBalance) async {
    final balances = await getAccountBalances();
    final found = balances.where((b) => b.accountId == accountId);
    final bookBalance = found.isNotEmpty ? found.first.balance : 0;
    final diff = actualBalance - bookBalance;

    if (diff != 0) {
      final now = DateTime.now();
      final kind = diff > 0 ? 'income' : 'expense';
      final amount = diff.abs();
      final tx = LedgerTransaction.create(
        tanggal: now,
        kind: kind,
        amount: amount,
        accountId: accountId,
        pool: 'utama',
        activity: 'pribadi',
        category: 'penyesuaian saldo',
        note:
            'Penyesuaian saldo (Buku: Rp $bookBalance, Aktual: Rp $actualBalance)',
        status: 'cleared',
      );
      await addTransaction(tx);
    }
    return diff;
  }

  Future<List<String>> getRecentCategories({String? activity}) async {
    final db = await LocalDb.instance.database;
    final where = activity != null
        ? 'deleted_at IS NULL AND category IS NOT NULL AND activity = ?'
        : 'deleted_at IS NULL AND category IS NOT NULL';
    final args = activity != null ? [activity] : null;

    final rows = await db.query(
      'transactions',
      columns: ['DISTINCT category'],
      where: where,
      whereArgs: args,
      orderBy: 'category ASC',
    );
    return rows
        .map((r) => r['category'] as String)
        .where((c) => c.isNotEmpty)
        .toList();
  }

  // =========================================================================
  // KENDARAAN & SERVIS
  // =========================================================================

  Future<List<Vehicle>> getVehicles({bool activeOnly = false}) async {
    final db = await LocalDb.instance.database;
    final where = activeOnly
        ? 'deleted_at IS NULL AND is_active = 1'
        : 'deleted_at IS NULL';
    final rows = await db.query('vehicles', where: where, orderBy: 'name ASC');
    return rows.map((r) => Vehicle.fromMap(r)).toList();
  }

  Future<Vehicle?> getVehicleById(String id) async {
    final db = await LocalDb.instance.database;
    final rows = await db.query(
      'vehicles',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Vehicle.fromMap(rows.first);
  }

  Future<void> saveVehicle(Vehicle vehicle) async {
    final db = await LocalDb.instance.database;
    final existing =
        await db.query('vehicles', where: 'id = ?', whereArgs: [vehicle.id]);
    final now = DateTime.now().toIso8601String();
    final data = vehicle.toMap()
      ..['updated_at'] = now
      ..['is_synced'] = 0;

    if (existing.isEmpty) {
      await db.insert('vehicles', data);
    } else {
      await db
          .update('vehicles', data, where: 'id = ?', whereArgs: [vehicle.id]);
    }
    Future.microtask(() => SyncService.sync());
  }

  Future<void> saveVehicleLog(VehicleLog log) async {
    final db = await LocalDb.instance.database;
    final tanggalStr = log.tanggal.toIso8601String().split('T').first;
    final existing = await db.query(
      'vehicle_logs',
      where: 'vehicle_id = ? AND tanggal = ?',
      whereArgs: [log.vehicleId, tanggalStr],
    );

    final now = DateTime.now().toIso8601String();
    final data = log.toMap()
      ..['updated_at'] = now
      ..['is_synced'] = 0;

    if (existing.isEmpty) {
      await db.insert('vehicle_logs', data);
    } else {
      await db.update(
        'vehicle_logs',
        data,
        where: 'vehicle_id = ? AND tanggal = ?',
        whereArgs: [log.vehicleId, tanggalStr],
      );
    }
    Future.microtask(() => SyncService.sync());
  }

  Future<VehicleLog?> getLatestVehicleLog(String vehicleId) async {
    final db = await LocalDb.instance.database;
    final rows = await db.query(
      'vehicle_logs',
      where: 'vehicle_id = ? AND deleted_at IS NULL',
      whereArgs: [vehicleId],
      orderBy: 'tanggal DESC, created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return VehicleLog.fromMap(rows.first);
  }

  Future<double> currentOdometer(String vehicleId) async {
    final latestLog = await getLatestVehicleLog(vehicleId);
    if (latestLog != null) return latestLog.odoEnd;

    final vehicle = await getVehicleById(vehicleId);
    return vehicle?.odoInitial ?? 0.0;
  }

  Future<List<VehicleLog>> getVehicleLogsMonth(DateTime month,
      {String? vehicleId}) async {
    final db = await LocalDb.instance.database;
    final startStr =
        DateTime(month.year, month.month, 1).toIso8601String().split('T').first;
    final endStr = DateTime(month.year, month.month + 1, 0)
        .toIso8601String()
        .split('T')
        .first;

    final where = <String>[
      'deleted_at IS NULL',
      'tanggal >= ?',
      'tanggal <= ?'
    ];
    final args = <dynamic>[startStr, endStr];
    if (vehicleId != null) {
      where.add('vehicle_id = ?');
      args.add(vehicleId);
    }

    final rows = await db.query(
      'vehicle_logs',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'tanggal ASC',
    );
    return rows.map((r) => VehicleLog.fromMap(r)).toList();
  }

  Future<List<ServiceItem>> getServiceItems(String vehicleId) async {
    final db = await LocalDb.instance.database;
    final rows = await db.query(
      'service_items',
      where: 'vehicle_id = ? AND deleted_at IS NULL',
      whereArgs: [vehicleId],
      orderBy: 'name ASC',
    );
    return rows.map((r) => ServiceItem.fromMap(r)).toList();
  }

  Future<void> saveServiceItem(ServiceItem item) async {
    final db = await LocalDb.instance.database;
    final existing =
        await db.query('service_items', where: 'id = ?', whereArgs: [item.id]);
    final now = DateTime.now().toIso8601String();
    final data = item.toMap()
      ..['updated_at'] = now
      ..['is_synced'] = 0;

    if (existing.isEmpty) {
      await db.insert('service_items', data);
    } else {
      await db
          .update('service_items', data, where: 'id = ?', whereArgs: [item.id]);
    }
    Future.microtask(() => SyncService.sync());
  }

  Future<List<ServiceItemEvaluation>> serviceDueList(
      [String? vehicleId]) async {
    final List<Vehicle> vehicles;
    if (vehicleId != null) {
      final all = await getVehicles();
      vehicles = all.where((v) => v.id == vehicleId).toList();
    } else {
      vehicles = await getVehicles(activeOnly: true);
    }

    final today = DateTime.now();
    final result = <ServiceItemEvaluation>[];

    for (final v in vehicles) {
      final items = await getServiceItems(v.id);
      final curOdo = await currentOdometer(v.id);
      for (final item in items) {
        final due = evaluateServiceItem(
          intervalKm: item.intervalKm,
          intervalDays: item.intervalDays,
          lastDate: item.lastServiceDate,
          lastOdo: item.lastServiceOdo,
          currentOdo: curOdo,
          today: today,
        );
        result.add(ServiceItemEvaluation(item: item, due: due));
      }
    }

    int priority(ServiceStatus s) {
      switch (s) {
        case ServiceStatus.overdue:
          return 0;
        case ServiceStatus.soon:
          return 1;
        case ServiceStatus.ok:
          return 2;
        case ServiceStatus.unknown:
          return 3;
      }
    }

    result.sort(
        (a, b) => priority(a.due.status).compareTo(priority(b.due.status)));
    return result;
  }

  Future<void> recordService({
    required String vehicleId,
    String? serviceItemId,
    required DateTime tanggal,
    double? odometer,
    int cost = 0,
    String? shop,
    String? note,
    String? accountId,
    String pool = 'utama',
  }) async {
    final db = await LocalDb.instance.database;
    await db.transaction((txn) async {
      final now = DateTime.now();
      String? txId;

      if (cost > 0 && accountId != null) {
        final tx = LedgerTransaction.create(
          tanggal: tanggal,
          kind: 'expense',
          amount: cost,
          accountId: accountId,
          pool: pool,
          activity: 'kendaraan',
          category: 'servis',
          vehicleId: vehicleId,
          note: note,
          status: 'cleared',
        );
        txId = tx.id;
        await txn.insert('transactions', tx.toMap()..['is_synced'] = 0);
      }

      final record = ServiceRecord.create(
        vehicleId: vehicleId,
        serviceItemId: serviceItemId,
        tanggal: tanggal,
        odometer: odometer,
        cost: cost,
        shop: shop,
        note: note,
        transactionId: txId,
      );
      await txn.insert('service_records', record.toMap()..['is_synced'] = 0);

      if (serviceItemId != null) {
        final itemUpdate = <String, dynamic>{
          'last_service_date': tanggal.toIso8601String().split('T').first,
          'updated_at': now.toIso8601String(),
          'is_synced': 0,
        };
        if (odometer != null) {
          itemUpdate['last_service_odo'] = odometer;
        }
        await txn.update(
          'service_items',
          itemUpdate,
          where: 'id = ?',
          whereArgs: [serviceItemId],
        );
      }
    });

    Future.microtask(() => SyncService.sync());
  }

  Future<List<ServiceRecord>> getServiceRecords(String vehicleId) async {
    final db = await LocalDb.instance.database;
    final rows = await db.query(
      'service_records',
      where: 'vehicle_id = ? AND deleted_at IS NULL',
      whereArgs: [vehicleId],
      orderBy: 'tanggal DESC, created_at DESC',
    );
    return rows.map((r) => ServiceRecord.fromMap(r)).toList();
  }

  // --- INTEGRASI BBM KE LEDGER (FASE 5) ---

  Future<void> saveFuelWithLedger({
    required FuelFilling filling,
    required bool recordInFinance,
    String? accountId,
    String pool = 'utama',
    bool isEdit = false,
  }) async {
    final db = await LocalDb.instance.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      if (isEdit) {
        await txn.update(
          'fuel_fillings',
          filling.toInsertMap()..['is_synced'] = 0,
          where: 'id = ?',
          whereArgs: [filling.id],
        );

        final existingTxRows = await txn.query(
          'transactions',
          where: 'fuel_filling_id = ? AND deleted_at IS NULL',
          whereArgs: [filling.id],
        );

        if (recordInFinance && accountId != null && filling.totalBiaya > 0) {
          final amount = filling.totalBiaya.round();
          if (existingTxRows.isNotEmpty) {
            final txId = existingTxRows.first['id'] as String;
            await txn.update(
              'transactions',
              {
                'tanggal': filling.tanggal.toIso8601String().split('T').first,
                'amount': amount,
                'account_id': accountId,
                'pool': pool,
                'activity': 'kendaraan',
                'category': 'bbm',
                'vehicle_id': filling.vehicleId,
                'note': filling.catatan ?? 'Pengisian BBM ${filling.liter}L',
                'updated_at': now,
                'is_synced': 0,
              },
              where: 'id = ?',
              whereArgs: [txId],
            );
          } else {
            final tx = LedgerTransaction.create(
              tanggal: filling.tanggal,
              kind: 'expense',
              amount: amount,
              accountId: accountId,
              pool: pool,
              activity: 'kendaraan',
              category: 'bbm',
              vehicleId: filling.vehicleId,
              fuelFillingId: filling.id,
              status: 'cleared',
              note: filling.catatan ?? 'Pengisian BBM ${filling.liter}L',
            );
            await txn.insert('transactions', tx.toMap()..['is_synced'] = 0);
          }
        } else if (!recordInFinance && existingTxRows.isNotEmpty) {
          for (final r in existingTxRows) {
            await txn.update(
              'transactions',
              {
                'deleted_at': now,
                'updated_at': now,
                'is_synced': 0,
              },
              where: 'id = ?',
              whereArgs: [r['id']],
            );
          }
        }
      } else {
        await txn.insert(
            'fuel_fillings', filling.toInsertMap()..['is_synced'] = 0);

        if (recordInFinance && accountId != null && filling.totalBiaya > 0) {
          final tx = LedgerTransaction.create(
            tanggal: filling.tanggal,
            kind: 'expense',
            amount: filling.totalBiaya.round(),
            accountId: accountId,
            pool: pool,
            activity: 'kendaraan',
            category: 'bbm',
            vehicleId: filling.vehicleId,
            fuelFillingId: filling.id,
            status: 'cleared',
            note: filling.catatan ?? 'Pengisian BBM ${filling.liter}L',
          );
          await txn.insert('transactions', tx.toMap()..['is_synced'] = 0);
        }
      }
    });

    Future.microtask(() => SyncService.sync());
  }

  Future<void> deleteFuelWithLedger(String fillingId) async {
    final db = await LocalDb.instance.database;
    await db.transaction((txn) async {
      await txn.insert('pending_deletions', {
        'table_name': 'fuel_fillings',
        'record_id': fillingId,
      });
      await txn
          .delete('fuel_fillings', where: 'id = ?', whereArgs: [fillingId]);

      final now = DateTime.now().toIso8601String();
      await txn.update(
        'transactions',
        {
          'deleted_at': now,
          'updated_at': now,
          'is_synced': 0,
        },
        where: 'fuel_filling_id = ? AND deleted_at IS NULL',
        whereArgs: [fillingId],
      );
    });

    Future.microtask(() => SyncService.sync());
  }

  Future<LedgerTransaction?> getLinkedFuelTransaction(
      String fuelFillingId) async {
    final db = await LocalDb.instance.database;
    final rows = await db.query(
      'transactions',
      where: 'fuel_filling_id = ? AND deleted_at IS NULL',
      whereArgs: [fuelFillingId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LedgerTransaction.fromMap(rows.first);
  }

  Future<List<FuelFilling>> getFuelFillingsByVehicle(String vehicleId) async {
    final db = await LocalDb.instance.database;
    final rows = await db.query(
      'fuel_fillings',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'tanggal DESC, created_at DESC',
    );
    return rows.map((e) => FuelFilling.fromMap(e)).toList();
  }

  Future<VehicleFuelStats> getVehicleFuelStats(String vehicleId) async {
    final fillings = await getFuelFillingsByVehicle(vehicleId);
    if (fillings.isEmpty) {
      return const VehicleFuelStats();
    }

    final latest = fillings.first;
    double? kmPerLiter;

    // Cari pengisian dengan odometer non-null yang berurutan
    final withOdo =
        fillings.where((f) => f.odometer != null && f.odometer! > 0).toList();
    if (withOdo.length >= 2) {
      final f1 = withOdo[0]; // lebih baru
      final f2 = withOdo[1]; // sebelumnya
      final deltaKm = f1.odometer! - f2.odometer!;
      if (deltaKm > 0 && f1.liter > 0) {
        kmPerLiter = deltaKm / f1.liter;
      }
    }

    return VehicleFuelStats(
      lastLiters: latest.liter,
      kmPerLiter: kmPerLiter,
      lastOdometer: latest.odometer,
      lastFillingDate: latest.tanggal,
    );
  }
}

class VehicleFuelStats {
  final double? lastLiters;
  final double? kmPerLiter;
  final double? lastOdometer;
  final DateTime? lastFillingDate;

  const VehicleFuelStats({
    this.lastLiters,
    this.kmPerLiter,
    this.lastOdometer,
    this.lastFillingDate,
  });
}
