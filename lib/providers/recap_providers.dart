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
  final double saldoAwalGrabKredit;
  final double saldoAwalGrabTunai;
  final double saldoAwalGrabOvo;
  final double saldoAwalMandiri;
  final double saldoAwalBca;
  final double odoStart;
  final double odoEnd;
  final double fuelPricePerLiter;
  final double kmlParameter;
  final String status;
  final double saldoAkhirAppAktual;
  final double saldoAkhirGrabKreditAktual;
  final double saldoAkhirGrabTunaiAktual;
  final double saldoAkhirGrabOvoAktual;
  final double saldoAkhirMandiriAktual;
  final double saldoAkhirBcaAktual;
  final double tip;
  final double insentif;
  final String? tipWalletType;
  final String? insentifWalletType;
  final List<DailyOrder> orders;
  final List<PettyCashItem> pettyCash;
  final DailyRecap? summary;
  final bool isLoading;

  RecapDetailState({
    this.recapId,
    required this.tanggal,
    this.cashAwal = 0,
    this.saldoAwalApp = 0,
    this.saldoAwalGrabKredit = 0,
    this.saldoAwalGrabTunai = 0,
    this.saldoAwalGrabOvo = 0,
    this.saldoAwalMandiri = 0,
    this.saldoAwalBca = 0,
    this.odoStart = 0,
    this.odoEnd = 0,
    this.fuelPricePerLiter = 10000,
    this.kmlParameter = 45.5,
    this.status = 'open',
    this.saldoAkhirAppAktual = 0,
    this.saldoAkhirGrabKreditAktual = 0,
    this.saldoAkhirGrabTunaiAktual = 0,
    this.saldoAkhirGrabOvoAktual = 0,
    this.saldoAkhirMandiriAktual = 0,
    this.saldoAkhirBcaAktual = 0,
    this.tip = 0,
    this.insentif = 0,
    this.tipWalletType,
    this.insentifWalletType,
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
    double? saldoAwalGrabKredit,
    double? saldoAwalGrabTunai,
    double? saldoAwalGrabOvo,
    double? saldoAwalMandiri,
    double? saldoAwalBca,
    double? odoStart,
    double? odoEnd,
    double? fuelPricePerLiter,
    double? kmlParameter,
    String? status,
    double? saldoAkhirAppAktual,
    double? saldoAkhirGrabKreditAktual,
    double? saldoAkhirGrabTunaiAktual,
    double? saldoAkhirGrabOvoAktual,
    double? saldoAkhirMandiriAktual,
    double? saldoAkhirBcaAktual,
    double? tip,
    double? insentif,
    String? tipWalletType,
    String? insentifWalletType,
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
      saldoAwalGrabKredit: saldoAwalGrabKredit ?? this.saldoAwalGrabKredit,
      saldoAwalGrabTunai: saldoAwalGrabTunai ?? this.saldoAwalGrabTunai,
      saldoAwalGrabOvo: saldoAwalGrabOvo ?? this.saldoAwalGrabOvo,
      saldoAwalMandiri: saldoAwalMandiri ?? this.saldoAwalMandiri,
      saldoAwalBca: saldoAwalBca ?? this.saldoAwalBca,
      odoStart: odoStart ?? this.odoStart,
      odoEnd: odoEnd ?? this.odoEnd,
      fuelPricePerLiter: fuelPricePerLiter ?? this.fuelPricePerLiter,
      kmlParameter: kmlParameter ?? this.kmlParameter,
      status: status ?? this.status,
      saldoAkhirAppAktual: saldoAkhirAppAktual ?? this.saldoAkhirAppAktual,
      saldoAkhirGrabKreditAktual: saldoAkhirGrabKreditAktual ?? this.saldoAkhirGrabKreditAktual,
      saldoAkhirGrabTunaiAktual: saldoAkhirGrabTunaiAktual ?? this.saldoAkhirGrabTunaiAktual,
      saldoAkhirGrabOvoAktual: saldoAkhirGrabOvoAktual ?? this.saldoAkhirGrabOvoAktual,
      saldoAkhirMandiriAktual: saldoAkhirMandiriAktual ?? this.saldoAkhirMandiriAktual,
      saldoAkhirBcaAktual: saldoAkhirBcaAktual ?? this.saldoAkhirBcaAktual,
      tip: tip ?? this.tip,
      insentif: insentif ?? this.insentif,
      tipWalletType: tipWalletType ?? this.tipWalletType,
      insentifWalletType: insentifWalletType ?? this.insentifWalletType,
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
        saldoAwalGrabKredit: match.saldoAwalGrabKredit,
        saldoAwalGrabTunai: match.saldoAwalGrabTunai,
        saldoAwalGrabOvo: match.saldoAwalGrabOvo,
        saldoAwalMandiri: match.saldoAwalMandiri,
        saldoAwalBca: match.saldoAwalBca,
        odoStart: match.odoStart,
        odoEnd: match.odoEnd,
        fuelPricePerLiter: match.fuelPricePerLiter,
        kmlParameter: match.kmlParameter,
        status: match.status,
        saldoAkhirAppAktual: match.saldoAkhirAppAktual,
        saldoAkhirGrabKreditAktual: match.saldoAkhirGrabKreditAktual,
        saldoAkhirGrabTunaiAktual: match.saldoAkhirGrabTunaiAktual,
        saldoAkhirGrabOvoAktual: match.saldoAkhirGrabOvoAktual,
        saldoAkhirMandiriAktual: match.saldoAkhirMandiriAktual,
        saldoAkhirBcaAktual: match.saldoAkhirBcaAktual,
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
          saldoAwalGrabKredit: todayRecap.saldoAwalGrabKredit,
          saldoAwalGrabTunai: todayRecap.saldoAwalGrabTunai,
          saldoAwalGrabOvo: todayRecap.saldoAwalGrabOvo,
          saldoAwalMandiri: todayRecap.saldoAwalMandiri,
          saldoAwalBca: todayRecap.saldoAwalBca,
          odoStart: todayRecap.odoStart,
          odoEnd: todayRecap.odoEnd,
          fuelPricePerLiter: todayRecap.fuelPricePerLiter,
          kmlParameter: todayRecap.kmlParameter,
          status: todayRecap.status,
          saldoAkhirAppAktual: todayRecap.saldoAkhirAppAktual,
          saldoAkhirGrabKreditAktual: todayRecap.saldoAkhirGrabKreditAktual,
          saldoAkhirGrabTunaiAktual: todayRecap.saldoAkhirGrabTunaiAktual,
          saldoAkhirGrabOvoAktual: todayRecap.saldoAkhirGrabOvoAktual,
          saldoAkhirMandiriAktual: todayRecap.saldoAkhirMandiriAktual,
          saldoAkhirBcaAktual: todayRecap.saldoAkhirBcaAktual,
          tip: todayRecap.tip,
          insentif: todayRecap.insentif,
          tipWalletType: todayRecap.tipWalletType,
          insentifWalletType: todayRecap.insentifWalletType,
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
    required double saldoAwalGrabKredit,
    required double saldoAwalGrabTunai,
    required double saldoAwalGrabOvo,
    required double saldoAwalMandiri,
    required double saldoAwalBca,
    required double odoStart,
    required double odoEnd,
    required double fuelPricePerLiter,
    required double kmlParameter,
    required double tip,
    required double insentif,
    String? tipWalletType,
    String? insentifWalletType,
  }) async {
    String? id = state.recapId;
    if (id == null) {
      id = await _service.createRecap(
        tanggal: state.tanggal,
        cashAwal: cashAwal,
        saldoAwalApp: saldoAwalApp,
        saldoAwalGrabKredit: saldoAwalGrabKredit,
        saldoAwalGrabTunai: saldoAwalGrabTunai,
        saldoAwalGrabOvo: saldoAwalGrabOvo,
        saldoAwalMandiri: saldoAwalMandiri,
        saldoAwalBca: saldoAwalBca,
        odoStart: odoStart,
        odoEnd: odoEnd,
        fuelPricePerLiter: fuelPricePerLiter,
        kmlParameter: kmlParameter,
        status: state.status,
        saldoAkhirAppAktual: state.saldoAkhirAppAktual,
        saldoAkhirGrabKreditAktual: state.saldoAkhirGrabKreditAktual,
        saldoAkhirGrabTunaiAktual: state.saldoAkhirGrabTunaiAktual,
        saldoAkhirGrabOvoAktual: state.saldoAkhirGrabOvoAktual,
        saldoAkhirMandiriAktual: state.saldoAkhirMandiriAktual,
        saldoAkhirBcaAktual: state.saldoAkhirBcaAktual,
      );
      state = state.copyWith(recapId: id);
    } else {
      await _service.updateRecapHeader(
        id: id,
        cashAwal: cashAwal,
        saldoAwalApp: saldoAwalApp,
        saldoAwalGrabKredit: saldoAwalGrabKredit,
        saldoAwalGrabTunai: saldoAwalGrabTunai,
        saldoAwalGrabOvo: saldoAwalGrabOvo,
        saldoAwalMandiri: saldoAwalMandiri,
        saldoAwalBca: saldoAwalBca,
        odoStart: odoStart,
        odoEnd: odoEnd,
        fuelPricePerLiter: fuelPricePerLiter,
        kmlParameter: kmlParameter,
        status: state.status,
        saldoAkhirAppAktual: state.saldoAkhirAppAktual,
        saldoAkhirGrabKreditAktual: state.saldoAkhirGrabKreditAktual,
        saldoAkhirGrabTunaiAktual: state.saldoAkhirGrabTunaiAktual,
        saldoAkhirGrabOvoAktual: state.saldoAkhirGrabOvoAktual,
        saldoAkhirMandiriAktual: state.saldoAkhirMandiriAktual,
        saldoAkhirBcaAktual: state.saldoAkhirBcaAktual,
      );
    }
    await _service.saveExtra(
      id,
      tip: tip,
      insentif: insentif,
      tipWalletType: tipWalletType,
      insentifWalletType: insentifWalletType,
    );
    await refreshSummary();
    ref.invalidate(recapsProvider);
  }

  Future<void> closeRecap({
    required double actualSf,
    required double actualGrabKredit,
    required double actualGrabTunai,
    required double actualGrabOvo,
    required double actualMandiri,
    required double actualBca,
  }) async {
    final id = state.recapId;
    if (id == null) return;
    
    await _service.updateRecapHeader(
      id: id,
      cashAwal: state.cashAwal,
      saldoAwalApp: state.saldoAwalApp,
      saldoAwalGrabKredit: state.saldoAwalGrabKredit,
      saldoAwalGrabTunai: state.saldoAwalGrabTunai,
      saldoAwalGrabOvo: state.saldoAwalGrabOvo,
      saldoAwalMandiri: state.saldoAwalMandiri,
      saldoAwalBca: state.saldoAwalBca,
      odoStart: state.odoStart,
      odoEnd: state.odoEnd,
      fuelPricePerLiter: state.fuelPricePerLiter,
      kmlParameter: state.kmlParameter,
      status: 'closed',
      saldoAkhirAppAktual: actualSf,
      saldoAkhirGrabKreditAktual: actualGrabKredit,
      saldoAkhirGrabTunaiAktual: actualGrabTunai,
      saldoAkhirGrabOvoAktual: actualGrabOvo,
      saldoAkhirMandiriAktual: actualMandiri,
      saldoAkhirBcaAktual: actualBca,
    );

    state = state.copyWith(
      status: 'closed',
      saldoAkhirAppAktual: actualSf,
      saldoAkhirGrabKreditAktual: actualGrabKredit,
      saldoAkhirGrabTunaiAktual: actualGrabTunai,
      saldoAkhirGrabOvoAktual: actualGrabOvo,
      saldoAkhirMandiriAktual: actualMandiri,
      saldoAkhirBcaAktual: actualBca,
    );
    await refreshSummary();
    ref.invalidate(recapsProvider);
  }

  Future<void> reopenRecap() async {
    final id = state.recapId;
    if (id == null) return;
    
    await _service.updateRecapHeader(
      id: id,
      cashAwal: state.cashAwal,
      saldoAwalApp: state.saldoAwalApp,
      saldoAwalGrabKredit: state.saldoAwalGrabKredit,
      saldoAwalGrabTunai: state.saldoAwalGrabTunai,
      saldoAwalGrabOvo: state.saldoAwalGrabOvo,
      saldoAwalMandiri: state.saldoAwalMandiri,
      saldoAwalBca: state.saldoAwalBca,
      odoStart: state.odoStart,
      odoEnd: state.odoEnd,
      fuelPricePerLiter: state.fuelPricePerLiter,
      kmlParameter: state.kmlParameter,
      status: 'open',
      saldoAkhirAppAktual: state.saldoAkhirAppAktual,
      saldoAkhirGrabKreditAktual: state.saldoAkhirGrabKreditAktual,
      saldoAkhirGrabTunaiAktual: state.saldoAkhirGrabTunaiAktual,
      saldoAkhirGrabOvoAktual: state.saldoAkhirGrabOvoAktual,
      saldoAkhirMandiriAktual: state.saldoAkhirMandiriAktual,
      saldoAkhirBcaAktual: state.saldoAkhirBcaAktual,
    );

    state = state.copyWith(status: 'open');
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
    final matchRecap = match.isNotEmpty ? match.first : state.summary;
    state = state.copyWith(
      summary: matchRecap,
      orders: orders,
      pettyCash: petty,
      tipWalletType: matchRecap?.tipWalletType ?? state.tipWalletType,
      insentifWalletType: matchRecap?.insentifWalletType ?? state.insentifWalletType,
    );
    ref.invalidate(recapsProvider);
  }

  Future<void> upsertOrder(DailyOrder order) async {
    await _service.upsertOrder(order);
    
    final id = state.recapId;
    if (id != null) {
      final orders = await _service.getOrders(id);
      double maxOdo = state.odoStart;
      for (final o in orders) {
        if (o.odometer != null && o.odometer! > maxOdo) {
          maxOdo = o.odometer!;
        }
      }

      bool shouldUpdate = false;
      if (maxOdo > state.odoEnd) {
        shouldUpdate = true;
      } else if (order.id != null) {
        final previousOrder = state.orders.firstWhere((o) => o.id == order.id, orElse: () => order);
        if (previousOrder.odometer == state.odoEnd && maxOdo < state.odoEnd) {
          shouldUpdate = true;
        }
      }

      if (shouldUpdate) {
        await _service.updateRecapHeader(
          id: id,
          cashAwal: state.cashAwal,
          saldoAwalApp: state.saldoAwalApp,
          saldoAwalGrabKredit: state.saldoAwalGrabKredit,
          saldoAwalGrabTunai: state.saldoAwalGrabTunai,
          saldoAwalGrabOvo: state.saldoAwalGrabOvo,
          saldoAwalMandiri: state.saldoAwalMandiri,
          saldoAwalBca: state.saldoAwalBca,
          odoStart: state.odoStart,
          odoEnd: maxOdo,
          fuelPricePerLiter: state.fuelPricePerLiter,
          kmlParameter: state.kmlParameter,
          status: state.status,
          saldoAkhirAppAktual: state.saldoAkhirAppAktual,
          saldoAkhirGrabKreditAktual: state.saldoAkhirGrabKreditAktual,
          saldoAkhirGrabTunaiAktual: state.saldoAkhirGrabTunaiAktual,
          saldoAkhirGrabOvoAktual: state.saldoAkhirGrabOvoAktual,
          saldoAkhirMandiriAktual: state.saldoAkhirMandiriAktual,
          saldoAkhirBcaAktual: state.saldoAkhirBcaAktual,
        );
        state = state.copyWith(odoEnd: maxOdo);
      }
    }

    await refreshSummary();
  }

  Future<void> deleteOrder(DailyOrder o) async {
    if (o.id == null) return;
    await _service.deleteOrder(o.id!);
    
    final id = state.recapId;
    if (id != null) {
      final orders = await _service.getOrders(id);
      double maxOdo = state.odoStart;
      for (final order in orders) {
        if (order.odometer != null && order.odometer! > maxOdo) {
          maxOdo = order.odometer!;
        }
      }

      if (o.odometer == state.odoEnd && maxOdo < state.odoEnd) {
        await _service.updateRecapHeader(
          id: id,
          cashAwal: state.cashAwal,
          saldoAwalApp: state.saldoAwalApp,
          saldoAwalGrabKredit: state.saldoAwalGrabKredit,
          saldoAwalGrabTunai: state.saldoAwalGrabTunai,
          saldoAwalGrabOvo: state.saldoAwalGrabOvo,
          saldoAwalMandiri: state.saldoAwalMandiri,
          saldoAwalBca: state.saldoAwalBca,
          odoStart: state.odoStart,
          odoEnd: maxOdo,
          fuelPricePerLiter: state.fuelPricePerLiter,
          kmlParameter: state.kmlParameter,
          status: state.status,
          saldoAkhirAppAktual: state.saldoAkhirAppAktual,
          saldoAkhirGrabKreditAktual: state.saldoAkhirGrabKreditAktual,
          saldoAkhirGrabTunaiAktual: state.saldoAkhirGrabTunaiAktual,
          saldoAkhirGrabOvoAktual: state.saldoAkhirGrabOvoAktual,
          saldoAkhirMandiriAktual: state.saldoAkhirMandiriAktual,
          saldoAkhirBcaAktual: state.saldoAkhirBcaAktual,
        );
        state = state.copyWith(odoEnd: maxOdo);
      }
    }

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

class HomeTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void change(int val) => state = val;
}
final homeTabProvider = NotifierProvider<HomeTabNotifier, int>(HomeTabNotifier.new);

class ReportTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void change(int val) => state = val;
}
final reportTabProvider = NotifierProvider<ReportTabNotifier, int>(ReportTabNotifier.new);

class SelectedAccountNotifier extends Notifier<String> {
  @override
  String build() => 'cash';
  void change(String val) => state = val;
}
final selectedAccountProvider = NotifierProvider<SelectedAccountNotifier, String>(SelectedAccountNotifier.new);

class SyncLogsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => ['Aplikasi diinisialisasi.'];
  void addLog(String log) => state = [...state, log];
}
final syncLogsProvider = NotifierProvider<SyncLogsNotifier, List<String>>(SyncLogsNotifier.new);
