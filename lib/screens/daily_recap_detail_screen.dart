import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_recap.dart';
import '../models/daily_order.dart';
import '../models/petty_cash_item.dart';
import '../models/saldo_mutation.dart';
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
  final _saldoAwalGrabKreditCtrl = TextEditingController(text: '0');
  final _saldoAwalGrabTunaiCtrl = TextEditingController(text: '0');
  final _saldoAwalGrabOvoCtrl = TextEditingController(text: '0');
  final _saldoAwalMandiriCtrl = TextEditingController(text: '0');
  final _saldoAwalBcaCtrl = TextEditingController(text: '0');
  final _odoStartCtrl = TextEditingController(text: '0');
  final _odoEndCtrl = TextEditingController(text: '0');
  final _fuelPriceCtrl = TextEditingController(text: '10000');
  final _kmlParamCtrl = TextEditingController(text: '45.5');
  final _actualAppBalanceCtrl = TextEditingController(text: '0');
  final _actualGrabKreditCtrl = TextEditingController(text: '0');
  final _actualGrabTunaiCtrl = TextEditingController(text: '0');
  final _actualGrabOvoCtrl = TextEditingController(text: '0');
  final _actualMandiriCtrl = TextEditingController(text: '0');
  final _actualBcaCtrl = TextEditingController(text: '0');
  final _tipCtrl = TextEditingController(text: '0');
  final _insentifCtrl = TextEditingController(text: '0');

  List<PettyCashItem> _localPettyCash = [];
  bool _initialized = false;
  int _selectedSection = 0;

  @override
  void dispose() {
    _cashAwalCtrl.dispose();
    _saldoAwalAppCtrl.dispose();
    _saldoAwalGrabKreditCtrl.dispose();
    _saldoAwalGrabTunaiCtrl.dispose();
    _saldoAwalGrabOvoCtrl.dispose();
    _saldoAwalMandiriCtrl.dispose();
    _saldoAwalBcaCtrl.dispose();
    _odoStartCtrl.dispose();
    _odoEndCtrl.dispose();
    _fuelPriceCtrl.dispose();
    _kmlParamCtrl.dispose();
    _actualAppBalanceCtrl.dispose();
    _actualGrabKreditCtrl.dispose();
    _actualGrabTunaiCtrl.dispose();
    _actualGrabOvoCtrl.dispose();
    _actualMandiriCtrl.dispose();
    _actualBcaCtrl.dispose();
    _tipCtrl.dispose();
    _insentifCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveHeader() async {
    final cashAwal = double.tryParse(_cashAwalCtrl.text) ?? 0;
    final saldoAwalApp = double.tryParse(_saldoAwalAppCtrl.text) ?? 0;
    final saldoAwalGrabKredit = double.tryParse(_saldoAwalGrabKreditCtrl.text) ?? 0;
    final saldoAwalGrabTunai = double.tryParse(_saldoAwalGrabTunaiCtrl.text) ?? 0;
    final saldoAwalGrabOvo = double.tryParse(_saldoAwalGrabOvoCtrl.text) ?? 0;
    final saldoAwalMandiri = double.tryParse(_saldoAwalMandiriCtrl.text) ?? 0;
    final saldoAwalBca = double.tryParse(_saldoAwalBcaCtrl.text) ?? 0;
    final odoStart = double.tryParse(_odoStartCtrl.text) ?? 0;
    final odoEnd = double.tryParse(_odoEndCtrl.text) ?? 0;
    final fuelPrice = double.tryParse(_fuelPriceCtrl.text) ?? 10000;
    final kmlParam = double.tryParse(_kmlParamCtrl.text) ?? 45.5;
    final tip = double.tryParse(_tipCtrl.text) ?? 0;
    final insentif = double.tryParse(_insentifCtrl.text) ?? 0;

    await ref.read(recapDetailNotifierProvider(widget.recapId).notifier).saveHeader(
          cashAwal: cashAwal,
          saldoAwalApp: saldoAwalApp,
          saldoAwalGrabKredit: saldoAwalGrabKredit,
          saldoAwalGrabTunai: saldoAwalGrabTunai,
          saldoAwalGrabOvo: saldoAwalGrabOvo,
          saldoAwalMandiri: saldoAwalMandiri,
          saldoAwalBca: saldoAwalBca,
          odoStart: odoStart,
          odoEnd: odoEnd,
          fuelPricePerLiter: fuelPrice,
          kmlParameter: kmlParam,
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
        isClosed: state.status == 'closed',
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
      _saldoAwalGrabKreditCtrl.text = state.saldoAwalGrabKredit.toStringAsFixed(0);
      _saldoAwalGrabTunaiCtrl.text = state.saldoAwalGrabTunai.toStringAsFixed(0);
      _saldoAwalGrabOvoCtrl.text = state.saldoAwalGrabOvo.toStringAsFixed(0);
      _saldoAwalMandiriCtrl.text = state.saldoAwalMandiri.toStringAsFixed(0);
      _saldoAwalBcaCtrl.text = state.saldoAwalBca.toStringAsFixed(0);
      _odoStartCtrl.text = state.odoStart.toStringAsFixed(0);
      _odoEndCtrl.text = state.odoEnd.toStringAsFixed(0);
      _fuelPriceCtrl.text = state.fuelPricePerLiter.toStringAsFixed(0);
      _kmlParamCtrl.text = state.kmlParameter.toStringAsFixed(1);
      _actualAppBalanceCtrl.text = state.saldoAkhirAppAktual.toStringAsFixed(0);
      _actualGrabKreditCtrl.text = state.saldoAkhirGrabKreditAktual.toStringAsFixed(0);
      _actualGrabTunaiCtrl.text = state.saldoAkhirGrabTunaiAktual.toStringAsFixed(0);
      _actualGrabOvoCtrl.text = state.saldoAkhirGrabOvoAktual.toStringAsFixed(0);
      _actualMandiriCtrl.text = state.saldoAkhirMandiriAktual.toStringAsFixed(0);
      _actualBcaCtrl.text = state.saldoAkhirBcaAktual.toStringAsFixed(0);
      _tipCtrl.text = state.tip.toStringAsFixed(0);
      _insentifCtrl.text = state.insentif.toStringAsFixed(0);
      _localPettyCash = List<PettyCashItem>.from(state.pettyCash);
      _initialized = true;
    }

    final isClosed = state.status == 'closed';
    final hasChanges = !_initialized ? false : (
      (double.tryParse(_cashAwalCtrl.text) ?? 0) != state.cashAwal ||
      (double.tryParse(_saldoAwalAppCtrl.text) ?? 0) != state.saldoAwalApp ||
      (double.tryParse(_saldoAwalGrabKreditCtrl.text) ?? 0) != state.saldoAwalGrabKredit ||
      (double.tryParse(_saldoAwalGrabTunaiCtrl.text) ?? 0) != state.saldoAwalGrabTunai ||
      (double.tryParse(_saldoAwalGrabOvoCtrl.text) ?? 0) != state.saldoAwalGrabOvo ||
      (double.tryParse(_saldoAwalMandiriCtrl.text) ?? 0) != state.saldoAwalMandiri ||
      (double.tryParse(_saldoAwalBcaCtrl.text) ?? 0) != state.saldoAwalBca ||
      (double.tryParse(_odoStartCtrl.text) ?? 0) != state.odoStart ||
      (double.tryParse(_odoEndCtrl.text) ?? 0) != state.odoEnd ||
      (double.tryParse(_fuelPriceCtrl.text) ?? 0) != state.fuelPricePerLiter ||
      (double.tryParse(_kmlParamCtrl.text) ?? 0) != state.kmlParameter ||
      (double.tryParse(_tipCtrl.text) ?? 0) != state.tip ||
      (double.tryParse(_insentifCtrl.text) ?? 0) != state.insentif
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 750;

        final appBarWidget = AppBar(
          leading: const BackButton(),
          title: Row(
            children: [
              Text(dateFmt.format(state.tanggal)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isClosed ? Colors.red.shade900 : Colors.green.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isClosed ? 'TERKUNCI' : 'AKTIF',
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          actions: [
            if (widget.recapId != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: 'Hapus Rekap Harian',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Hapus Rekap'),
                      content: const Text('Apakah Anda yakin ingin menghapus rekap harian ini beserta seluruh transaksinya? Tindakan ini tidak bisa dibatalkan.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final messenger = ScaffoldMessenger.of(context);
                    await ref.read(recapServiceProvider).deleteRecap(widget.recapId!);
                    ref.invalidate(recapsProvider);
                    ref.invalidate(platformDistributionProvider);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Rekap berhasil dihapus')),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
              ),
            if (hasChanges)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Center(
                  child: Text(
                    'Belum Disimpan',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: Icon(
                Icons.save,
                color: hasChanges ? Colors.orange : null,
              ),
              tooltip: hasChanges ? 'Simpan Perubahan' : 'Simpan',
              onPressed: isClosed
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await _saveHeader();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Tersimpan')),
                      );
                    },
            ),
          ],
        );

        return Scaffold(
          appBar: appBarWidget,
          body: isDesktop
              ? Row(
                  children: [
                    Container(
                      width: 250,
                      color: Colors.white,
                      child: _buildSidebarMenu(context, false),
                    ),
                    const VerticalDivider(width: 1, thickness: 1, color: Colors.black12),
                    Expanded(
                      child: _buildSectionContent(state, isClosed),
                    ),
                  ],
                )
              : _buildSectionContent(state, isClosed),
          bottomNavigationBar: isDesktop ? null : BottomNavigationBar(
            currentIndex: _selectedSection,
            onTap: (index) {
              setState(() {
                _selectedSection = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.tune_outlined),
                label: 'Setup Awal',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                label: 'Transaksi',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.fact_check_outlined),
                label: 'Closing',
              ),
            ],
            selectedItemColor: const Color(0xFF2E7D32),
          ),
        );
      },
    );
  }

  Widget _buildSidebarMenu(BuildContext context, bool isDrawer) {
    final menuItems = [
      {'label': 'Setup Awal & Telemetri', 'icon': Icons.tune_outlined},
      {'label': 'Transaksi & Pendapatan', 'icon': Icons.receipt_long_outlined},
      {'label': 'Closing & Rekonsiliasi', 'icon': Icons.fact_check_outlined},
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (isDrawer)
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF2E7D32)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Rekap Harian',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Menu Navigasi Seksi',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.grey.shade100,
            child: const Text(
              'MENU REKAP',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 1),
            ),
          ),
        for (int i = 0; i < menuItems.length; i++)
          ListTile(
            leading: Icon(
              menuItems[i]['icon'] as IconData,
              color: _selectedSection == i ? const Color(0xFF2E7D32) : Colors.black54,
            ),
            title: Text(
              menuItems[i]['label'] as String,
              style: TextStyle(
                fontWeight: _selectedSection == i ? FontWeight.bold : FontWeight.normal,
                color: _selectedSection == i ? const Color(0xFF2E7D32) : Colors.black87,
              ),
            ),
            selected: _selectedSection == i,
            selectedColor: const Color(0xFF2E7D32).withOpacity(0.08),
            onTap: () {
              setState(() {
                _selectedSection = i;
              });
              if (isDrawer) {
                Navigator.pop(context);
              }
            },
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.arrow_back),
          title: const Text('Kembali ke Dashboard'),
          onTap: () {
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildSectionContent(RecapDetailState state, bool isClosed) {
    switch (_selectedSection) {
      case 0:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('Saldo Awal'),
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _numField('Cash Awal', _cashAwalCtrl, enabled: !isClosed),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _numField('ShopeeFood Awal', _saldoAwalAppCtrl, enabled: !isClosed),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _numField('Grab Kredit Awal', _saldoAwalGrabKreditCtrl, enabled: !isClosed),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _numField('Grab Tunai Awal', _saldoAwalGrabTunaiCtrl, enabled: !isClosed),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _numField('Grab OVO Awal', _saldoAwalGrabOvoCtrl, enabled: !isClosed),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _numField('Mandiri Awal', _saldoAwalMandiriCtrl, enabled: !isClosed),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _numField('BCA Awal', _saldoAwalBcaCtrl, enabled: !isClosed),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _sectionTitle('Telemetri & BBM'),
            Row(
              children: [
                Expanded(
                  child: _numField('Odometer Awal (KM)', _odoStartCtrl, enabled: !isClosed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numField('Odometer Akhir (KM)', _odoEndCtrl, enabled: !isClosed),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _numField('Harga BBM / L (Rp)', _fuelPriceCtrl, enabled: !isClosed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numField('Konsumsi (KM/L)', _kmlParamCtrl, enabled: !isClosed),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '© 2026 D\'Azhars Studio',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blueGrey.shade300,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
      case 1:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('Tip & Insentif Harian'),
            Card(
              margin: const EdgeInsets.only(bottom: 20),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: _numField('Tip', _tipCtrl, enabled: !isClosed)),
                    const SizedBox(width: 12),
                    Expanded(child: _numField('Insentif', _insentifCtrl, enabled: !isClosed)),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _sectionTitle('Daftar Transaksi (Order, Pengeluaran, Top Up)'),
                ),
                if (!isClosed)
                  ElevatedButton.icon(
                    onPressed: () => _addOrEditOrder(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.orders.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'Belum ada transaksi dimasukkan untuk hari ini.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...state.orders.map((o) => _orderTile(o, isClosed)),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '© 2026 D\'Azhars Studio',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blueGrey.shade300,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
      case 2:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('Petty Cash (Pecahan Kas Fisik)'),
            Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
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
                                enabled: !isClosed,
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
                        onPressed: isClosed ? null : _savePettyCash,
                        icon: const Icon(Icons.check),
                        label: const Text('Simpan Petty Cash'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (state.summary != null) ...[
              _summaryCard(state.summary!),
              const SizedBox(height: 16),
              _buildVehicleStats(state.summary!),
              const SizedBox(height: 16),
              _buildReconciliationCard(state),
            ],
            const SizedBox(height: 24),
            Center(
              child: Text(
                '© 2026 D\'Azhars Studio',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blueGrey.shade300,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _numField(String label, TextEditingController ctrl, {bool enabled = true}) => TextFormField(
        controller: ctrl,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) {
          setState(() {});
        },
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );

  Widget _orderTile(DailyOrder o, bool isClosed) {
    String title = 'Transaksi ${o.urutan}';
    if (o.platform != null && o.platform!.isNotEmpty) {
      String walletLabel = '';
      if (o.platform == 'Grab') {
        if (o.walletType == 'grab_kredit') walletLabel = ' (Kredit)';
        if (o.walletType == 'grab_tunai') walletLabel = ' (Tunai)';
        if (o.walletType == 'grab_ovo') walletLabel = ' (OVO)';
      }
      title = '${o.platform}$walletLabel (Order ${o.urutan})';
    } else if (o.keterangan != null && o.keterangan!.isNotEmpty) {
      title = o.keterangan!;
    } else if (o.income > 0) {
      title = 'Order ${o.urutan}';
    } else if (o.expense > 0) {
      title = 'Pengeluaran ${o.urutan}';
    } else if (o.saldoTopUp > 0) {
      String target = 'Aplikasi';
      if (o.walletType == 'shopeefood') target = 'ShopeeFood';
      if (o.walletType == 'grab_kredit') target = 'Grab Kredit';
      if (o.walletType == 'grab_tunai') target = 'Grab Tunai';
      if (o.walletType == 'grab_ovo') target = 'Grab OVO';
      if (o.walletType == 'mandiri') target = 'Mandiri';
      if (o.walletType == 'bca') target = 'BCA';

      String source = 'Tunai';
      if (o.topupSource == 'mandiri') source = 'Mandiri';
      if (o.topupSource == 'bca') source = 'BCA';

      title = 'Top Up $target ($source)';
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
        trailing: isClosed
            ? null
            : IconButton(
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
            _summaryRow('Cash Akhir (Buku)', s.cashAkhir, walletType: 'cash', recap: s),
            _summaryRow('Saldo ShopeeFood (Buku)', s.saldoAkhirApp, walletType: 'shopeefood', recap: s),
            _summaryRow('Saldo Grab Kredit (Buku)', s.saldoAkhirGrabKredit, walletType: 'grab_kredit', recap: s),
            _summaryRow('Saldo Grab Tunai (Buku)', s.saldoAkhirGrabTunai, walletType: 'grab_tunai', recap: s),
            _summaryRow('Saldo Grab OVO (Buku)', s.saldoAkhirGrabOvo, walletType: 'grab_ovo', recap: s),
            _summaryRow('Saldo Mandiri (Buku)', s.saldoAkhirMandiri, walletType: 'mandiri', recap: s),
            _summaryRow('Saldo BCA (Buku)', s.saldoAkhirBca, walletType: 'bca', recap: s),
            const Divider(),
            _summaryRow('Total Income', s.totalIncome),
            _summaryRow('Total Expense', s.totalExpense),
            _summaryRow('Petty Cash (Tunai Aktual)', s.pettyCashTotal),
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

  Widget _summaryRow(String label, double value, {String? walletType, DailyRecap? recap}) {
    final isClickable = walletType != null && recap != null;
    return InkWell(
      onTap: isClickable ? () => _showWalletMutationDialog(label, walletType, recap) : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(label),
                if (isClickable) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.info_outline, size: 14, color: Colors.blueGrey.shade400),
                ],
              ],
            ),
            Text(
              currency.format(value),
              style: TextStyle(
                fontWeight: isClickable ? FontWeight.w600 : FontWeight.normal,
                color: isClickable ? const Color(0xFF2E7D32) : null,
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showWalletMutationDialog(String walletName, String walletType, DailyRecap recap) async {
    final dateStart = DateTime(recap.tanggal.year, recap.tanggal.month, recap.tanggal.day);
    final dateEnd = DateTime(recap.tanggal.year, recap.tanggal.month, recap.tanggal.day);
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 500),
            child: FutureBuilder<List<SaldoMutation>>(
              future: ref.read(recapServiceProvider).getWalletMutations(walletType, dateStart, dateEnd),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                
                final mutations = snapshot.data ?? [];
                
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  walletName,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  dateFmt.format(recap.tanggal),
                                  style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: mutations.isEmpty
                            ? const Center(child: Text('Tidak ada mutasi saldo hari ini.'))
                            : ListView.separated(
                                itemCount: mutations.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final m = mutations[index];
                                  final isStart = m.keterangan == 'Saldo Awal';
                                  
                                  Widget amountWidget;
                                  if (isStart) {
                                    amountWidget = Text(
                                      'Mulai',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                                    );
                                  } else if (m.kredit > 0) {
                                    amountWidget = Text(
                                      '+${currency.format(m.kredit)}',
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                    );
                                  } else {
                                    amountWidget = Text(
                                      '-${currency.format(m.debit)}',
                                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                                    );
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m.keterangan,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Saldo: ${currency.format(m.runningBalance)}',
                                                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade500),
                                              ),
                                            ],
                                          ),
                                        ),
                                        amountWidget,
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleStats(DailyRecap recap) {
    final surplus = recap.literMasuk - recap.literTerpakai;
    final isPositive = surplus >= 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indikator Kendaraan & BBM',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(Icons.speed, '${recap.jarakTempuh.toStringAsFixed(1)} KM', 'Jarak Tempuh'),
                _statItem(Icons.local_gas_station, '+${recap.literMasuk.toStringAsFixed(1)} L', 'BBM Masuk'),
                _statItem(Icons.whatshot, '-${recap.literTerpakai.toStringAsFixed(1)} L', 'BBM Terpakai'),
              ],
            ),
            const Divider(color: Colors.white10, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(
                  isPositive ? Icons.battery_charging_full : Icons.battery_alert,
                  '${isPositive ? '+' : ''}${surplus.toStringAsFixed(1)} L',
                  'Est. Sisa Tangki',
                  color: isPositive ? Colors.greenAccent : Colors.redAccent,
                ),
                _statItem(
                  Icons.av_timer,
                  recap.literMasuk > 0
                      ? '${(recap.jarakTempuh / recap.literMasuk).toStringAsFixed(1)} KM/L'
                      : 'N/A',
                  'KM/L Aktual',
                  color: recap.literMasuk > 0 ? Colors.cyanAccent : Colors.white70,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label, {Color color = Colors.white70}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color == Colors.white70 ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildReconciliationCard(RecapDetailState state) {
    final s = state.summary;
    if (s == null) return const SizedBox();

    final actualAppVal = double.tryParse(_actualAppBalanceCtrl.text) ?? 0;
    final actualGrabKreditVal = double.tryParse(_actualGrabKreditCtrl.text) ?? 0;
    final actualGrabTunaiVal = double.tryParse(_actualGrabTunaiCtrl.text) ?? 0;
    final actualGrabOvoVal = double.tryParse(_actualGrabOvoCtrl.text) ?? 0;
    final actualMandiriVal = double.tryParse(_actualMandiriCtrl.text) ?? 0;
    final actualBcaVal = double.tryParse(_actualBcaCtrl.text) ?? 0;

    final appDiscrepancy = actualAppVal - s.saldoAkhirApp;
    final grabKreditDiscrepancy = actualGrabKreditVal - s.saldoAkhirGrabKredit;
    final grabTunaiDiscrepancy = actualGrabTunaiVal - s.saldoAkhirGrabTunai;
    final grabOvoDiscrepancy = actualGrabOvoVal - s.saldoAkhirGrabOvo;
    final mandiriDiscrepancy = actualMandiriVal - s.saldoAkhirMandiri;
    final bcaDiscrepancy = actualBcaVal - s.saldoAkhirBca;
    final cashDiscrepancy = s.pettyCashTotal - s.cashAkhir;

    final cashCorrect = cashDiscrepancy == 0;
    final appCorrect = appDiscrepancy == 0;
    final grabKreditCorrect = grabKreditDiscrepancy == 0;
    final grabTunaiCorrect = grabTunaiDiscrepancy == 0;
    final grabOvoCorrect = grabOvoDiscrepancy == 0;
    final mandiriCorrect = mandiriDiscrepancy == 0;
    final bcaCorrect = bcaDiscrepancy == 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rekonsiliasi Daily Closing & EOD',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            const Text('Saldo E-Wallet / Bank HP Aktual saat Closing:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _numField('ShopeeFood HP', _actualAppBalanceCtrl, enabled: state.status != 'closed'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numField('Grab Kredit HP', _actualGrabKreditCtrl, enabled: state.status != 'closed'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _numField('Grab Tunai HP', _actualGrabTunaiCtrl, enabled: state.status != 'closed'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numField('Grab OVO HP', _actualGrabOvoCtrl, enabled: state.status != 'closed'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _numField('Mandiri HP', _actualMandiriCtrl, enabled: state.status != 'closed'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numField('BCA HP', _actualBcaCtrl, enabled: state.status != 'closed'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _discrepancyRow(
              'Selisih Kas Tunai (Drawer vs Buku)',
              cashDiscrepancy,
              cashCorrect,
            ),
            const Divider(height: 16),
            _discrepancyRow(
              'Selisih ShopeeFood',
              appDiscrepancy,
              appCorrect,
            ),
            const Divider(height: 16),
            _discrepancyRow(
              'Selisih Grab Kredit',
              grabKreditDiscrepancy,
              grabKreditCorrect,
            ),
            const Divider(height: 16),
            _discrepancyRow(
              'Selisih Grab Tunai',
              grabTunaiDiscrepancy,
              grabTunaiCorrect,
            ),
            const Divider(height: 16),
            _discrepancyRow(
              'Selisih Grab OVO',
              grabOvoDiscrepancy,
              grabOvoCorrect,
            ),
            const Divider(height: 16),
            _discrepancyRow(
              'Selisih Mandiri',
              mandiriDiscrepancy,
              mandiriCorrect,
            ),
            const Divider(height: 16),
            _discrepancyRow(
              'Selisih BCA',
              bcaDiscrepancy,
              bcaCorrect,
            ),
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              child: state.status == 'open'
                  ? FilledButton.icon(
                      icon: const Icon(Icons.lock_outline),
                      onPressed: () => _confirmCloseDay(state),
                      label: const Text('Tutup Hari (Close Day)'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade800,
                        foregroundColor: Colors.white,
                      ),
                    )
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.lock_open_outlined),
                      onPressed: _reopenDay,
                      label: const Text('Buka Kembali Rekap Harian'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade800,
                        side: BorderSide(color: Colors.red.shade800),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _discrepancyRow(String label, double value, bool isCorrect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle_outline : Icons.error_outline,
              color: isCorrect ? Colors.green : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              isCorrect ? 'Sesuai (Rp 0)' : 'Selisih ${currency.format(value)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmCloseDay(RecapDetailState state) async {
    final actualSf = double.tryParse(_actualAppBalanceCtrl.text) ?? 0;
    final actualGrabKredit = double.tryParse(_actualGrabKreditCtrl.text) ?? 0;
    final actualGrabTunai = double.tryParse(_actualGrabTunaiCtrl.text) ?? 0;
    final actualGrabOvo = double.tryParse(_actualGrabOvoCtrl.text) ?? 0;
    final actualMandiri = double.tryParse(_actualMandiriCtrl.text) ?? 0;
    final actualBca = double.tryParse(_actualBcaCtrl.text) ?? 0;
    
    // 1. Simpan header/telemetri saat ini dulu
    await _saveHeader();

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tutup Rekap Harian?'),
        content: const Text(
          'Tindakan ini akan mengunci rekap harian untuk hari ini. '
          'Anda tidak dapat mengubah data transaksi atau petty cash kecuali membuka kembali kunci rekap ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            child: const Text('Ya, Tutup Hari'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(recapDetailNotifierProvider(widget.recapId).notifier).closeRecap(
            actualSf: actualSf,
            actualGrabKredit: actualGrabKredit,
            actualGrabTunai: actualGrabTunai,
            actualGrabOvo: actualGrabOvo,
            actualMandiri: actualMandiri,
            actualBca: actualBca,
          );
      if (!mounted) return;
      _showClosingReportDialog(ref.read(recapDetailNotifierProvider(widget.recapId)).summary!);
    }
  }

  Future<void> _reopenDay() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buka Kembali Rekap Harian?'),
        content: const Text(
          'Membuka kembali rekap harian akan memperbolehkan edit data transaksi dan petty cash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buka Kunci'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(recapDetailNotifierProvider(widget.recapId).notifier).reopenRecap();
    }
  }

  void _showClosingReportDialog(DailyRecap s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.assignment_turned_in, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Daily Closing Report'),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _reportRow('Tanggal', dateFmt.format(s.tanggal)),
                const Divider(),
                _reportRow('Net Earnings', currency.format(s.netEarning)),
                _reportRow('Jarak Tempuh', '${s.jarakTempuh.toStringAsFixed(1)} KM'),
                const Divider(),
                _reportRow('Uang Kas Awal', currency.format(s.cashAwal)),
                _reportRow('Uang Kas Akhir (Buku)', currency.format(s.cashAkhir)),
                _reportRow('Petty Cash Aktual', currency.format(s.pettyCashTotal)),
                _reportRow(
                  'Selisih Kas Tunai',
                  currency.format(s.cashDiscrepancy),
                  color: s.cashDiscrepancy == 0 ? Colors.green : Colors.red,
                ),
                const Divider(),
                const Text(
                  'Detail Saldo Aplikasi & Rekening (Buku vs HP)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _reportRow('ShopeeFood (Buku)', currency.format(s.saldoAkhirApp)),
                _reportRow('ShopeeFood (HP)', currency.format(s.saldoAkhirAppAktual)),
                _reportRow(
                  'Selisih ShopeeFood',
                  currency.format(s.appDiscrepancy),
                  color: s.appDiscrepancy == 0 ? Colors.green : Colors.red,
                ),
                const Divider(),
                _reportRow('Grab Kredit (Buku)', currency.format(s.saldoAkhirGrabKredit)),
                _reportRow('Grab Kredit (HP)', currency.format(s.saldoAkhirGrabKreditAktual)),
                _reportRow(
                  'Selisih Grab Kredit',
                  currency.format(s.grabKreditDiscrepancy),
                  color: s.grabKreditDiscrepancy == 0 ? Colors.green : Colors.red,
                ),
                const Divider(),
                _reportRow('Grab Tunai (Buku)', currency.format(s.saldoAkhirGrabTunai)),
                _reportRow('Grab Tunai (HP)', currency.format(s.saldoAkhirGrabTunaiAktual)),
                _reportRow(
                  'Selisih Grab Tunai',
                  currency.format(s.grabTunaiDiscrepancy),
                  color: s.grabTunaiDiscrepancy == 0 ? Colors.green : Colors.red,
                ),
                const Divider(),
                _reportRow('Grab OVO (Buku)', currency.format(s.saldoAkhirGrabOvo)),
                _reportRow('Grab OVO (HP)', currency.format(s.saldoAkhirGrabOvoAktual)),
                _reportRow(
                  'Selisih Grab OVO',
                  currency.format(s.grabOvoDiscrepancy),
                  color: s.grabOvoDiscrepancy == 0 ? Colors.green : Colors.red,
                ),
                const Divider(),
                _reportRow('Mandiri (Buku)', currency.format(s.saldoAkhirMandiri)),
                _reportRow('Mandiri (HP)', currency.format(s.saldoAkhirMandiriAktual)),
                _reportRow(
                  'Selisih Mandiri',
                  currency.format(s.mandiriDiscrepancy),
                  color: s.mandiriDiscrepancy == 0 ? Colors.green : Colors.red,
                ),
                const Divider(),
                _reportRow('BCA (Buku)', currency.format(s.saldoAkhirBca)),
                _reportRow('BCA (HP)', currency.format(s.saldoAkhirBcaAktual)),
                _reportRow(
                  'Selisih BCA',
                  currency.format(s.bcaDiscrepancy),
                  color: s.bcaDiscrepancy == 0 ? Colors.green : Colors.red,
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  Widget _reportRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
