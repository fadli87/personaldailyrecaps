import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/recap_providers.dart';
import '../models/daily_recap.dart';
import '../models/fuel_filling.dart';
import '../services/sync_service.dart';
import '../screens/fuel_filling_sheet.dart';
import '../providers/finance_providers.dart';
import '../logic/ledger_math.dart';
import 'home_screen.dart' show currency;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recapsAsync = ref.watch(recapsProvider);
    final platformAsync = ref.watch(platformDistributionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50 - Bersih dan modern
      body: RefreshIndicator(
        displacement: 20,
        color: const Color(0xFF2E7D32),
        onRefresh: () async {
          ref.invalidate(recapsProvider);
          ref.invalidate(platformDistributionProvider);
          try {
            await ref.read(recapsProvider.future);
            await ref.read(platformDistributionProvider.future);
          } catch (_) {}
        },
        child: recapsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Gagal memuat data: $err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          data: (recaps) {
            return platformAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              error: (err, stack) => Center(
                child: Text('Gagal memuat platform: $err'),
              ),
              data: (platformData) {
                if (recaps.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 180),
                      const Center(
                        child: Column(
                          children: [
                            Icon(Icons.assignment_late_outlined,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Belum ada data transaksi.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
                      Center(
                        child: Text(
                          '© 2026 D\'Azhars Studio. All Rights Reserved.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey.shade300,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Ambil rekap harian terbaru dan rekap hari sebelumnya
                final latestRecap = recaps.first;
                final previousRecap = recaps.length > 1 ? recaps[1] : null;

                // Kalkulasi Kendaraan 7 Hari Terakhir (Siklus Mingguan)
                double weeklyJarak = 0;
                double weeklyLiterTerpakai = 0;
                double weeklyLiterMasuk = 0;

                final weeklyRecaps = recaps.take(7).toList();
                for (var r in weeklyRecaps) {
                  weeklyJarak += r.jarakTempuh;
                  weeklyLiterTerpakai += r.literTerpakai;
                  weeklyLiterMasuk += r.literMasuk;
                }

                // Ambil 7 hari TERBARU secara kronologis (terlama -> terbaru) untuk grafik
                final chartRecaps = recaps.take(7).toList().reversed.toList();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 850;
                    return ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        // Header Selamat Datang
                        _buildHeader(context, ref),
                        const SizedBox(height: 24),

                        // --- SECTION 1: KPI FINANCIAL CARDS (GRADASI PREMIUM) ---
                        _buildFinancialKPIs(
                            isDesktop, latestRecap, previousRecap, ref),
                        const SizedBox(height: 24),

                        // --- SECTION 1B: STATUS SALDO AKUN & REKENING ---
                        _buildAccountBalances(context, recaps.first, ref),
                        const SizedBox(height: 24),

                        // --- SECTION 1C: KARTU KAS & REMINDER SERVIS MOTOR ---
                        _buildFinanceAndServiceQuickCards(context, ref),
                        const SizedBox(height: 24),

                        // --- SECTION 2: VEHICLE TELEMETRY CARD (MODERN GLASSMORPHISM EFFECT) ---
                        _buildVehicleTelemetry(weeklyJarak, weeklyLiterTerpakai,
                            weeklyLiterMasuk, ref),
                        const SizedBox(height: 24),

                        // --- SECTION 2B: FUEL ALERT & RECENT FILLINGS ---
                        _buildFuelAlertAndHistory(ref, latestRecap),
                        const SizedBox(height: 24),

                        // --- SECTION 3: CHARTS ---
                        if (isDesktop) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildChartContainer(
                                  title:
                                      'Tren Keuntungan Bersih (7 Hari Terakhir)',
                                  subtitle:
                                      'Pantau stabilitas harian pendapatan bersih Anda',
                                  child: _buildLoyverseLineChart(chartRecaps),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 2,
                                child: _buildChartContainer(
                                  title: 'Penjualan per Platform',
                                  subtitle: 'Persentase performa ojek online',
                                  child: _buildLoyversePieChart(platformData),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildChartContainer(
                            title:
                                'Perbandingan Pemasukan vs Pengeluaran Harian',
                            subtitle:
                                'Rasio rasional antara modal BBM/Operasional dan Omset harian',
                            child: _buildLoyverseBarChart(chartRecaps),
                          ),
                        ] else ...[
                          _buildChartContainer(
                            title: 'Tren Keuntungan Bersih (7 Hari Terakhir)',
                            subtitle:
                                'Pantau stabilitas harian pendapatan bersih Anda',
                            child: _buildLoyverseLineChart(chartRecaps),
                          ),
                          const SizedBox(height: 20),
                          _buildChartContainer(
                            title: 'Penjualan per Platform',
                            subtitle: 'Persentase performa ojek online',
                            child: _buildLoyversePieChart(platformData),
                          ),
                          const SizedBox(height: 20),
                          _buildChartContainer(
                            title:
                                'Perbandingan Pemasukan vs Pengeluaran Harian',
                            subtitle:
                                'Rasio rasional antara modal BBM/Operasional dan Omset harian',
                            child: _buildLoyverseBarChart(chartRecaps),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            '© 2026 D\'Azhars Studio. All Rights Reserved.',
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
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // --- HEADER DASHBOARD ---
  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting = 'Selamat Datang';
    if (hour < 11) {
      greeting = 'Selamat Pagi';
    } else if (hour < 15) {
      greeting = 'Selamat Siang';
    } else if (hour < 19) {
      greeting = 'Selamat Sore';
    } else {
      greeting = 'Selamat Malam';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, Pak Fadli!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Ringkasan data operasional harian terupdate.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey.shade500,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: () => _showSyncLogsBottomSheet(context, ref),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE2F1E8),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFF2E7D32).withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSyncLogsBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final logs = ref.watch(syncLogsProvider);
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Status & Log Sinkronisasi',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.cloud_done_outlined,
                          color: Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Supabase Cloud DB',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Status: Online (Terhubung)',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('Sinkronkan'),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final nowStr =
                              DateFormat('HH:mm:ss').format(DateTime.now());

                          ref.read(syncLogsProvider.notifier).addLog(
                              '$nowStr: Memulai sinkronisasi Supabase...');

                          try {
                            await SyncService.sync();

                            final successStr =
                                DateFormat('HH:mm:ss').format(DateTime.now());
                            ref.read(syncLogsProvider.notifier).addLog(
                                '$successStr: Sinkronisasi data sukses (Supabase synced).');

                            ref.invalidate(recapsProvider);
                            ref.invalidate(platformDistributionProvider);

                            messenger.showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Sinkronisasi Supabase sukses!')),
                            );
                          } catch (e) {
                            final failStr =
                                DateFormat('HH:mm:ss').format(DateTime.now());
                            ref
                                .read(syncLogsProvider.notifier)
                                .addLog('$failStr: Sinkronisasi gagal: $e');
                            messenger.showSnackBar(
                              SnackBar(content: Text('Sinkronisasi gagal: $e')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Riwayat Aktivitas (Log)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[logs.length - 1 - index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey)),
                              Expanded(
                                child: Text(
                                  log,
                                  style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: Colors.black87),
                                ),
                              ),
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
        );
      },
    );
  }

  // --- SECTION 1: FINANCIAL CARDS DENGAN GRADASI PREMIUM & SHADOW SOFT ---
  Widget _buildFinancialKPIs(
      bool isDesktop, DailyRecap latest, DailyRecap? previous, WidgetRef ref) {
    final net = latest.netEarning;
    final income = latest.totalIncome;
    final expense = latest.totalExpense;

    final prevNet = previous?.netEarning ?? 0.0;
    final prevIncome = previous?.totalIncome ?? 0.0;
    final prevExpense = previous?.totalExpense ?? 0.0;

    final netDiff = net - prevNet;
    final incomeDiff = income - prevIncome;
    final expenseDiff = expense - prevExpense;

    String _diffText(double diff) {
      if (previous == null) return 'Hari pertama';
      final sign = diff >= 0 ? '+' : '';
      return '$sign${currency.format(diff)} vs kemarin';
    }

    final netDiffText = _diffText(netDiff);
    final incomeDiffText = _diffText(incomeDiff);
    final expenseDiffText = _diffText(expenseDiff);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (isDesktop) {
          return Row(
            children: [
              Expanded(
                  child: _buildPremiumKpiCard(
                title: 'Keuntungan Bersih',
                value: net,
                icon: Icons.wallet_rounded,
                colors: [
                  const Color(0xFF16A34A),
                  const Color(0xFF15803D)
                ], // Hijau gradasi
                iconColor: Colors.white.withOpacity(0.2),
                comparisonText: netDiffText,
                isMain: true,
                onTap: () {
                  ref.read(homeTabProvider.notifier).change(2); // Laporan
                  ref.read(reportTabProvider.notifier).change(0); // Kinerja
                },
              )),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildPremiumKpiCard(
                title: 'Total Pemasukan',
                value: income,
                icon: Icons.trending_up_rounded,
                colors: [
                  const Color(0xFF3B82F6),
                  const Color(0xFF2563EB)
                ], // Biru gradasi
                iconColor: Colors.white.withOpacity(0.2),
                comparisonText: incomeDiffText,
                onTap: () {
                  ref.read(homeTabProvider.notifier).change(2); // Laporan
                  ref.read(reportTabProvider.notifier).change(0); // Kinerja
                },
              )),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildPremiumKpiCard(
                title: 'Total Pengeluaran',
                value: expense,
                icon: Icons.trending_down_rounded,
                colors: [
                  const Color(0xFFEF4444),
                  const Color(0xFFDC2626)
                ], // Merah gradasi
                iconColor: Colors.white.withOpacity(0.2),
                comparisonText: expenseDiffText,
                onTap: () {
                  ref.read(homeTabProvider.notifier).change(2); // Laporan
                  ref.read(reportTabProvider.notifier).change(0); // Kinerja
                },
              )),
            ],
          );
        } else {
          return Column(
            children: [
              _buildPremiumKpiCard(
                title: 'Keuntungan Bersih',
                value: net,
                icon: Icons.wallet_rounded,
                colors: [const Color(0xFF16A34A), const Color(0xFF15803D)],
                iconColor: Colors.white.withOpacity(0.25),
                comparisonText: netDiffText,
                isMain: true,
                onTap: () {
                  ref.read(homeTabProvider.notifier).change(2); // Laporan
                  ref.read(reportTabProvider.notifier).change(0); // Kinerja
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildPremiumKpiCard(
                    title: 'Total Pemasukan',
                    value: income,
                    icon: Icons.trending_up_rounded,
                    colors: [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                    iconColor: Colors.white.withOpacity(0.2),
                    comparisonText: incomeDiffText,
                    isCompact: true,
                    onTap: () {
                      ref.read(homeTabProvider.notifier).change(2); // Laporan
                      ref.read(reportTabProvider.notifier).change(0); // Kinerja
                    },
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildPremiumKpiCard(
                    title: 'Total Pengeluaran',
                    value: expense,
                    icon: Icons.trending_down_rounded,
                    colors: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                    iconColor: Colors.white.withOpacity(0.2),
                    comparisonText: expenseDiffText,
                    isCompact: true,
                    onTap: () {
                      ref.read(homeTabProvider.notifier).change(2); // Laporan
                      ref.read(reportTabProvider.notifier).change(0); // Kinerja
                    },
                  )),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildPremiumKpiCard({
    required String title,
    required double value,
    required IconData icon,
    required List<Color> colors,
    required Color iconColor,
    String? comparisonText,
    bool isMain = false,
    bool isCompact = false,
    VoidCallback? onTap,
  }) {
    return Container(
      height: isMain ? 122 : (isCompact ? 102 : 117),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Stack(
            children: [
              // Background Decorative Circle
              Positioned(
                right: -20,
                bottom: -20,
                child: CircleAvatar(
                  radius: isMain ? 60 : 45,
                  backgroundColor: Colors.white.withOpacity(0.06),
                ),
              ),
              // Icon hiasan besar di pojok
              Positioned(
                right: 8,
                bottom: isMain ? 4 : 0,
                child: Icon(
                  icon,
                  size: isMain ? 74 : 54,
                  color: iconColor,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: isCompact ? 12 : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: isCompact ? 9 : 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        currency.format(value),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMain ? 24 : (isCompact ? 18 : 20),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    if (comparisonText != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            comparisonText.startsWith('+')
                                ? Icons.trending_up_rounded
                                : (comparisonText.startsWith('-')
                                    ? Icons.trending_down_rounded
                                    : (comparisonText == 'Hari pertama'
                                        ? Icons.star_border_rounded
                                        : Icons.swap_horiz_rounded)),
                            size: 11,
                            color: Colors.white.withOpacity(0.85),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            comparisonText,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ] else if (isMain) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 12, color: Colors.white.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text(
                            'Sudah dikurangi pengeluaran harian',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleTelemetry(double weeklyKm, double weeklyLiter,
      double weeklyLiterMasuk, WidgetRef ref) {
    double efisiensi = weeklyLiter > 0 ? (weeklyKm / weeklyLiter) : 0.0;
    double surplusDefisit = weeklyLiterMasuk - weeklyLiter;

    // Menentukan kategori kesehatan efisiensi BBM
    String efficiencyStatus = 'Tidak Terdeteksi';
    Color efficiencyColor = Colors.blueGrey.shade400;
    if (efisiensi > 0) {
      if (efisiensi >= 40) {
        efficiencyStatus = 'Sangat Irit';
        efficiencyColor = const Color(0xFF22C55E); // Green
      } else if (efisiensi >= 30) {
        efficiencyStatus = 'Normal';
        efficiencyColor = const Color(0xFFF59E0B); // Amber
      } else {
        efficiencyStatus = 'Boros / Perlu Servis';
        efficiencyColor = const Color(0xFFEF4444); // Red
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Slate 900 - Dark Glass Effect
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(homeTabProvider.notifier).change(2); // Laporan
            ref.read(reportTabProvider.notifier).change(0); // Kinerja
          },
          splashColor: Colors.white.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TELEMETRI & BBM 7 HARI TERAKHIR',
                      style: TextStyle(
                        color: Color(0xFF94A3B8), // Slate 400
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    if (efisiensi > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: efficiencyColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: efficiencyColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          efficiencyStatus.toUpperCase(),
                          style: TextStyle(
                            color: efficiencyColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _telemetryItem(
                      Icons.alt_route_rounded,
                      weeklyKm.toStringAsFixed(1),
                      'KM',
                      'Jarak Tempuh',
                      const Color(0xFF38BDF8), // Light Blue
                    ),
                    Container(width: 1, height: 40, color: Colors.white10),
                    _telemetryItem(
                      Icons.local_gas_station_rounded,
                      weeklyLiter.toStringAsFixed(1),
                      'Liter',
                      'BBM Terpakai',
                      const Color(0xFFFB923C), // Orange
                    ),
                    Container(width: 1, height: 40, color: Colors.white10),
                    _telemetryItem(
                      Icons.eco_rounded,
                      efisiensi.toStringAsFixed(1),
                      'KM/L',
                      'Efisiensi',
                      const Color(0xFF4ADE80), // Light Green
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      surplusDefisit >= 0
                          ? Icons.battery_charging_full
                          : Icons.battery_alert,
                      color: surplusDefisit >= 0
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white70),
                          children: [
                            const TextSpan(text: 'Estimasi Tangki Mingguan: '),
                            TextSpan(
                              text:
                                  '${surplusDefisit >= 0 ? '+' : ''}${surplusDefisit.toStringAsFixed(1)} Liter ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: surplusDefisit >= 0
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFEF4444),
                              ),
                            ),
                            TextSpan(
                              text: surplusDefisit >= 0
                                  ? '(Surplus Bensin)'
                                  : '(Defisit Bensin)',
                              style: const TextStyle(color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _telemetryItem(
    IconData icon,
    String value,
    String unit,
    String label,
    Color iconColor,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B), // Slate 500
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- CHART CONTAINER PREMIUM ---
  Widget _buildChartContainer({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      height: 350,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A)
                .withOpacity(0.03), // Shadow sangat redup & rapi
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.blueGrey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }

  // ============================================================================
  // CHARTS (MODERN STYLED)
  // ============================================================================

  Widget _buildLoyverseLineChart(List<DailyRecap> recaps) {
    if (recaps.isEmpty) return const Center(child: Text('Tidak cukup data'));

    final spots = <FlSpot>[];
    for (int i = 0; i < recaps.length; i++) {
      spots.add(FlSpot(i.toDouble(), recaps[i].netEarning));
    }

    const primaryColor = Color(0xFF16A34A); // Hijau Emerald Modern

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.blueGrey.shade100,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < recaps.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      DateFormat('dd/MM').format(recaps[idx].tanggal),
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.blueGrey.shade400,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatCompactNumber(value),
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.blueGrey.shade400,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: primaryColor,
            barWidth: 3.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(
              show: true,
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.18),
                  primaryColor.withOpacity(0.0)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoyversePieChart(Map<String, double> data) {
    if (data.isEmpty) return const Center(child: Text('Data tidak tersedia'));

    final colors = [
      const Color(0xFF10B981), // Emerald Green (ShopeeFood / Gofood)
      const Color(0xFF3B82F6), // Grab Blue/Kredit
      const Color(0xFFF59E0B), // Amber / Tunai
      const Color(0xFF8B5CF6), // Purple / Ovo
      const Color(0xFFEC4899), // Pink
      const Color(0xFF64748B), // Slate Grey
    ];

    final totalSales = data.values.fold(0.0, (a, b) => a + b);

    int colorIdx = 0;
    final sections = data.entries.map((entry) {
      final color = colors[colorIdx % colors.length];
      colorIdx++;
      final pct = totalSales > 0 ? (entry.value / totalSales * 100) : 0.0;
      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '${pct.toStringAsFixed(0)}%',
        radius: 42,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 38,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Scrollbar(
            child: ListView(
              shrinkWrap: true,
              children: data.entries.toList().asMap().entries.map((item) {
                final color = colors[item.key % colors.length];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item.value.key.toUpperCase()}\n${currency.format(item.value.value)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blueGrey.shade700,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoyverseBarChart(List<DailyRecap> recaps) {
    if (recaps.isEmpty) return const Center(child: Text('Tidak cukup data'));

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < recaps.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: recaps[i].totalIncome,
              color: const Color(0xFF3B82F6), // Blue Accent
              width: 7,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: recaps[i].totalExpense,
              color: const Color(0xFFEF4444), // Red Accent
              width: 7,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.blueGrey.shade100,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < recaps.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      DateFormat('dd/MM').format(recaps[idx].tanggal),
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.blueGrey.shade400,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatCompactNumber(value),
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.blueGrey.shade400,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: groups,
      ),
    );
  }

  static String _formatCompactNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}jt';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}rb';
    return value.toStringAsFixed(0);
  }

  Widget _buildAccountBalances(
      BuildContext context, DailyRecap latest, WidgetRef ref) {
    final wallets = [
      _WalletBalanceItem('cash', 'Kas Tunai', latest.cashAkhir,
          Icons.money_outlined, Colors.teal),
      _WalletBalanceItem('shopeefood', 'ShopeeFood', latest.saldoAkhirApp,
          Icons.fastfood_outlined, Colors.orange),
      _WalletBalanceItem('grab_tunai', 'Grab Tunai', latest.saldoAkhirGrabTunai,
          Icons.account_balance_wallet_outlined, Colors.green),
      _WalletBalanceItem(
          'grab_kredit',
          'Grab Kredit',
          latest.saldoAkhirGrabKredit,
          Icons.local_taxi_outlined,
          Colors.lightGreen),
      _WalletBalanceItem('grab_ovo', 'Grab OVO', latest.saldoAkhirGrabOvo,
          Icons.phone_android_outlined, Colors.purple),
      _WalletBalanceItem('mandiri', 'Bank Mandiri', latest.saldoAkhirMandiri,
          Icons.account_balance_wallet_outlined, Colors.blue),
      _WalletBalanceItem('bca', 'Bank BCA', latest.saldoAkhirBca,
          Icons.account_balance_outlined, Colors.indigo),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status Saldo Akun & Rekening',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: wallets.length,
            itemBuilder: (context, index) {
              final w = wallets[index];
              return InkWell(
                onTap: () {
                  ref.read(homeTabProvider.notifier).change(2); // Laporan
                  ref
                      .read(reportTabProvider.notifier)
                      .change(1); // Mutasi Rekening
                  ref.read(selectedAccountProvider.notifier).change(w.id);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 175,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(w.icon, color: w.color, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              w.name,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          currency.format(w.balance),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: w.balance < 0
                                ? Colors.red.shade700
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- FUEL ALERT & HISTORY WIDGET ---

  Widget _buildFuelAlertAndHistory(WidgetRef ref, DailyRecap latestRecap) {
    final recapId = latestRecap.id;

    return Consumer(
      builder: (context, ref, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header with Add Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '⛽ MONITORING BBM & RIWAYAT ISI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => showFuelFillingSheet(context, recapId),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Isi BBM',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Alert Card & Fuel Fillings List
            Consumer(
              builder: (context, ref, child) {
                final estimatedRemainingAsync =
                    ref.watch(estimatedFuelRemainingProvider(recapId));
                final fuelFillingsAsync =
                    ref.watch(fuelFillingsProvider(recapId));

                return Column(
                  children: [
                    // Alert Card (Estimasi Sisa BBM)
                    estimatedRemainingAsync.when(
                      loading: () => _buildSkeletonFuelCard(),
                      error: (err, stack) =>
                          _buildErrorFuelCard(err.toString()),
                      data: (estimatedRemaining) {
                        final isCritical =
                            estimatedRemaining <= 0.5 && estimatedRemaining > 0;
                        final isEmpty = estimatedRemaining <= 0;

                        return _buildFuelAlertCard(
                          context,
                          estimatedRemaining: estimatedRemaining,
                          isCritical: isCritical,
                          isEmpty: isEmpty,
                          onTap: () => showFuelFillingSheet(context, recapId),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Recent Fuel Fillings List
                    fuelFillingsAsync.when(
                      loading: () => _buildSkeletonFuelList(),
                      error: (err, stack) =>
                          _buildErrorFuelList(err.toString()),
                      data: (fillings) {
                        if (fillings.isEmpty) {
                          return _buildEmptyFuelState(
                            context,
                            recapId,
                            onAdd: () => showFuelFillingSheet(context, recapId),
                          );
                        }
                        return _buildFuelFillingsList(
                          context,
                          fillings,
                          ref,
                          recapId,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFuelAlertCard(
    BuildContext context, {
    required double estimatedRemaining,
    required bool isCritical,
    required bool isEmpty,
    required VoidCallback onTap,
  }) {
    Color alertColor;
    IconData alertIcon;
    String title;
    String subtitle;

    if (isEmpty) {
      alertColor = const Color(0xFFEF4444);
      alertIcon = Icons.battery_alert_rounded;
      title = 'TANGKI HAMPIR KOSONG!';
      subtitle = 'Estimasi sisa: 0 Liter. Segera isi BBM!';
    } else if (isCritical) {
      alertColor = const Color(0xFFF59E0B);
      alertIcon = Icons.warning_amber_rounded;
      title = 'PERINGATAN: SISA ≤ 0.5 LITER';
      subtitle =
          'Estimasi sisa: ${estimatedRemaining.toStringAsFixed(1)} Liter. Siapkan isi BBM.';
    } else {
      alertColor = const Color(0xFF22C55E);
      alertIcon = Icons.battery_charging_full_rounded;
      title = 'BBM AMAN';
      subtitle =
          'Estimasi sisa tangki: ${estimatedRemaining.toStringAsFixed(1)} Liter';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              alertColor.withOpacity(0.12),
              alertColor.withOpacity(0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: alertColor.withOpacity(isCritical || isEmpty ? 0.4 : 0.2),
            width: isCritical || isEmpty ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: alertColor.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Alert Icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: alertColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(alertIcon, color: alertColor, size: 28),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: alertColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: estimatedRemaining > 0
                          ? (estimatedRemaining / 10)
                              .clamp(0.0, 1.0) // Assuming max ~10L tank
                          : 0.0,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(alertColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tekan untuk catat isi BBM →',
                    style: TextStyle(
                      fontSize: 10,
                      color: alertColor.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(Icons.chevron_right_rounded, color: alertColor, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelFillingsList(
    BuildContext context,
    List<FuelFilling> fillings,
    WidgetRef ref,
    String recapId,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded,
                    color: Color(0xFF2E7D32), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Riwayat Pengisian BBM (Terbaru)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                Text(
                  '${fillings.length} catatan',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: fillings.length > 5
                ? 5
                : fillings.length, // Show max 5 on dashboard
            separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey.shade100,
                indent: 16,
                endIndent: 16),
            itemBuilder: (context, index) {
              final filling = fillings[index];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_gas_station_rounded,
                      color: Color(0xFFEF4444), size: 20),
                ),
                title: Text(
                  '${filling.liter.toStringAsFixed(2)} L × Rp ${filling.hargaPerLiter.toStringAsFixed(0)}/L',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 10, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM yy, HH:mm', 'id_ID')
                              .format(filling.tanggal),
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500),
                        ),
                        if (filling.odometer != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.speed_rounded,
                              size: 10, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            '${filling.odometer!.toStringAsFixed(0)} KM',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                    if (filling.catatan != null &&
                        filling.catatan!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        filling.catatan!,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade400),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                trailing: Text(
                  currency.format(filling.totalBiaya),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
                onTap: () => showFuelFillingSheet(
                  context,
                  recapId,
                  existingFilling: filling,
                ),
              );
            },
          ),
          // View All Footer
          if (fillings.length > 5)
            InkWell(
              onTap: () {
                ref.read(homeTabProvider.notifier).change(2);
                ref.read(reportTabProvider.notifier).change(3);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Center(
                  child: Text(
                    'Lihat semua ${fillings.length} riwayat →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyFuelState(
    BuildContext context,
    String recapId, {
    required VoidCallback onAdd,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.local_gas_station_rounded,
                color: Color(0xFFEF4444), size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Riwayat Pengisian BBM',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Mulai catat pengisian BBM agar estimasi sisa tangki akurat dan alert 0.5L berfungsi.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Catat Isi BBM Pertama',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonFuelCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 120, height: 16, color: Colors.grey.shade200),
                const SizedBox(height: 8),
                Container(width: 200, height: 12, color: Colors.grey.shade200),
                const SizedBox(height: 12),
                Container(
                    width: double.infinity,
                    height: 6,
                    color: Colors.grey.shade200),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorFuelCard(String error) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Gagal memuat estimasi BBM: $error',
              style: TextStyle(fontSize: 13, color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonFuelList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: List.generate(
            3,
            (index) => Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: index.isEven ? Colors.grey.shade50 : Colors.white,
                    border: Border(
                        bottom: index < 2
                            ? BorderSide(color: Colors.grey.shade100)
                            : BorderSide.none),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Container(
                          width: 36, height: 36, color: Colors.grey.shade200),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                width: 150,
                                height: 14,
                                color: Colors.grey.shade200),
                            const SizedBox(height: 6),
                            Container(
                                width: 100,
                                height: 10,
                                color: Colors.grey.shade200),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                )),
      ),
    );
  }

  Widget _buildErrorFuelList(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        'Gagal memuat riwayat: $error',
        style: TextStyle(fontSize: 13, color: Colors.red.shade700),
      ),
    );
  }

  Widget _buildFinanceAndServiceQuickCards(
      BuildContext context, WidgetRef ref) {
    final poolBalancesAsync = ref.watch(poolBalancesProvider);
    final serviceDueAsync = ref.watch(serviceDueProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        final cashCard = InkWell(
          onTap: () => ref.read(homeTabProvider.notifier).change(3),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet,
                            size: 18, color: const Color(0xFF2E7D32)),
                        const SizedBox(width: 8),
                        const Text(
                          'Saldo Kas',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 12, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 12),
                poolBalancesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Gagal memuat kas',
                      style: TextStyle(fontSize: 12)),
                  data: (pools) {
                    final utama = pools['utama'] ?? 0;
                    final tambahan = pools['tambahan'] ?? 0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kas Utama',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600)),
                            Text(currency.format(utama),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Kas Tambahan',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600)),
                            Text(currency.format(tambahan),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );

        final serviceCard = InkWell(
          onTap: () => ref.read(homeTabProvider.notifier).change(3),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.two_wheeler,
                            size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Servis Motor',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 12, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 12),
                serviceDueAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Gagal memuat servis',
                      style: TextStyle(fontSize: 12)),
                  data: (dueList) {
                    final urgent = dueList.where((d) => d.isUrgent).toList();
                    if (urgent.isNotEmpty) {
                      return Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 16, color: Colors.red.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${urgent.length} segera: ${urgent.map((u) => u.item.name).join(', ')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Semua jadwal servis aman',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );

        if (isNarrow) {
          return Column(
            children: [
              cashCard,
              const SizedBox(height: 12),
              serviceCard,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cashCard),
            const SizedBox(width: 16),
            Expanded(child: serviceCard),
          ],
        );
      },
    );
  }
}

class _WalletBalanceItem {
  final String id;
  final String name;
  final double balance;
  final IconData icon;
  final Color color;

  _WalletBalanceItem(this.id, this.name, this.balance, this.icon, this.color);
}
