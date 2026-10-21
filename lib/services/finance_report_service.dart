import 'package:sqflite/sqflite.dart';
import '../logic/ledger_math.dart';
import 'ledger_service.dart';
import 'local_db.dart';

class FinanceMonthSummary {
  final DateTime month;
  final Map<String, ActivityProfit> activityProfits;
  final int totalVehicleCost;
  final int unallocatedVehicleCost;
  final int pendingIncome;
  final double totalKm;
  final double kmKanvasing;
  final double kmOjol;
  final double kmPribadi;
  final double jamOnlineOjol;
  final double? ojolIncomePerKm;
  final double? ojolIncomePerHour;
  final double? biayaMotorPerKm;
  final int legacyOjolNetEarning;

  const FinanceMonthSummary({
    required this.month,
    required this.activityProfits,
    required this.totalVehicleCost,
    required this.unallocatedVehicleCost,
    required this.pendingIncome,
    required this.totalKm,
    required this.kmKanvasing,
    required this.kmOjol,
    required this.kmPribadi,
    required this.jamOnlineOjol,
    this.ojolIncomePerKm,
    this.ojolIncomePerHour,
    this.biayaMotorPerKm,
    required this.legacyOjolNetEarning,
  });
}

class FinanceReportService {
  final LedgerService ledgerService;

  FinanceReportService({required this.ledgerService});

  Future<FinanceMonthSummary> getMonthSummary(DateTime month,
      {String? vehicleId}) async {
    final db = await LocalDb.instance.database;
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);

    // 1. Ambil transaksi bulan itu (cleared & pending)
    final allTxs = await ledgerService.getTransactions(
      startDate: startDate,
      endDate: endDate,
      vehicleId: vehicleId,
    );

    final ledgerTxs = allTxs
        .map((t) => LedgerTx(
              kind: t.kind,
              amount: t.amount,
              activity: t.activity,
              status: t.status,
            ))
        .toList();

    // 2. Ambil log kendaraan bulan itu
    final logs =
        await ledgerService.getVehicleLogsMonth(month, vehicleId: vehicleId);
    double kmKanvasing = 0;
    double kmOjol = 0;
    double kmPribadi = 0;
    double jamOnlineOjol = 0;

    for (final l in logs) {
      kmKanvasing += l.kmKanvasing;
      kmOjol += l.kmOjol;
      kmPribadi += l.kmPribadi;
      if (l.jamOnlineOjol != null) jamOnlineOjol += l.jamOnlineOjol!;
    }

    final totalKm = kmKanvasing + kmOjol + kmPribadi;
    final totalVehicleCost = sumVehicleCost(ledgerTxs);
    final pendingIncome = sumPendingIncome(ledgerTxs);

    // 3. Alokasi biaya motor
    Map<String, int> allocated;
    int unallocatedVehicleCost = 0;

    if (totalKm <= 0 && totalVehicleCost > 0) {
      unallocatedVehicleCost = totalVehicleCost;
      allocated = {'kanvasing': 0, 'ojol': 0, 'pribadi': 0};
    } else {
      allocated = allocateVehicleCost(
        totalCost: totalVehicleCost,
        kmKanvasing: kmKanvasing,
        kmOjol: kmOjol,
        kmPribadi: kmPribadi,
      );
    }

    // 4. Hitung profit per aktivitas (hanya cleared)
    final activityProfits = computeActivityProfits(
      txs: ledgerTxs,
      allocatedVehicleCost: allocated,
    );

    // 5. Efisiensi
    final ojolIncome = activityProfits['ojol']?.income ?? 0;
    final ojolIncomePerKm = perUnit(ojolIncome, kmOjol);
    final ojolIncomePerHour = perUnit(ojolIncome, jamOnlineOjol);
    final biayaMotorPerKm = perUnit(totalVehicleCost, totalKm);

    // 6. Legacy Ojol Net Earning dari daily_recap_summary
    final startStr = startDate.toIso8601String().split('T').first;
    final endStr = endDate.toIso8601String().split('T').first;
    final legacyRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(net_earning), 0) as total_legacy
      FROM daily_recap_summary
      WHERE tanggal >= ? AND tanggal <= ?
      ''',
      [startStr, endStr],
    );
    final legacyOjolNetEarning =
        (legacyRows.first['total_legacy'] as num?)?.toInt() ?? 0;

    return FinanceMonthSummary(
      month: month,
      activityProfits: activityProfits,
      totalVehicleCost: totalVehicleCost,
      unallocatedVehicleCost: unallocatedVehicleCost,
      pendingIncome: pendingIncome,
      totalKm: totalKm,
      kmKanvasing: kmKanvasing,
      kmOjol: kmOjol,
      kmPribadi: kmPribadi,
      jamOnlineOjol: jamOnlineOjol,
      ojolIncomePerKm: ojolIncomePerKm,
      ojolIncomePerHour: ojolIncomePerHour,
      biayaMotorPerKm: biayaMotorPerKm,
      legacyOjolNetEarning: legacyOjolNetEarning,
    );
  }
}
