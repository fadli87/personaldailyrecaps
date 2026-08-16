import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/recap_providers.dart';
import '../models/daily_recap.dart';
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
                    children: const [
                      SizedBox(height: 180),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.assignment_late_outlined, size: 64, color: Colors.grey),
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
                    ],
                  );
                }

                // Kalkulasi KPI
                double totalIncome = 0;
                double totalExpense = 0;
                double totalNetEarnings = 0;
                
                // Kalkulasi Kendaraan
                double totalJarak = 0;
                double totalLiterTerpakai = 0;

                for (var r in recaps) {
                  totalIncome += r.totalIncome;
                  totalExpense += r.totalExpense;
                  totalNetEarnings += r.netEarning;
                  totalJarak += r.jarakTempuh; 
                  totalLiterTerpakai += r.literTerpakai;
                }

                // Ambil 7 hari TERBARU secara kronologis (terlama -> terbaru) untuk grafik
                final chartRecaps = recaps.take(7).toList().reversed.toList();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 850;
                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        // Header Selamat Datang
                        _buildHeader(),
                        const SizedBox(height: 24),

                        // --- SECTION 1: KPI FINANCIAL CARDS (GRADASI PREMIUM) ---
                        _buildFinancialKPIs(isDesktop, totalNetEarnings, totalIncome, totalExpense),
                        const SizedBox(height: 24),

                        // --- SECTION 2: VEHICLE TELEMETRY CARD (MODERN GLASSMORPHISM EFFECT) ---
                        _buildVehicleTelemetry(totalJarak, totalLiterTerpakai),
                        const SizedBox(height: 24),

                        // --- SECTION 3: CHARTS ---
                        if (isDesktop) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildChartContainer(
                                  title: 'Tren Keuntungan Bersih (7 Hari Terakhir)',
                                  subtitle: 'Pantau stabilitas harian pendapatan bersih Anda',
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
                            title: 'Perbandingan Pemasukan vs Pengeluaran Harian',
                            subtitle: 'Rasio rasional antara modal BBM/Operasional dan Omset harian',
                            child: _buildLoyverseBarChart(chartRecaps),
                          ),
                        ] else ...[
                          _buildChartContainer(
                            title: 'Tren Keuntungan Bersih (7 Hari Terakhir)',
                            subtitle: 'Pantau stabilitas harian pendapatan bersih Anda',
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
                            title: 'Perbandingan Pemasukan vs Pengeluaran Harian',
                            subtitle: 'Rasio rasional antara modal BBM/Operasional dan Omset harian',
                            child: _buildLoyverseBarChart(chartRecaps),
                          ),
                        ],
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
  Widget _buildHeader() {
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting, Pak Fadli!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ringkasan data operasional harian terupdate.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blueGrey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE2F1E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.offline_bolt_rounded, color: Color(0xFF2E7D32), size: 16),
              SizedBox(width: 4),
              Text(
                'Supabase Sync',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 1: FINANCIAL CARDS DENGAN GRADASI PREMIUM & SHADOW SOFT ---
  Widget _buildFinancialKPIs(bool isDesktop, double net, double income, double expense) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isDesktop) {
          return Row(
            children: [
              Expanded(child: _buildPremiumKpiCard(
                title: 'Keuntungan Bersih',
                value: net,
                icon: Icons.wallet_rounded,
                colors: [const Color(0xFF16A34A), const Color(0xFF15803D)], // Hijau gradasi
                iconColor: Colors.white.withOpacity(0.2),
                isMain: true,
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildPremiumKpiCard(
                title: 'Total Pemasukan',
                value: income,
                icon: Icons.trending_up_rounded,
                colors: [const Color(0xFF3B82F6), const Color(0xFF2563EB)], // Biru gradasi
                iconColor: Colors.white.withOpacity(0.2),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildPremiumKpiCard(
                title: 'Total Pengeluaran',
                value: expense,
                icon: Icons.trending_down_rounded,
                colors: [const Color(0xFFEF4444), const Color(0xFFDC2626)], // Merah gradasi
                iconColor: Colors.white.withOpacity(0.2),
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
                isMain: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildPremiumKpiCard(
                    title: 'Total Pemasukan',
                    value: income,
                    icon: Icons.trending_up_rounded,
                    colors: [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                    iconColor: Colors.white.withOpacity(0.2),
                    isCompact: true,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _buildPremiumKpiCard(
                    title: 'Total Pengeluaran',
                    value: expense,
                    icon: Icons.trending_down_rounded,
                    colors: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                    iconColor: Colors.white.withOpacity(0.2),
                    isCompact: true,
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
    bool isMain = false,
    bool isCompact = false,
  }) {
    return Container(
      height: isMain ? 115 : (isCompact ? 95 : 110),
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
                if (isMain) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 12, color: Colors.white.withOpacity(0.7)),
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
    );
  }

  // --- KARTU TELEMETRI KENDARAAN (GLASSMORPHISM / NEUMORPHIC CARD) ---
  Widget _buildVehicleTelemetry(double totalKm, double totalLiter) {
    double efisiensi = totalLiter > 0 ? (totalKm / totalLiter) : 0.0;

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
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AKUMULASI TELEMETRI KENDARAAN',
                style: TextStyle(
                  color: Color(0xFF94A3B8), // Slate 400
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              if (efisiensi > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: efficiencyColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: efficiencyColor.withOpacity(0.3), width: 1),
                  ),
                  child: Text(
                    efficiencyStatus,
                    style: TextStyle(
                      color: efficiencyColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
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
                '${totalKm.toStringAsFixed(1)}', 
                'KM', 
                'Jarak Tempuh',
                const Color(0xFF38BDF8), // Light Blue
              ),
              Container(width: 1, height: 40, color: Colors.white10),
              _telemetryItem(
                Icons.local_gas_station_rounded, 
                '${totalLiter.toStringAsFixed(1)}', 
                'Liter', 
                'BBM Terpakai',
                const Color(0xFFFB923C), // Orange
              ),
              Container(width: 1, height: 40, color: Colors.white10),
              _telemetryItem(
                Icons.eco_rounded, 
                '${efisiensi.toStringAsFixed(1)}', 
                'KM/L', 
                'Efisiensi',
                const Color(0xFF4ADE80), // Light Green
                isEco: true,
              ),
            ],
          ),
          if (efisiensi > 0) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white30, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Performa dihitung berdasarkan odometer harian dibagi liter BBM terisi.',
                    style: TextStyle(
                      color: Colors.blueGrey.shade400,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _telemetryItem(
    IconData icon, 
    String value, 
    String unit, 
    String label, 
    Color iconColor, {
    bool isEco = false,
  }) {
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
            color: const Color(0xFF0F172A).withOpacity(0.03), // Shadow sangat redup & rapi
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
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                colors: [primaryColor.withOpacity(0.18), primaryColor.withOpacity(0.0)],
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
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
}
