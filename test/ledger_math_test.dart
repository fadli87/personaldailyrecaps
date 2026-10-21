import 'package:flutter_test/flutter_test.dart';
import 'package:sf_daily_recap/logic/ledger_math.dart';

void main() {
  group('allocateVehicleCost', () {
    test('proporsional km, jumlah tepat', () {
      final r = allocateVehicleCost(
          totalCost: 80000, kmKanvasing: 60, kmOjol: 30, kmPribadi: 10);
      expect(r, {'kanvasing': 48000, 'ojol': 24000, 'pribadi': 8000});
    });

    test('sepertiga: sisa 1 rupiah ke kanvasing (urutan seri)', () {
      final r = allocateVehicleCost(
          totalCost: 100000, kmKanvasing: 1, kmOjol: 1, kmPribadi: 1);
      expect(r, {'kanvasing': 33334, 'ojol': 33333, 'pribadi': 33333});
      expect(r.values.reduce((a, b) => a + b), 100000);
    });

    test('sisa terbesar ke pecahan terbesar', () {
      final r = allocateVehicleCost(
          totalCost: 50001, kmKanvasing: 3, kmOjol: 3, kmPribadi: 4);
      expect(r, {'kanvasing': 15000, 'ojol': 15000, 'pribadi': 20001});
    });

    test('km nol di satu aktivitas', () {
      final r = allocateVehicleCost(
          totalCost: 1000, kmKanvasing: 1, kmOjol: 2, kmPribadi: 0);
      expect(r, {'kanvasing': 333, 'ojol': 667, 'pribadi': 0});
    });

    test('total km nol atau biaya nol -> semua 0 (tidak error)', () {
      expect(
          allocateVehicleCost(
              totalCost: 100000, kmKanvasing: 0, kmOjol: 0, kmPribadi: 0),
          {'kanvasing': 0, 'ojol': 0, 'pribadi': 0});
      expect(
          allocateVehicleCost(
              totalCost: 0, kmKanvasing: 1, kmOjol: 1, kmPribadi: 1),
          {'kanvasing': 0, 'ojol': 0, 'pribadi': 0});
    });
  });

  group('computeActivityProfits', () {
    test('profit per pekerjaan (komisi pending tidak dihitung)', () {
      final txs = <LedgerTx>[
        const LedgerTx(kind: 'income', amount: 300000, activity: 'kanvasing'),
        const LedgerTx(
            kind: 'income',
            amount: 200000,
            activity: 'kanvasing',
            status: 'pending'),
        const LedgerTx(kind: 'income', amount: 150000, activity: 'ojol'),
        const LedgerTx(kind: 'expense', amount: 20000, activity: 'kendaraan'),
        const LedgerTx(kind: 'expense', amount: 60000, activity: 'kendaraan'),
        const LedgerTx(kind: 'transfer', amount: 100000, activity: 'pribadi'),
      ];
      expect(sumVehicleCost(txs), 80000);
      expect(sumPendingIncome(txs), 200000);

      final alloc = allocateVehicleCost(
          totalCost: sumVehicleCost(txs),
          kmKanvasing: 60,
          kmOjol: 30,
          kmPribadi: 10);
      final p = computeActivityProfits(txs: txs, allocatedVehicleCost: alloc);
      expect(p['kanvasing']!.profit, 252000);
      expect(p['ojol']!.profit, 126000);
      expect(p['pribadi']!.profit, -8000);
    });
  });

  group('perUnit', () {
    test('pembagian aman', () {
      expect(perUnit(150000, 30), 5000);
      expect(perUnit(150000, 0), isNull);
    });
  });

  group('evaluateServiceItem', () {
    final today = DateTime(2026, 10, 21);

    ServiceDue byKm(double current) => evaluateServiceItem(
          intervalKm: 3000,
          intervalDays: null,
          lastDate: null,
          lastOdo: 10000,
          currentOdo: current,
          today: today,
        );

    ServiceDue byDays(DateTime last) => evaluateServiceItem(
          intervalKm: null,
          intervalDays: 90,
          lastDate: last,
          lastOdo: null,
          currentOdo: 0,
          today: today,
        );

    // Angka interval di test ini hanya contoh, BUKAN rekomendasi servis.
    test('berdasarkan km', () {
      expect(byKm(11000).status, ServiceStatus.ok);
      expect(byKm(11000).remainingKm, 2000);
      expect(byKm(12500).status, ServiceStatus.soon);
      expect(byKm(12400).status, ServiceStatus.soon); // tepat 20% (sisa 600)
      expect(byKm(13100).status, ServiceStatus.overdue);
      expect(byKm(13100).remainingKm, -100);
    });

    test('berdasarkan hari', () {
      expect(byDays(DateTime(2026, 10, 1)).status, ServiceStatus.ok);
      expect(byDays(DateTime(2026, 10, 1)).remainingDays, 70);
      expect(byDays(DateTime(2026, 8, 1)).status, ServiceStatus.soon);
      expect(byDays(DateTime(2026, 8, 1)).remainingDays, 9);
      expect(byDays(DateTime(2026, 7, 1)).status, ServiceStatus.overdue);
      expect(byDays(DateTime(2026, 7, 1)).remainingDays, -22);
    });

    test('km dan hari: yang terburuk menang', () {
      final r = evaluateServiceItem(
        intervalKm: 3000,
        intervalDays: 90,
        lastDate: DateTime(2026, 10, 1),
        lastOdo: 10000,
        currentOdo: 13000,
        today: today,
      );
      expect(r.status, ServiceStatus.overdue); // sisa km 0, sisa hari 70
    });

    test('belum ada data servis terakhir -> unknown', () {
      final r = evaluateServiceItem(
        intervalKm: 3000,
        intervalDays: null,
        lastDate: null,
        lastOdo: null,
        currentOdo: 13000,
        today: today,
      );
      expect(r.status, ServiceStatus.unknown);
    });
  });
}
