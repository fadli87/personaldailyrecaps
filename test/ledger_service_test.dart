import 'package:flutter_test/flutter_test.dart';
import 'package:sf_daily_recap/models/account.dart';
import 'package:sf_daily_recap/models/ledger_transaction.dart';
import 'package:sf_daily_recap/services/ledger_schema.dart';
import 'package:sf_daily_recap/services/ledger_service.dart';
import 'package:sf_daily_recap/services/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late LedgerService service;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    for (final s in ledgerSchemaStatements) {
      await db.execute(s);
    }
    // Set singleton db
    LocalDb.setMockDatabase(db);
    service = LedgerService();

    // Seed akun
    await service.saveAccount(
        Account.create(name: 'Tunai', kind: 'cash', openingBalance: 100000));
    await service.saveAccount(
        Account.create(name: 'BCA', kind: 'bank', openingBalance: 500000));
    await service.saveAccount(
        Account.create(name: 'Dana', kind: 'ewallet', openingBalance: 0));
  });

  tearDown(() async {
    await db.close();
  });

  test('validasi transaksi salah bentuk ditolak service dengan pesan Indonesia',
      () async {
    final accounts = await service.getAccounts();
    final bca = accounts.firstWhere((a) => a.name == 'BCA');
    final dana = accounts.firstWhere((a) => a.name == 'Dana');

    // Nominal <= 0
    expect(
      () => service.addTransaction(LedgerTransaction.create(
        tanggal: DateTime(2026, 10, 2),
        kind: 'income',
        amount: 0,
        accountId: bca.id,
      )),
      throwsA(isA<ArgumentError>().having(
        (e) => e.message,
        'message',
        contains('Nominal transaksi harus lebih besar dari 0'),
      )),
    );

    // Transfer tanpa toAccountId / toPool
    expect(
      () => service.addTransaction(LedgerTransaction.create(
        tanggal: DateTime(2026, 10, 2),
        kind: 'transfer',
        amount: 50000,
        accountId: bca.id,
      )),
      throwsA(isA<ArgumentError>().having(
        (e) => e.message,
        'message',
        contains('Transfer wajib memiliki rekening tujuan dan kas tujuan'),
      )),
    );

    // Transfer dengan rekening dan kas tujuan sama persis
    expect(
      () => service.addTransaction(LedgerTransaction.create(
        tanggal: DateTime(2026, 10, 2),
        kind: 'transfer',
        amount: 50000,
        accountId: bca.id,
        toAccountId: bca.id,
        pool: 'utama',
        toPool: 'utama',
      )),
      throwsA(isA<ArgumentError>().having(
        (e) => e.message,
        'message',
        contains('Rekening dan kas tujuan tidak boleh sama persis'),
      )),
    );

    // Non-transfer memiliki toAccountId
    expect(
      () => service.addTransaction(LedgerTransaction.create(
        tanggal: DateTime(2026, 10, 2),
        kind: 'income',
        amount: 50000,
        accountId: bca.id,
        toAccountId: dana.id,
      )),
      throwsA(isA<ArgumentError>().having(
        (e) => e.message,
        'message',
        contains(
            'Transaksi non-transfer tidak boleh memiliki rekening atau kas tujuan'),
      )),
    );
  });

  test(
      'transaksi valid, pending tidak masuk saldo, soft delete mengurangi saldo',
      () async {
    final accounts = await service.getAccounts();
    final tunai = accounts.firstWhere((a) => a.name == 'Tunai');
    final bca = accounts.firstWhere((a) => a.name == 'BCA');
    final dana = accounts.firstWhere((a) => a.name == 'Dana');

    // 1. Pemasukan cleared 300.000 BCA
    final t1 = LedgerTransaction.create(
      tanggal: DateTime(2026, 10, 2),
      kind: 'income',
      amount: 300000,
      accountId: bca.id,
      activity: 'kanvasing',
      status: 'cleared',
    );
    await service.addTransaction(t1);

    // 2. Pemasukan pending 200.000 BCA
    final t2 = LedgerTransaction.create(
      tanggal: DateTime(2026, 10, 2),
      kind: 'income',
      amount: 200000,
      accountId: bca.id,
      activity: 'kanvasing',
      status: 'pending',
    );
    await service.addTransaction(t2);

    // 3. Pengeluaran 20.000 Tunai
    final t3 = LedgerTransaction.create(
      tanggal: DateTime(2026, 10, 2),
      kind: 'expense',
      amount: 20000,
      accountId: tunai.id,
      activity: 'kendaraan',
      status: 'cleared',
    );
    await service.addTransaction(t3);

    // 4. Pemasukan 150.000 Dana (tambahan)
    final t4 = LedgerTransaction.create(
      tanggal: DateTime(2026, 10, 2),
      kind: 'income',
      amount: 150000,
      accountId: dana.id,
      pool: 'tambahan',
      activity: 'ojol',
      status: 'cleared',
    );
    await service.addTransaction(t4);

    // 5. Transfer 100.000 Dana (tambahan) -> BCA (utama)
    final t5 = LedgerTransaction.create(
      tanggal: DateTime(2026, 10, 2),
      kind: 'transfer',
      amount: 100000,
      accountId: dana.id,
      pool: 'tambahan',
      toAccountId: bca.id,
      toPool: 'utama',
      activity: 'pribadi',
      status: 'cleared',
    );
    await service.addTransaction(t5);

    // Cek saldo rekening (angka skenario bagian 8: Tunai 80k, BCA 900k, Dana 50k)
    final balances = await service.getAccountBalances();
    final bMap = {for (final b in balances) b.name: b.balance};
    expect(bMap['Tunai'], 80000);
    expect(bMap['BCA'], 900000);
    expect(bMap['Dana'], 50000);

    // Cek saldo kas (utama: 380k, tambahan: 50k)
    final pools = await service.getPoolBalances();
    expect(pools['utama'], 380000);
    expect(pools['tambahan'], 50000);

    // Soft delete t1 (BCA 900k -> 600k)
    await service.softDeleteTransaction(t1.id);
    final balancesAfterDel = await service.getAccountBalances();
    final bMapAfterDel = {for (final b in balancesAfterDel) b.name: b.balance};
    expect(bMapAfterDel['BCA'], 600000);
  });
}
