import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sf_daily_recap/services/ledger_schema.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  const now = '2026-10-02T10:00:00';

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    for (final s in ledgerSchemaStatements) {
      await db.execute(s);
    }
    for (final a in [
      {'id': 'A1', 'name': 'Tunai', 'kind': 'cash', 'opening_balance': 100000},
      {'id': 'A2', 'name': 'BCA', 'kind': 'bank', 'opening_balance': 500000},
      {'id': 'A3', 'name': 'Dana', 'kind': 'ewallet', 'opening_balance': 0},
    ]) {
      await db.insert('accounts', {...a, 'created_at': now, 'updated_at': now});
    }
  });

  tearDown(() async => db.close());

  Future<void> tx(
    String id,
    String kind,
    int amount,
    String acc,
    String pool,
    String activity, {
    String? toAcc,
    String? toPool,
    String status = 'cleared',
  }) {
    return db.insert('transactions', {
      'id': id,
      'tanggal': '2026-10-02',
      'kind': kind,
      'amount': amount,
      'account_id': acc,
      'to_account_id': toAcc,
      'pool': pool,
      'to_pool': toPool,
      'activity': activity,
      'status': status,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> seed() async {
    await tx('t1', 'income', 300000, 'A2', 'utama', 'kanvasing');
    await tx('t2', 'income', 200000, 'A2', 'utama', 'kanvasing',
        status: 'pending');
    await tx('t3', 'expense', 20000, 'A1', 'utama', 'kendaraan');
    await tx('t4', 'income', 150000, 'A3', 'tambahan', 'ojol');
    await tx('t5', 'transfer', 100000, 'A3', 'tambahan', 'pribadi',
        toAcc: 'A2', toPool: 'utama');
  }

  test('saldo rekening dan saldo kas', () async {
    await seed();
    final acc = {
      for (final r in await db.query('v_account_balance'))
        r['name'] as String: r['balance'] as int,
    };
    expect(acc, {'Tunai': 80000, 'BCA': 900000, 'Dana': 50000});

    final pool = {
      for (final r in await db.query('v_pool_balance'))
        r['pool'] as String: r['balance'] as int,
    };
    expect(pool, {'utama': 380000, 'tambahan': 50000});
  });

  test('soft delete mengurangi saldo; pending tidak dihitung', () async {
    await seed();
    await db.update('transactions', {'deleted_at': now},
        where: 'id = ?', whereArgs: ['t1']);
    final rows = await db
        .query('v_account_balance', where: 'name = ?', whereArgs: ['BCA']);
    expect(rows.first['balance'], 600000);
  });

  test('constraint menolak data yang salah bentuk', () async {
    expect(() => tx('x1', 'transfer', 1000, 'A2', 'utama', 'pribadi'),
        throwsA(isA<DatabaseException>()));
    expect(() => tx('x2', 'expense', 0, 'A2', 'utama', 'pribadi'),
        throwsA(isA<DatabaseException>()));
    expect(
      () => tx('x3', 'income', 1000, 'A2', 'utama', 'pribadi',
          toAcc: 'A1', toPool: 'utama'),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      () => tx('x4', 'transfer', 1000, 'A2', 'utama', 'pribadi',
          toAcc: 'A2', toPool: 'utama'),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('item servis wajib punya minimal satu interval', () async {
    expect(
      () => db.insert('service_items', {
        'id': 's1',
        'vehicle_id': 'v1',
        'name': 'Contoh',
        'created_at': now,
        'updated_at': now,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}
