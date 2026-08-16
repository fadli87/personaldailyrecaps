import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/recap_service.dart';
import '../models/daily_recap.dart';
import '../models/daily_order.dart';
import '../models/petty_cash_item.dart';

final recapServiceProvider = Provider<RecapService>((ref) {
  return RecapService();
});

final recapsProvider = FutureProvider<List<DailyRecap>>((ref) async {
  final service = ref.watch(recapServiceProvider);
  return service.getRecaps();
});

class RecapDetailState {
  final String? recapId;
  final DateTime tanggal;
  final double cashAwal;
  final double saldoAwalApp;
  final double tip;
  final double insentif;
  final List<DailyOrder> orders;
  final List<PettyCashItem> pettyCash;
  final DailyRecap? summary;
  final bool isLoading;

  RecapDetailState({
    this.recapId,
    required this.tanggal,
    this.cashAwal = 0,
    this.saldoAwalApp = 0,
    this.tip = 0,
    this.insentif = 0,
    this.orders = const [],
    this.pettyCash = const [],
    this.summary,
    this.isLoading = true,
  });

  RecapDetailState copyWith({
    String? recapId,
    DateTime? tanggal,
    double? cashAwal,
    double? saldoAwalApp,
    double? tip,
    double? insentif,
    List<DailyOrder>? orders,
    List<PettyCashItem>? pettyCash,
    DailyRecap? summary,
    bool? isLoading,
  }) {
    return RecapDetailState(
      recapId: recapId ?? this.recapId,
      tanggal: tanggal ?? this.tanggal,
      cashAwal: cashAwal ?? this.cashAwal,
      saldoAwalApp: saldoAwalApp ?? this.saldoAwalApp,
      tip: tip ?? this.tip,
      insentif: insentif ?? this.insentif,
      orders: orders ?? this.orders,
      pettyCash: pettyCash ?? this.pettyCash,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class RecapDetailNotifier extends Notifier<RecapDetailState> {
  final String? recapId;
  late final RecapService _service;

  RecapDetailNotifier(this.recapId);

  @override
  RecapDetailState build() {
    _service = ref.watch(recapServiceProvider);

    // Asynchronous load
    Future.microtask(() => load());

    return RecapDetailState(
      recapId: recapId,
      tanggal: DateTime.now(),
      isLoading: true,
    );
  }

  Future<void> load() async {
    final activeId = recapId;
    if (activeId != null) {
      final orders = await _service.getOrders(activeId);
      final petty = await _service.getPettyCash(activeId);
      final all = await _service.getRecaps();
      // Cari summary dari list yang ter-cached atau buat default
      final match = all.firstWhere(
        (r) => r.id == activeId,
        orElse: () => DailyRecap(
          id: activeId,
          tanggal: state.tanggal,
          cashAwal: 0,
          saldoAwalApp: 0,
        ),
      );

      state = state.copyWith(
        summary: match,
        tanggal: match.tanggal,
        cashAwal: match.cashAwal,
        saldoAwalApp: match.saldoAwalApp,
        tip: match.tip,
        insentif: match.insentif,
        orders: orders,
        pettyCash: petty,
        isLoading: false,
      );
    } else {
      // Jika recapId null (ingin membuat rekap hari ini), periksa terlebih dahulu apakah
      // rekap untuk tanggal hari ini sudah ada di database untuk menghindari UNIQUE constraint error.
      final todayRecap = await _service.getRecapByDate(DateTime.now());
      if (todayRecap != null) {
        final orders = await _service.getOrders(todayRecap.id);
        final petty = await _service.getPettyCash(todayRecap.id);
        state = state.copyWith(
          recapId: todayRecap.id,
          summary: todayRecap,
          tanggal: todayRecap.tanggal,
          cashAwal: todayRecap.cashAwal,
          saldoAwalApp: todayRecap.saldoAwalApp,
          tip: todayRecap.tip,
          insentif: todayRecap.insentif,
          orders: orders,
          pettyCash: petty,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          pettyCash: pettyCashDenoms.map((d) => PettyCashItem(denom: d, qty: 0)).toList(),
          isLoading: false,
        );
      }
    }
  }

  Future<void> saveHeader({
    required double cashAwal,
    required double saldoAwalApp,
    required double tip,
    required double insentif,
  }) async {
    String? id = state.recapId;
    if (id == null) {
      id = await _service.createRecap(
        tanggal: state.tanggal,
        cashAwal: cashAwal,
        saldoAwalApp: saldoAwalApp,
      );
      state = state.copyWith(recapId: id);
    } else {
      await _service.updateRecapHeader(
        id: id,
        cashAwal: cashAwal,
        saldoAwalApp: saldoAwalApp,
      );
    }
    await _service.saveExtra(id, tip: tip, insentif: insentif);
    await refreshSummary();
    ref.invalidate(recapsProvider);
  }

  Future<void> refreshSummary() async {
    final id = state.recapId;
    if (id == null) return;
    final all = await _service.getRecaps();
    final match = all.where((r) => r.id == id).toList();
    final orders = await _service.getOrders(id);
    final petty = await _service.getPettyCash(id);
    state = state.copyWith(
      summary: match.isNotEmpty ? match.first : state.summary,
      orders: orders,
      pettyCash: petty,
    );
    ref.invalidate(recapsProvider);
  }

  Future<void> upsertOrder(DailyOrder order) async {
    await _service.upsertOrder(order);
    await refreshSummary();
  }

  Future<void> deleteOrder(DailyOrder o) async {
    if (o.id == null) return;
    await _service.deleteOrder(o.id!);
    await refreshSummary();
  }

  void updatePettyCashQty(int index, int qty) {
    final updated = List<PettyCashItem>.from(state.pettyCash);
    updated[index] = updated[index].copyWith(qty: qty);
    state = state.copyWith(pettyCash: updated);
  }

  Future<void> savePettyCash(List<PettyCashItem> items) async {
    final id = state.recapId;
    if (id == null) return;
    await _service.savePettyCash(id, items);
    await refreshSummary();
  }
}

final recapDetailNotifierProvider =
    NotifierProvider.family<RecapDetailNotifier, RecapDetailState, String?>((recapId) {
  return RecapDetailNotifier(recapId);
});

final platformDistributionProvider = FutureProvider<Map<String, double>>((ref) async {
  final service = ref.watch(recapServiceProvider);
  return service.getPlatformIncomeDistribution();
});
