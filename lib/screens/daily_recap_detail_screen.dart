import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_recap.dart';
import '../models/daily_order.dart';
import '../models/petty_cash_item.dart';
import '../providers/recap_providers.dart';
import 'home_screen.dart' show currency, dateFmt;
import 'order_form_sheet.dart';

/// recapId == null -> membuat rekap baru untuk hari ini.
class DailyRecapDetailScreen extends ConsumerStatefulWidget {
  final String? recapId;
  const DailyRecapDetailScreen({super.key, required this.recapId});

  @override
  ConsumerState<DailyRecapDetailScreen> createState() => _DailyRecapDetailScreenState();
}

class _DailyRecapDetailScreenState extends ConsumerState<DailyRecapDetailScreen> {
  final _cashAwalCtrl = TextEditingController(text: '0');
  final _saldoAwalAppCtrl = TextEditingController(text: '0');
  final _tipCtrl = TextEditingController(text: '0');
  final _insentifCtrl = TextEditingController(text: '0');

  List<PettyCashItem> _localPettyCash = [];
  bool _initialized = false;

  @override
  void dispose() {
    _cashAwalCtrl.dispose();
    _saldoAwalAppCtrl.dispose();
    _tipCtrl.dispose();
    _insentifCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveHeader() async {
    final cashAwal = double.tryParse(_cashAwalCtrl.text) ?? 0;
    final saldoAwalApp = double.tryParse(_saldoAwalAppCtrl.text) ?? 0;
    final tip = double.tryParse(_tipCtrl.text) ?? 0;
    final insentif = double.tryParse(_insentifCtrl.text) ?? 0;

    await ref.read(recapDetailNotifierProvider(widget.recapId).notifier).saveHeader(
          cashAwal: cashAwal,
          saldoAwalApp: saldoAwalApp,
          tip: tip,
          insentif: insentif,
        );
  }

  Future<void> _addOrEditOrder([DailyOrder? existing]) async {
    final state = ref.read(recapDetailNotifierProvider(widget.recapId));
    var activeId = state.recapId;
    if (activeId == null) {
      await _saveHeader(); // pastikan header sudah tersimpan dulu
      activeId = ref.read(recapDetailNotifierProvider(widget.recapId)).recapId;
    }
    if (activeId == null) return;
    if (!mounted) return;

    final result = await showModalBottomSheet<DailyOrder>(
      context: context,
      isScrollControlled: true,
      builder: (_) => OrderFormSheet(
        dailyRecapId: activeId!,
        existing: existing,
        nextUrutan: state.orders.length + 1,
      ),
    );
    if (result != null) {
      await ref.read(recapDetailNotifierProvider(widget.recapId).notifier).upsertOrder(result);
    }
  }

  Future<void> _deleteOrder(DailyOrder o) async {
    if (o.id == null) return;
    await ref.read(recapDetailNotifierProvider(widget.recapId).notifier).deleteOrder(o);
  }

  Future<void> _savePettyCash() async {
    var activeId = ref.read(recapDetailNotifierProvider(widget.recapId)).recapId;
    if (activeId == null) {
      await _saveHeader();
      activeId = ref.read(recapDetailNotifierProvider(widget.recapId)).recapId;
    }
    if (activeId == null) return;

    await ref.read(recapDetailNotifierProvider(widget.recapId).notifier).savePettyCash(_localPettyCash);
    
    // Sinkronkan kembali dengan data terbaru setelah save
    final updatedState = ref.read(recapDetailNotifierProvider(widget.recapId));
    setState(() {
      _localPettyCash = List<PettyCashItem>.from(updatedState.pettyCash);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recapDetailNotifierProvider(widget.recapId));

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Inisialisasi controller dan local petty cash setelah data selesai loading
    if (!_initialized) {
      _cashAwalCtrl.text = state.cashAwal.toStringAsFixed(0);
      _saldoAwalAppCtrl.text = state.saldoAwalApp.toStringAsFixed(0);
      _tipCtrl.text = state.tip.toStringAsFixed(0);
      _insentifCtrl.text = state.insentif.toStringAsFixed(0);
      _localPettyCash = List<PettyCashItem>.from(state.pettyCash);
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(dateFmt.format(state.tanggal)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Simpan',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await _saveHeader();
              messenger.showSnackBar(
                const SnackBar(content: Text('Tersimpan')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Saldo Awal'),
          Row(
            children: [
              Expanded(
                child: _numField('Cash Awal', _cashAwalCtrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numField('Saldo Awal App', _saldoAwalAppCtrl),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _sectionTitle('Daftar Transaksi (Order, Pengeluaran, Top Up)'),
          ...state.orders.map((o) => _orderTile(o)),
          OutlinedButton.icon(
            onPressed: () => _addOrEditOrder(),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Transaksi (Order/Lainnya)'),
          ),
          const SizedBox(height: 20),

          _sectionTitle('Tip & Insentif'),
          Row(
            children: [
              Expanded(child: _numField('Tip', _tipCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _numField('Insentif', _insentifCtrl)),
            ],
          ),
          const SizedBox(height: 20),

          _sectionTitle('Petty Cash (Breakdown Uang Tunai)'),
          ..._localPettyCash.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 90, child: Text(currency.format(item.denom))),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('${item.denom}_$i'),
                      initialValue: item.qty.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                      onChanged: (v) {
                        final qty = int.tryParse(v) ?? 0;
                        setState(() {
                          _localPettyCash[i] = item.copyWith(qty: qty);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: Text(
                      currency.format(item.subtotal),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _savePettyCash,
              icon: const Icon(Icons.check),
              label: const Text('Simpan Petty Cash'),
            ),
          ),
          const SizedBox(height: 20),

          if (state.summary != null) _summaryCard(state.summary!),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _numField(String label, TextEditingController ctrl) => TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );

  Widget _orderTile(DailyOrder o) {
    String title = 'Transaksi ${o.urutan}';
    if (o.platform != null && o.platform!.isNotEmpty) {
      title = '${o.platform} (Order ${o.urutan})';
    } else if (o.keterangan != null && o.keterangan!.isNotEmpty) {
      title = o.keterangan!;
    } else if (o.income > 0) {
      title = 'Order ${o.urutan}';
    } else if (o.expense > 0) {
      title = 'Pengeluaran ${o.urutan}';
    } else if (o.saldoTopUp > 0) {
      title = 'Top Up ${o.urutan}';
    }

    final subtitleParts = [
      if (o.income > 0) 'Income: ${currency.format(o.income)}',
      if (o.expense > 0) 'Expense: ${currency.format(o.expense)}',
      if (o.saldoTopUp > 0) 'Top Up: ${currency.format(o.saldoTopUp)}',
      if (o.deductCashApp > 0) 'Deduct Cash: ${currency.format(o.deductCashApp)}',
      if (o.custPay > 0) 'Cust Pay: ${currency.format(o.custPay)}',
      if (o.custChange > 0) 'Cust Change: ${currency.format(o.custChange)}',
    ];

    final subtitle = subtitleParts.isNotEmpty 
        ? subtitleParts.join('  ·  ') 
        : 'Tidak ada nominal';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtitle + (o.remark != null && o.remark!.isNotEmpty ? '\n${o.remark}' : ''),
        ),
        isThreeLine: o.remark != null && o.remark!.isNotEmpty,
        onTap: () => _addOrEditOrder(o),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _deleteOrder(o),
        ),
      ),
    );
  }

  Widget _summaryCard(DailyRecap s) {
    final positif = s.netEarning >= 0;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ringkasan Otomatis', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _summaryRow('Cash Akhir', s.cashAkhir),
            _summaryRow('Saldo Akhir App', s.saldoAkhirApp),
            _summaryRow('Total Income', s.totalIncome),
            _summaryRow('Total Expense', s.totalExpense),
            _summaryRow('Petty Cash (Grand Total)', s.pettyCashTotal),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net Earning', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  (positif ? '+' : '') + currency.format(s.netEarning),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: positif ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(currency.format(value))],
        ),
      );
}
