import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sf_daily_recap/models/account.dart';
import 'package:sf_daily_recap/models/ledger_transaction.dart';
import 'package:sf_daily_recap/models/vehicle.dart';
import 'package:sf_daily_recap/models/vehicle_log.dart';
import 'package:sf_daily_recap/services/ledger_schema.dart';
import 'package:sf_daily_recap/services/ledger_service.dart';
import 'package:sf_daily_recap/services/finance_report_service.dart';
import 'package:sf_daily_recap/services/local_db.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late LedgerService ledgerService;
  late FinanceReportService reportService;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    for (final s in ledgerSchemaStatements) {
      await db.execute(s);
    }
    LocalDb.setMockDatabase(db);
    ledgerService = LedgerService();
    reportService = FinanceReportService(ledgerService: ledgerService);
  });

  tearDown(() async {
    LocalDb.setMockDatabase(null);
    await db.close();
  });

  test('Skenario Lengkap Bagian 8 Panduan Agy (End-to-End)', () async {
    final now = DateTime.now();
    // 1. Data Awal: Tunai 100k, BCA 500k, Dana 0
    final accTunai = Account(
      id: 'A_TUNAI',
      name: 'Tunai',
      kind: 'cash',
      openingBalance: 100000,
      createdAt: now,
      updatedAt: now,
    );
    final accBca = Account(
      id: 'A_BCA',
      name: 'BCA',
      kind: 'bank',
      openingBalance: 500000,
      createdAt: now,
      updatedAt: now,
    );
    final accDana = Account(
      id: 'A_DANA',
      name: 'Dana',
      kind: 'ewallet',
      openingBalance: 0,
      createdAt: now,
      updatedAt: now,
    );

    await ledgerService.saveAccount(accTunai);
    await ledgerService.saveAccount(accBca);
    await ledgerService.saveAccount(accDana);

    // Motor Jupiter Z & Aerox
    final motorJupiter = Vehicle(
      id: 'V_JUPITER',
      name: 'Jupiter Z',
      odoInitial: 10000,
      createdAt: now,
      updatedAt: now,
    );
    await ledgerService.saveVehicle(motorJupiter);

    // 2. Transaksi (semua 2 Okt 2026)
    final date = DateTime(2026, 10, 2);

    // #1: Pemasukan 300.000 | BCA | utama | kanvasing | cleared
    final t1 = LedgerTransaction(
      id: 'tx_1',
      tanggal: date,
      kind: 'income',
      amount: 300000,
      accountId: 'A_BCA',
      pool: 'utama',
      activity: 'kanvasing',
      category: 'komisi',
      status: 'cleared',
      createdAt: now,
      updatedAt: now,
    );
    await ledgerService.addTransaction(t1);

    // #2: Pemasukan 200.000 | BCA | utama | kanvasing | pending
    final t2 = LedgerTransaction(
      id: 'tx_2',
      tanggal: date,
      kind: 'income',
      amount: 200000,
      accountId: 'A_BCA',
      pool: 'utama',
      activity: 'kanvasing',
      category: 'komisi',
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    );
    await ledgerService.addTransaction(t2);

    // #3: Pengeluaran 20.000 | Tunai | utama | kendaraan (bbm) | cleared
    final t3 = LedgerTransaction(
      id: 'tx_3',
      tanggal: date,
      kind: 'expense',
      amount: 20000,
      accountId: 'A_TUNAI',
      pool: 'utama',
      activity: 'kendaraan',
      category: 'bbm',
      vehicleId: 'V_JUPITER',
      status: 'cleared',
      createdAt: now,
      updatedAt: now,
    );
    await ledgerService.addTransaction(t3);

    // #4: Pemasukan 150.000 | Dana | tambahan | ojol | cleared
    final t4 = LedgerTransaction(
      id: 'tx_4',
      tanggal: date,
      kind: 'income',
      amount: 150000,
      accountId: 'A_DANA',
      pool: 'tambahan',
      activity: 'ojol',
      status: 'cleared',
      createdAt: now,
      updatedAt: now,
    );
    await ledgerService.addTransaction(t4);

    // #5: Transfer 100.000 | Dana (tambahan) -> BCA (utama) | cleared
    final t5 = LedgerTransaction(
      id: 'tx_5',
      tanggal: date,
      kind: 'transfer',
      amount: 100000,
      accountId: 'A_DANA',
      toAccountId: 'A_BCA',
      pool: 'tambahan',
      toPool: 'utama',
      activity: 'pribadi',
      status: 'cleared',
      createdAt: now,
      updatedAt: now,
    );
    await ledgerService.addTransaction(t5);

    // --- VERIFIKASI SALDO AWAL & TRANSAKSI ---
    final balances = await ledgerService.getAccountBalances();
    final balanceMap = {for (final b in balances) b.name: b.balance};

    expect(balanceMap['Tunai'], 80000, reason: 'Tunai 100k - 20k = 80k');
    expect(balanceMap['BCA'], 900000,
        reason: 'BCA 500k + 300k + 100k (transfer) = 900k');
    expect(balanceMap['Dana'], 50000,
        reason: 'Dana 0 + 150k - 100k (transfer) = 50k');

    final pools = await ledgerService.getPoolBalances();
    expect(pools['utama'], 380000, reason: 'Utama: 300k - 20k + 100k = 380k');
    expect(pools['tambahan'], 50000, reason: 'Tambahan: 150k - 100k = 50k');

    // Komisi belum cair = 200.000
    final summaryAwal = await reportService.monthSummary(date);
    expect(summaryAwal.pendingIncome, 200000);

    // --- VERIFIKASI SOFT DELETE TRANSAKSI #1 ---
    await ledgerService.softDeleteTransaction('tx_1');
    final balancesAfterDelete = await ledgerService.getAccountBalances();
    final bcaAfterDelete =
        balancesAfterDelete.firstWhere((b) => b.name == 'BCA').balance;
    expect(bcaAfterDelete, 600000,
        reason: 'BCA kembali ke 600k setelah tx_1 soft-deleted');

    // Pulihkan kembali tx_1 untuk pengujian alokasi servis
    await ledgerService.updateTransaction(t1.copyWith(deletedAt: null));

    // --- TAMBAH SERVIS KENDARAAN 60.000 ---
    // Total biaya kendaraan menjadi 20k (BBM) + 60k (servis) = 80.000
    await ledgerService.recordService(
      vehicleId: 'V_JUPITER',
      tanggal: date,
      odometer: 10100,
      cost: 60000,
      shop: 'Yamaha Surya',
      note: 'Ganti oli & servis berkala',
      accountId: 'A_BCA',
      pool: 'utama',
    );

    // Catat log km bulan itu: kanvasing 60 / ojol 30 / pribadi 10 (total 100 km)
    await ledgerService.saveVehicleLog(
      VehicleLog.create(
        vehicleId: 'V_JUPITER',
        tanggal: date,
        odoEnd: 10100,
        kmKanvasing: 60,
        kmOjol: 30,
        kmPribadi: 10,
        jamOnlineOjol: 3.0,
      ),
    );

    // Verifikasi laporan performa bulanan
    final summaryAkhir = await reportService.monthSummary(date);
    expect(summaryAkhir.totalVehicleCost, 80000);
    expect(summaryAkhir.unallocatedVehicleCost, 0);

    final kanvasingProfit = summaryAkhir.activityProfits['kanvasing']!;
    final ojolProfit = summaryAkhir.activityProfits['ojol']!;
    final pribadiProfit = summaryAkhir.activityProfits['pribadi']!;

    // Alokasi biaya motor 80.000 ke 60/30/10 -> 48.000 / 24.000 / 8.000
    expect(kanvasingProfit.allocatedVehicleCost, 48000);
    expect(ojolProfit.allocatedVehicleCost, 24000);
    expect(pribadiProfit.allocatedVehicleCost, 8000);

    // Profit Kanvasing: 300k - 0 - 48k = 252.000
    expect(kanvasingProfit.profit, 252000);
    // Profit Ojol (Ledger): 150k - 0 - 24k = 126.000
    expect(ojolProfit.profit, 126000);
    // Profit Pribadi: 0 - 0 - 8k = -8.000
    expect(pribadiProfit.profit, -8000);

    // Efisiensi Ojol:
    // 150.000 / 30 km = 5.000 / km
    expect(summaryAkhir.ojolIncomePerKm, 5000);
    // 150.000 / 3.0 jam = 50.000 / jam
    expect(summaryAkhir.ojolIncomePerHour, 50000);
    // Biaya motor / km: 80.000 / 100 km = 800 / km
    expect(summaryAkhir.biayaMotorPerKm, 800);
  });
}
