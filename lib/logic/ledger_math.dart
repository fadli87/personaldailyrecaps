// Logika murni (tanpa database/UI) untuk modul Keuangan & Kendaraan.
// Semua uang = int rupiah. Semua fungsi di sini harus punya unit test (test/ledger_math_test.dart).

const List<String> kActivityOrder = <String>['kanvasing', 'ojol', 'pribadi'];

/// Alokasi biaya kendaraan bersama (activity 'kendaraan') ke kanvasing/ojol/pribadi menurut km.
/// Metode sisa terbesar: jumlah hasil SELALU sama dengan [totalCost].
/// Seri dipecah dengan urutan kanvasing, ojol, pribadi.
/// Jika total km <= 0 atau totalCost <= 0, semua 0 (pemanggil menampilkan biaya itu sebagai "belum teralokasi").
Map<String, int> allocateVehicleCost({
  required int totalCost,
  required double kmKanvasing,
  required double kmOjol,
  required double kmPribadi,
}) {
  final kms = <double>[kmKanvasing, kmOjol, kmPribadi];
  final result = <String, int>{for (final a in kActivityOrder) a: 0};

  var kmTotal = 0.0;
  for (final k in kms) {
    if (k > 0) kmTotal += k;
  }
  if (totalCost <= 0 || kmTotal <= 0) return result;

  final floors = List<int>.filled(3, 0);
  final fracs = List<double>.filled(3, 0);
  var assigned = 0;
  for (var i = 0; i < 3; i++) {
    final km = kms[i] > 0 ? kms[i] : 0.0;
    final quota = totalCost * km / kmTotal;
    floors[i] = quota.floor();
    fracs[i] = quota - floors[i];
    assigned += floors[i];
  }

  var remainder = totalCost - assigned;
  final order = <int>[0, 1, 2];
  order.sort((a, b) {
    final c = fracs[b].compareTo(fracs[a]);
    return c != 0 ? c : a.compareTo(b);
  });
  for (var j = 0; j < order.length && remainder > 0; j++) {
    floors[order[j]] += 1;
    remainder -= 1;
  }

  for (var i = 0; i < 3; i++) {
    result[kActivityOrder[i]] = floors[i];
  }
  return result;
}

/// Baris ledger minimal untuk perhitungan laporan.
class LedgerTx {
  final String kind; // income | expense | transfer
  final int amount;
  final String activity; // kanvasing | ojol | pribadi | kendaraan
  final String status; // cleared | pending

  const LedgerTx({
    required this.kind,
    required this.amount,
    required this.activity,
    this.status = 'cleared',
  });
}

class ActivityProfit {
  final int income;
  final int directExpense;
  final int allocatedVehicleCost;

  const ActivityProfit({
    this.income = 0,
    this.directExpense = 0,
    this.allocatedVehicleCost = 0,
  });

  int get profit => income - directExpense - allocatedVehicleCost;
}

/// Total biaya kendaraan bersama (activity 'kendaraan', hanya 'cleared').
int sumVehicleCost(List<LedgerTx> txs) {
  var total = 0;
  for (final t in txs) {
    if (t.kind == 'expense' &&
        t.activity == 'kendaraan' &&
        t.status == 'cleared') {
      total += t.amount;
    }
  }
  return total;
}

/// Komisi/pendapatan yang belum cair (status 'pending'), tidak masuk saldo.
int sumPendingIncome(List<LedgerTx> txs) {
  var total = 0;
  for (final t in txs) {
    if (t.kind == 'income' && t.status == 'pending') total += t.amount;
  }
  return total;
}

/// Profit per aktivitas. Transfer diabaikan. Hanya transaksi 'cleared' yang dihitung.
/// [allocatedVehicleCost] berasal dari [allocateVehicleCost].
Map<String, ActivityProfit> computeActivityProfits({
  required List<LedgerTx> txs,
  required Map<String, int> allocatedVehicleCost,
}) {
  final income = <String, int>{for (final a in kActivityOrder) a: 0};
  final expense = <String, int>{for (final a in kActivityOrder) a: 0};

  for (final t in txs) {
    if (t.status != 'cleared') continue;
    if (t.kind == 'income' && income.containsKey(t.activity)) {
      income[t.activity] = income[t.activity]! + t.amount;
    } else if (t.kind == 'expense' && expense.containsKey(t.activity)) {
      expense[t.activity] = expense[t.activity]! + t.amount;
    }
  }

  return <String, ActivityProfit>{
    for (final a in kActivityOrder)
      a: ActivityProfit(
        income: income[a]!,
        directExpense: expense[a]!,
        allocatedVehicleCost: allocatedVehicleCost[a] ?? 0,
      ),
  };
}

/// value / unit, atau null bila unit <= 0 (hindari pembagian nol di UI: tampilkan "-").
double? perUnit(num value, num unit) => unit <= 0 ? null : value / unit;

enum ServiceStatus { unknown, ok, soon, overdue }

class ServiceDue {
  final ServiceStatus status;
  final double? remainingKm;
  final int? remainingDays;

  const ServiceDue(this.status, {this.remainingKm, this.remainingDays});
}

/// Status reminder servis. Interval SELALU berasal dari input user (buku servis / Yamaha Motor On);
/// jangan pernah mengisi angka interval otomatis.
/// - overdue: sisa km atau sisa hari <= 0
/// - soon: sisa <= [soonRatio] x interval (default 20%)
/// - unknown: belum ada data servis terakhir untuk satuan yang punya interval
ServiceDue evaluateServiceItem({
  required int? intervalKm,
  required int? intervalDays,
  required DateTime? lastDate,
  required double? lastOdo,
  required double currentOdo,
  required DateTime today,
  double soonRatio = 0.2,
}) {
  double? remKm;
  int? remDays;

  if (intervalKm != null && lastOdo != null) {
    remKm = lastOdo + intervalKm - currentOdo;
  }
  if (intervalDays != null && lastDate != null) {
    final due = DateTime.utc(
        lastDate.year, lastDate.month, lastDate.day + intervalDays);
    final t = DateTime.utc(today.year, today.month, today.day);
    remDays = due.difference(t).inDays;
  }

  if (remKm == null && remDays == null) {
    return const ServiceDue(ServiceStatus.unknown);
  }

  const eps = 1e-9;
  final overdue =
      (remKm != null && remKm <= 0) || (remDays != null && remDays <= 0);
  if (overdue) {
    return ServiceDue(ServiceStatus.overdue,
        remainingKm: remKm, remainingDays: remDays);
  }

  final soon = (remKm != null &&
          intervalKm != null &&
          remKm <= intervalKm * soonRatio + eps) ||
      (remDays != null &&
          intervalDays != null &&
          remDays <= intervalDays * soonRatio + eps);
  return ServiceDue(
    soon ? ServiceStatus.soon : ServiceStatus.ok,
    remainingKm: remKm,
    remainingDays: remDays,
  );
}
