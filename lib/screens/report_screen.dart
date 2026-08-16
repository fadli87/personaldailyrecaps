import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/recap_providers.dart';
import '../models/daily_recap.dart';
import '../models/saldo_mutation.dart';
import 'home_screen.dart' show currency;

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  
  bool _isLoading = true;
  List<DailyRecap> _recaps = [];
  Map<String, double> _platformData = {};
  String? _error;

  int _activeTab = 0;
  String _selectedAccount = 'cash';
  List<SaldoMutation> _mutations = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    
    Future.microtask(() => _loadData());
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final service = ref.read(recapServiceProvider);
      final recaps = await service.getRecapsInPeriod(_startDate, _endDate);
      final platform = await service.getPlatformIncomeDistributionInPeriod(_startDate, _endDate);
      final mutations = await service.getWalletMutations(_selectedAccount, _startDate, _endDate);
      setState(() {
        _recaps = recaps;
        _platformData = platform;
        _mutations = mutations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _selectPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      if (preset == 'bulan_ini') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0);
      } else if (preset == 'bulan_lalu') {
        _startDate = DateTime(now.year, now.month - 1, 1);
        _endDate = DateTime(now.year, now.month, 0);
      } else if (preset == '7_hari') {
        _startDate = now.subtract(const Duration(days: 6));
        _endDate = now;
      } else if (preset == '30_hari') {
        _startDate = now.subtract(const Duration(days: 29));
        _endDate = now;
      }
    });
    _loadData();
  }

  Future<void> _selectCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  Future<void> _exportToCSV() async {
    try {
      final service = ref.read(recapServiceProvider);
      
      // 1. Generate CSV Data
      final csv = StringBuffer();
      
      // Section 1: Ringkasan Harian
      csv.writeln('"LAPORAN RINGKASAN HARIAN"');
      csv.writeln('"Tanggal","Cash Awal","Saldo Awal","Total Pemasukan","Total Pengeluaran","Laba Bersih","Jarak Tempuh (KM)","BBM Terpakai (L)","Status"');
      for (var r in _recaps) {
        final dateStr = DateFormat('yyyy-MM-dd').format(r.tanggal);
        csv.writeln('"$dateStr","${r.cashAwal}","${r.saldoAwalApp}","${r.totalIncome}","${r.totalExpense}","${r.netEarning}","${r.jarakTempuh}","${r.literTerpakai}","${r.status}"');
      }
      
      csv.writeln();
      csv.writeln();
      
      // Section 2: Detail Transaksi
      csv.writeln('"LAPORAN DETAIL TRANSAKSI"');
      csv.writeln('"Tanggal","Urutan","Platform/Keterangan","Tipe","Income","Expense","Cust Pay","Cust Change","Deduct Cash App","Saldo Top Up","Remark"');
      
      final rawOrders = await service.getRawOrdersInPeriod(_startDate, _endDate);
      for (var o in rawOrders) {
        final dateStr = o['recap_tanggal'] ?? '';
        final urutan = o['urutan'] ?? '';
        final type = o['type'] ?? '';
        final platform = o['platform'] ?? o['keterangan'] ?? '';
        final income = o['income'] ?? 0;
        final expense = o['expense'] ?? 0;
        final custPay = o['cust_pay'] ?? 0;
        final custChange = o['cust_change'] ?? 0;
        final deductCashApp = o['deduct_cash_app'] ?? 0;
        final saldoTopUp = o['saldo_top_up'] ?? 0;
        final remark = o['remark'] ?? '';
        csv.writeln('"$dateStr","$urutan","$platform","$type","$income","$expense","$custPay","$custChange","$deductCashApp","$saldoTopUp","$remark"');
      }
      
      // 2. Save file to Downloads folder
      final dir = await getDownloadsDirectory();
      if (dir == null) {
        throw Exception('Folder Downloads tidak ditemukan');
      }
      final startStr = DateFormat('yyyyMMdd').format(_startDate);
      final endStr = DateFormat('yyyyMMdd').format(_endDate);
      final filePath = '${dir.path}/sf_daily_recap_${startStr}_$endStr.csv';
      
      final file = File(filePath);
      await file.writeAsString(csv.toString());
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ekspor Berhasil'),
          content: Text('Laporan CSV berhasil disimpan di:\n$filePath'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor CSV: $e')),
      );
    }
  }

  void _copyToClipboard(double net, double income, double expense, double totalKm, double totalLiter, double efisiensi) {
    final startStr = DateFormat('dd/MM/yyyy').format(_startDate);
    final endStr = DateFormat('dd/MM/yyyy').format(_endDate);
    
    final buffer = StringBuffer();
    buffer.writeln('📊 LAPORAN KINERJA SF DAILY RECAP');
    buffer.writeln('Periode: $startStr s/d $endStr');
    buffer.writeln('----------------------------------');
    buffer.writeln('Laba Bersih      : ${currency.format(net)}');
    buffer.writeln('Total Pemasukan  : ${currency.format(income)}');
    buffer.writeln('Total Pengeluaran: ${currency.format(expense)}');
    buffer.writeln('----------------------------------');
    buffer.writeln('Performa Kendaraan:');
    buffer.writeln('Jarak Tempuh     : ${totalKm.toStringAsFixed(1)} KM');
    buffer.writeln('Konsumsi BBM     : ${totalLiter.toStringAsFixed(1)} L');
    buffer.writeln('Efisiensi Rata2  : ${efisiensi.toStringAsFixed(1)} KM/L');
    buffer.writeln('----------------------------------');
    buffer.writeln('Kontribusi Pendapatan Platform/Rekening:');
    
    final totalSales = _platformData.values.fold(0.0, (a, b) => a + b);
    _platformData.forEach((platform, amount) {
      final pct = totalSales > 0 ? (amount / totalSales * 100) : 0.0;
      buffer.writeln('- $platform: ${currency.format(amount)} (${pct.toStringAsFixed(0)}%)');
    });

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ringkasan laporan disalin ke clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startStr = DateFormat('dd MMM yyyy', 'id_ID').format(_startDate);
    final endStr = DateFormat('dd MMM yyyy', 'id_ID').format(_endDate);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 850;

                    double totalIncome = 0;
                    double totalExpense = 0;
                    double totalNet = 0;
                    double totalKm = 0;
                    double totalLiter = 0;

                    for (var r in _recaps) {
                      totalIncome += r.totalIncome;
                      totalExpense += r.totalExpense;
                      totalNet += r.netEarning;
                      totalKm += r.jarakTempuh;
                      totalLiter += r.literTerpakai;
                    }
                    double efisiensi = totalLiter > 0 ? (totalKm / totalLiter) : 0.0;

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // --- PRESET BUTTONS & DATE RANGE SELECTOR ---
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Filter Periode Laporan',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _presetButton('Bulan Ini', 'bulan_ini'),
                                    _presetButton('Bulan Lalu', 'bulan_lalu'),
                                    _presetButton('7 Hari Terakhir', '7_hari'),
                                    _presetButton('30 Hari Terakhir', '30_hari'),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.date_range, size: 16),
                                      onPressed: _selectCustomRange,
                                      label: const Text('Kustom Range'),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.black54),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$startStr - $endStr',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.refresh),
                                      onPressed: _loadData,
                                      tooltip: 'Segarkan Data',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- TAB SELECTOR ---
                        Center(
                          child: SegmentedButton<int>(
                            segments: const [
                              ButtonSegment<int>(
                                value: 0,
                                label: Text('Ringkasan Kinerja'),
                                icon: Icon(Icons.analytics_outlined),
                              ),
                              ButtonSegment<int>(
                                value: 1,
                                label: Text('Mutasi Rekening'),
                                icon: Icon(Icons.receipt_long_outlined),
                              ),
                            ],
                            selected: {_activeTab},
                            onSelectionChanged: (set) {
                              setState(() {
                                _activeTab = set.first;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (_activeTab == 0) ...[
                          // --- FINANCIAL KPI SUMMARY ---
                          _buildFinancialGrid(isDesktop, totalNet, totalIncome, totalExpense),
                          const SizedBox(height: 20),

                          // --- VEHICLE FUEL METRICS ---
                          _buildVehicleCard(totalKm, totalLiter, efisiensi),
                          const SizedBox(height: 20),

                          // --- PLATFORM ANALYSIS SECTION ---
                          _buildPlatformCard(),
                          const SizedBox(height: 20),

                          // --- REPORT ACTIONS ---
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ekspor & Bagikan Laporan',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.copy),
                                          onPressed: () => _copyToClipboard(totalNet, totalIncome, totalExpense, totalKm, totalLiter, efisiensi),
                                          label: const Text('Salin Ringkasan WA'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.table_view_outlined),
                                          onPressed: _exportToCSV,
                                          label: const Text('Ekspor CSV (Excel)'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ] else ...[
                          _buildMutationTab(isDesktop),
                          const SizedBox(height: 40),
                        ],
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildMutationTab(bool isDesktop) {
    final accountOptions = [
      {'value': 'cash', 'label': 'Kas Tunai'},
      {'value': 'shopeefood', 'label': 'ShopeeFood'},
      {'value': 'grab_tunai', 'label': 'Grab Tunai'},
      {'value': 'grab_kredit', 'label': 'Grab Kredit'},
      {'value': 'grab_ovo', 'label': 'Grab OVO'},
      {'value': 'mandiri', 'label': 'Bank Mandiri'},
      {'value': 'bca', 'label': 'Bank BCA'},
    ];

    double saldoAwal = 0.0;
    double totalMasuk = 0.0;
    double totalKeluar = 0.0;
    double saldoAkhir = 0.0;

    if (_mutations.isNotEmpty) {
      final first = _mutations.firstWhere(
        (m) => m.keterangan == 'Saldo Awal',
        orElse: () => _mutations.first,
      );
      saldoAwal = first.runningBalance;
      
      for (final m in _mutations) {
        if (m.keterangan != 'Saldo Awal') {
          totalMasuk += m.kredit;
          totalKeluar += m.debit;
        }
      }
      saldoAkhir = _mutations.last.runningBalance;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Akun Keuangan:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedAccount,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: accountOptions.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt['value'],
                        child: Text(opt['label']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedAccount = val;
                        });
                        _loadData();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = isDesktop ? 200 : (constraints.maxWidth - 12) / 2;
            Widget itemBox(String label, double val, Color col) {
              return Container(
                width: cardWidth,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        currency.format(val),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: col),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                itemBox('Saldo Awal Periode', saldoAwal, Colors.black87),
                itemBox('Total Mutasi Masuk', totalMasuk, Colors.green.shade700),
                itemBox('Total Mutasi Keluar', totalKeluar, Colors.red.shade700),
                itemBox('Saldo Akhir Periode', saldoAkhir, const Color(0xFF2E7D32)),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Riwayat Mutasi Saldo',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_all_outlined),
                      tooltip: 'Salin Mutasi ke Clipboard',
                      onPressed: () {
                        final buffer = StringBuffer();
                        buffer.writeln('MUTASI REKENING - $_selectedAccount');
                        buffer.writeln('Periode: ${DateFormat('yyyy-MM-dd').format(_startDate)} s.d. ${DateFormat('yyyy-MM-dd').format(_endDate)}');
                        buffer.writeln('--------------------------------------------------');
                        buffer.writeln('Tanggal\tKeterangan\tKeluar (Debit)\tMasuk (Kredit)\tSaldo');
                        for (final m in _mutations) {
                          buffer.writeln('${DateFormat('yyyy-MM-dd').format(m.tanggal)}\t${m.keterangan}\t${m.debit}\t${m.kredit}\t${m.runningBalance}');
                        }
                        Clipboard.setData(ClipboardData(text: buffer.toString()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Mutasi rekening disalin ke clipboard!')),
                        );
                      },
                    ),
                  ],
                ),
                const Divider(),
                if (_mutations.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('Tidak ada mutasi saldo dalam periode ini.'),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: isDesktop ? 800 : 500),
                      child: DataTable(
                        columnSpacing: 16,
                        columns: const [
                          DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Keterangan', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Debit (Keluar)', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Kredit (Masuk)', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Saldo Berjalan', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _mutations.map((m) {
                          final isStart = m.keterangan == 'Saldo Awal';
                          return DataRow(
                            cells: [
                              DataCell(Text(DateFormat('dd MMM yyyy', 'id_ID').format(m.tanggal))),
                              DataCell(Text(m.keterangan)),
                              DataCell(
                                isStart
                                    ? const Text('-')
                                    : Text(
                                        m.debit > 0 ? currency.format(m.debit) : '-',
                                        style: TextStyle(
                                          color: m.debit > 0 ? Colors.red.shade700 : null,
                                          fontWeight: m.debit > 0 ? FontWeight.bold : null,
                                        ),
                                      ),
                              ),
                              DataCell(
                                isStart
                                    ? const Text('-')
                                    : Text(
                                        m.kredit > 0 ? currency.format(m.kredit) : '-',
                                        style: TextStyle(
                                          color: m.kredit > 0 ? Colors.green.shade700 : null,
                                          fontWeight: m.kredit > 0 ? FontWeight.bold : null,
                                        ),
                                      ),
                              ),
                              DataCell(
                                Text(
                                  currency.format(m.runningBalance),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _presetButton(String text, String value) {
    return ActionChip(
      label: Text(text),
      onPressed: () => _selectPreset(value),
      backgroundColor: Colors.white,
      elevation: 1,
    );
  }

  Widget _buildFinancialGrid(bool isDesktop, double net, double income, double expense) {
    final items = [
      _KpiItem('Laba Bersih', net, Icons.payments, const Color(0xFF2E7D32)),
      _KpiItem('Total Pemasukan', income, Icons.arrow_upward, const Color(0xFF4CAF50)),
      _KpiItem('Total Pengeluaran', expense, Icons.arrow_downward, const Color(0xFFD32F2F)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 3 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isDesktop ? 2.5 : 3.5,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildCard(items[i]),
    );
  }

  Widget _buildCard(_KpiItem kpi) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: kpi.color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(kpi.icon, color: kpi.color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                kpi.label.toUpperCase(),
                style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currency.format(kpi.value),
              style: const TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(double totalKm, double totalLiter, double efisiensi) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PERFORMA KENDARAAN PERIODE',
            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _vehicleItem(Icons.speed, '${totalKm.toStringAsFixed(1)} KM', 'Jarak Tempuh'),
              _vehicleItem(Icons.local_gas_station, '${totalLiter.toStringAsFixed(1)} L', 'BBM Terpakai'),
              _vehicleItem(Icons.eco, '${efisiensi.toStringAsFixed(1)} KM/L', 'Efisiensi Rata2', color: Colors.greenAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vehicleItem(IconData icon, String value, String label, {Color color = Colors.white}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color.withOpacity(0.8), size: 22),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildPlatformCard() {
    final totalSales = _platformData.values.fold(0.0, (a, b) => a + b);

    final colors = [
      const Color(0xFF2E7D32),
      const Color(0xFF1565C0),
      const Color(0xFFF9A825),
      const Color(0xFFD84315),
      const Color(0xFFAD1457),
      const Color(0xFF4527A0),
    ];

    int colorIdx = 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kontribusi Pendapatan per Platform / Rekening',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            if (_platformData.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Tidak ada pendapatan platform pada periode ini.'),
                ),
              )
            else
              ..._platformData.entries.map((entry) {
                final color = colors[colorIdx % colors.length];
                colorIdx++;
                final pct = totalSales > 0 ? (entry.value / totalSales) : 0.0;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                          Text(
                            '${currency.format(entry.value)} (${(pct * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          color: color,
                          backgroundColor: Colors.grey.shade100,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _KpiItem {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  _KpiItem(this.label, this.value, this.icon, this.color);
}
