import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sf_daily_recap/models/account.dart';
import 'package:sf_daily_recap/models/fuel_filling.dart';
import 'package:sf_daily_recap/models/vehicle.dart';
import 'package:sf_daily_recap/services/ledger_schema.dart';
import 'package:sf_daily_recap/services/ledger_service.dart';
import 'package:sf_daily_recap/services/local_db.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late LedgerService ledgerService;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

    // Skema fuel_fillings dan pending_deletions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fuel_fillings (
        id TEXT PRIMARY KEY,
        daily_recap_id TEXT NOT NULL,
        tanggal TEXT NOT NULL,
        liter REAL NOT NULL,
        harga_per_liter REAL NOT NULL DEFAULT 0,
        total_biaya REAL NOT NULL DEFAULT 0,
        odometer REAL,
        catatan TEXT,
        vehicle_id TEXT,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_deletions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL
      )
    ''');

    for (final s in ledgerSchemaStatements) {
      await db.execute(s);
    }

    LocalDb.setMockDatabase(db);
    ledgerService = LedgerService();
  });

  tearDown(() async {
    LocalDb.setMockDatabase(null);
    await db.close();
  });

  test(
      'Integrasi BBM ke Ledger: simpan, update, soft delete, dan efisiensi km/L',
      () async {
    final now = DateTime.now();

    // 1. Setup Akun dan Motor
    final accBca = Account(
      id: 'ACC_BCA',
      name: 'BCA',
      kind: 'bank',
      openingBalance: 500000,
      createdAt: now,
      updatedAt: now,
    );
    await ledgerService.saveAccount(accBca);

    final motor = Vehicle(
      id: 'V_AEROX',
      name: 'Aerox 155',
      odoInitial: 5000,
      createdAt: now,
      updatedAt: now,
    );
    await ledgerService.saveVehicle(motor);

    // 2. Simpan Pengisian BBM pertama (3.0 L, Rp13.500/L, total 40.500, odo 5100)
    final date1 = DateTime(2026, 10, 2);
    final fuel1 = FuelFilling.create(
      dailyRecapId: 'recap_01',
      tanggal: date1,
      liter: 3.0,
      hargaPerLiter: 13500,
      totalBiaya: 40500,
      odometer: 5100,
      vehicleId: 'V_AEROX',
      catatan: 'Isi Pertamax',
    );

    await ledgerService.saveFuelWithLedger(
      filling: fuel1,
      recordInFinance: true,
      accountId: 'ACC_BCA',
      pool: 'utama',
      isEdit: false,
    );

    // Verifikasi transaksi ledger terbuat
    final linkedTx1 = await ledgerService.getLinkedFuelTransaction(fuel1.id);
    expect(linkedTx1, isNotNull);
    expect(linkedTx1!.kind, 'expense');
    expect(linkedTx1.amount, 40500);
    expect(linkedTx1.accountId, 'ACC_BCA');
    expect(linkedTx1.pool, 'utama');
    expect(linkedTx1.activity, 'kendaraan');
    expect(linkedTx1.category, 'bbm');
    expect(linkedTx1.vehicleId, 'V_AEROX');

    // Verifikasi saldo BCA berkurang 40.500 -> 459.500
    final balances = await ledgerService.getAccountBalances();
    final bcaBalance =
        balances.firstWhere((b) => b.accountId == 'ACC_BCA').balance;
    expect(bcaBalance, 500000 - 40500);

    // 3. Simpan Pengisian BBM kedua (4.0 L, Rp13.500/L, total 54.000, odo 5280)
    final date2 = DateTime(2026, 10, 5);
    final fuel2 = FuelFilling.create(
      dailyRecapId: 'recap_02',
      tanggal: date2,
      liter: 4.0,
      hargaPerLiter: 13500,
      totalBiaya: 54000,
      odometer: 5280,
      vehicleId: 'V_AEROX',
      catatan: 'Isi kedua full',
    );

    await ledgerService.saveFuelWithLedger(
      filling: fuel2,
      recordInFinance: true,
      accountId: 'ACC_BCA',
      pool: 'utama',
      isEdit: false,
    );

    // 4. Verifikasi Efisiensi Motor
    // Jarak: 5280 - 5100 = 180 km
    // Konsumsi: 180 km / 4.0 L = 45.0 km/L
    final stats = await ledgerService.getVehicleFuelStats('V_AEROX');
    expect(stats.lastLiters, 4.0);
    expect(stats.kmPerLiter, closeTo(45.0, 0.01));
    expect(stats.lastOdometer, 5280.0);

    // 5. Update Pengisian BBM kedua (ubah total menjadi 60.000)
    final fuel2Updated = fuel2.copyWith(totalBiaya: 60000, liter: 4.44);
    await ledgerService.saveFuelWithLedger(
      filling: fuel2Updated,
      recordInFinance: true,
      accountId: 'ACC_BCA',
      pool: 'utama',
      isEdit: true,
    );

    final linkedTx2 = await ledgerService.getLinkedFuelTransaction(fuel2.id);
    expect(linkedTx2!.amount, 60000,
        reason: 'Nominal transaksi otomatis terupdate ke 60.000');

    // 6. Hapus Pengisian BBM kedua via deleteFuelWithLedger
    await ledgerService.deleteFuelWithLedger(fuel2.id);

    // Verifikasi fuel2 terhapus dari tabel fuel_fillings
    final fillingsAfterDel =
        await ledgerService.getFuelFillingsByVehicle('V_AEROX');
    expect(fillingsAfterDel.length, 1);
    expect(fillingsAfterDel.first.id, fuel1.id);

    // Verifikasi transaksi tertaut di-soft-delete (tidak aktif lagi)
    final linkedTx2AfterDel =
        await ledgerService.getLinkedFuelTransaction(fuel2.id);
    expect(linkedTx2AfterDel, isNull,
        reason: 'Transaksi tertaut otomatis di-soft-delete');

    // Verifikasi saldo kembali normal hanya terpotong fuel1 (40.500)
    final balancesAfterDel = await ledgerService.getAccountBalances();
    final bcaAfterDel =
        balancesAfterDel.firstWhere((b) => b.accountId == 'ACC_BCA').balance;
    expect(bcaAfterDel, 500000 - 40500);
  });
}
