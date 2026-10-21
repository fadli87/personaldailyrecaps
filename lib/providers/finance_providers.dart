import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account.dart';
import '../models/fuel_filling.dart';
import '../models/ledger_transaction.dart';
import '../models/service_record.dart';
import '../models/vehicle.dart';
import '../models/vehicle_log.dart';
import '../services/finance_report_service.dart';
import '../services/ledger_service.dart';

final ledgerServiceProvider = Provider<LedgerService>((ref) {
  return LedgerService();
});

final financeReportServiceProvider = Provider<FinanceReportService>((ref) {
  final ledger = ref.watch(ledgerServiceProvider);
  return FinanceReportService(ledgerService: ledger);
});

// Accounts
final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final service = ref.watch(ledgerServiceProvider);
  return service.getAccounts();
});

final activeAccountsProvider = FutureProvider<List<Account>>((ref) async {
  final service = ref.watch(ledgerServiceProvider);
  return service.getAccounts(activeOnly: true);
});

final accountBalancesProvider =
    FutureProvider<List<AccountBalanceInfo>>((ref) async {
  final service = ref.watch(ledgerServiceProvider);
  return service.getAccountBalances();
});

final poolBalancesProvider = FutureProvider<Map<String, int>>((ref) async {
  final service = ref.watch(ledgerServiceProvider);
  return service.getPoolBalances();
});

// Vehicles
final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final service = ref.watch(ledgerServiceProvider);
  return service.getVehicles();
});

final activeVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final service = ref.watch(ledgerServiceProvider);
  return service.getVehicles(activeOnly: true);
});

final vehicleOdometerProvider =
    FutureProvider.family<double, String>((ref, vehicleId) async {
  final service = ref.watch(ledgerServiceProvider);
  return service.currentOdometer(vehicleId);
});

final serviceDueProvider =
    FutureProvider<List<ServiceItemEvaluation>>((ref) async {
  final service = ref.watch(ledgerServiceProvider);
  return service.serviceDueList();
});

final vehicleServiceDueProvider =
    FutureProvider.family<List<ServiceItemEvaluation>, String>(
        (ref, vehicleId) async {
  final service = ref.watch(ledgerServiceProvider);
  return service.serviceDueList(vehicleId);
});

final vehicleLogsMonthProvider =
    FutureProvider.family<List<VehicleLog>, String>((ref, vehicleId) async {
  final service = ref.watch(ledgerServiceProvider);
  final month = ref.watch(financeMonthProvider);
  return service.getVehicleLogsMonth(month, vehicleId: vehicleId);
});

final serviceRecordsProvider =
    FutureProvider.family<List<ServiceRecord>, String>((ref, vehicleId) async {
  final service = ref.watch(ledgerServiceProvider);
  return service.getServiceRecords(vehicleId);
});

final vehicleFuelStatsProvider =
    FutureProvider.family<VehicleFuelStats, String>((ref, vehicleId) async {
  final service = ref.watch(ledgerServiceProvider);
  return service.getVehicleFuelStats(vehicleId);
});

final vehicleFuelFillingsProvider =
    FutureProvider.family<List<FuelFilling>, String>((ref, vehicleId) async {
  final service = ref.watch(ledgerServiceProvider);
  return service.getFuelFillingsByVehicle(vehicleId);
});

// Month selector for finance tab
class FinanceMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  void setMonth(DateTime month) {
    state = DateTime(month.year, month.month, 1);
  }

  void previousMonth() {
    state = DateTime(state.year, state.month - 1, 1);
  }

  void nextMonth() {
    state = DateTime(state.year, state.month + 1, 1);
  }
}

final financeMonthProvider =
    NotifierProvider<FinanceMonthNotifier, DateTime>(FinanceMonthNotifier.new);

// Summary provider watching financeMonthProvider
final monthSummaryProvider = FutureProvider<FinanceMonthSummary>((ref) async {
  final reportService = ref.watch(financeReportServiceProvider);
  final month = ref.watch(financeMonthProvider);
  return reportService.getMonthSummary(month);
});

// Transactions filter
class TransactionFilter {
  final String? accountId;
  final String? pool;
  final String? activity;
  final String? kind;
  final String? status;
  final String? vehicleId;
  final DateTime? startDate;
  final DateTime? endDate;

  const TransactionFilter({
    this.accountId,
    this.pool,
    this.activity,
    this.kind,
    this.status,
    this.vehicleId,
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionFilter &&
          runtimeType == other.runtimeType &&
          accountId == other.accountId &&
          pool == other.pool &&
          activity == other.activity &&
          kind == other.kind &&
          status == other.status &&
          vehicleId == other.vehicleId &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => Object.hash(
        accountId,
        pool,
        activity,
        kind,
        status,
        vehicleId,
        startDate,
        endDate,
      );
}

final transactionsProvider =
    FutureProvider.family<List<LedgerTransaction>, TransactionFilter>(
        (ref, filter) async {
  final service = ref.watch(ledgerServiceProvider);
  return service.getTransactions(
    startDate: filter.startDate,
    endDate: filter.endDate,
    accountId: filter.accountId,
    pool: filter.pool,
    activity: filter.activity,
    kind: filter.kind,
    status: filter.status,
    vehicleId: filter.vehicleId,
  );
});
