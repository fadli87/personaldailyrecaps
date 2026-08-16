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
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recapsProvider);
          ref.invalidate(platformDistributionProvider);
          try {
            await ref.read(recapsProvider.future);
            await ref.read(platformDistributionProvider.future);
          } catch (_) {}
        },
        child: recapsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Gagal memuat data: $err')),
          data: (recaps) {
            return platformAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Gagal memuat platform: $err')),
              data: (platformData) {
                if (recaps.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 100),
                      Center(child: Text('Belum ada data transaksi.')),
                    ],
                  );
                }

                // Kalkulasi KPI
                double totalIncome = 0;
                double totalExpense = 0;
                double totalNetEarnings = 0;
                
                // Kalkulasi Kendaraan (Akumulasi menggunakan precalculated fields dari DB)
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
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        // --- SECTION 1: KPI FINANCIAL CARDS ---
                        _buildFinancialKPIs(isDesktop, totalNetEarnings, totalIncome, totalExpense),
                        const SizedBox(height: 20),

                        // --- SECTION 2: VEHICLE TELEMETRY CARD ---
                        _buildVehicleTelemetry(totalJarak, totalLiterTerpakai),
                        const SizedBox(height: 20),

                        // --- SECTION 3: CHARTS ---
                        if (isDesktop) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildChartContainer(
                                  title: 'Tren Keuntungan Bersih (7 Hari Terakhir)',
                                  child: _buildLoyverseLineChart(chartRecaps),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: _buildChartContainer(
                                  title: 'Penjualan per Platform',
                                  child: _buildLoyversePieChart(platformData),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildChartContainer(
                            title: 'Perbandingan Pemasukan vs Pengeluaran Harian',
                            child: _buildLoyverseBarChart(chartRecaps),
                          ),
                        ] else ...[
                          _buildChartContainer(
                            title: 'Tren Keuntungan Bersih (7 Hari Terakhir)',
                            child: _buildLoyverseLineChart(chartRecaps),
                          ),
                          const SizedBox(height: 16),
                          _buildChartContainer(
                            title: 'Penjualan per Platform',
                            child: _buildLoyversePieChart(platformData),
                          ),
                          const SizedBox(height: 16),
                          _buildChartContainer(
                            title: 'Perbandingan Pemasukan vs Pengeluaran Harian',
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

  // ============================================================================
  // WIDGET BUILDERS
  // ============================================================================

  Widget _buildFinancialKPIs(bool isDesktop, double net, double income, double expense) {
    final kpis = [
      _KpiData('Keuntungan Bersih', net, Icons.payments, const Color(0xFF2E7D32)), // Hijau tua
      _KpiData('Total Pemasukan', income, Icons.arrow_upward, const Color(0xFF4CAF50)), // Hijau muda
      _KpiData('Total Pengeluaran', expense, Icons.arrow_downward, const Color(0xFFD32F2F)), // Merah
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
      itemCount: kpis.length,
      itemBuilder: (_, i) => _buildLoyverseKpiCard(kpis[i]),
    );
  }

  Widget _buildLoyverseKpiCard(_KpiData kpi) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // Shadow sangat halus ala Loyverse
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kpi.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(kpi.icon, color: kpi.color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                kpi.title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currency.format(kpi.value),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- KARTU TELEMETRI KENDARAAN ---
  Widget _buildVehicleTelemetry(double totalKm, double totalLiter) {
    double efisiensi = totalLiter > 0 ? (totalKm / totalLiter) : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)], // Cyber/Dark theme
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PERFORMA KENDARAAN (AKUMULASI)',
            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _telemetryItem(Icons.speed, '${totalKm.toStringAsFixed(1)} KM', 'Jarak Tempuh'),
              _telemetryItem(Icons.local_gas_station, '${totalLiter.toStringAsFixed(1)} L', 'BBM Terpakai'),
              _telemetryItem(Icons.eco, '${efisiensi.toStringAsFixed(1)} KM/L', 'Efisiensi Rata-rata', color: Colors.greenAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _telemetryItem(IconData icon, String value, String label, {Color color = Colors.white}) {
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

  Widget _buildChartContainer({required String title, required Widget child}) {
    return Container(
      height: 320,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      ),
    );
  }

  // ============================================================================
  // CHARTS (LOYVERSE STYLE)
  // ============================================================================

  Widget _buildLoyverseLineChart(List<DailyRecap> recaps) {
    if (recaps.isEmpty) return const Center(child: Text('Tidak cukup data'));

    final spots = <FlSpot>[];
    for (int i = 0; i < recaps.length; i++) {
      spots.add(FlSpot(i.toDouble(), recaps[i].netEarning));
    }

    const primaryColor = Color(0xFF2E7D32);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1, dashArray: [5, 5]),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < recaps.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('dd/MM').format(recaps[idx].tanggal),
                      style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600),
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
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatCompactNumber(value),
                  style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600),
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
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.2), primaryColor.withOpacity(0.0)],
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
      const Color(0xFF2E7D32), // Hijau
      const Color(0xFF1565C0), // Biru
      const Color(0xFFF9A825), // Kuning
      const Color(0xFFD84315), // Jingga
      const Color(0xFFAD1457), // Pink
      const Color(0xFF4527A0), // Ungu
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
        radius: 50,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 35,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: Scrollbar(
            child: ListView(
              shrinkWrap: true,
              children: data.entries.toList().asMap().entries.map((item) {
                final color = colors[item.key % colors.length];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${item.value.key}: ${currency.format(item.value.value)}',
                          style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.w600),
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
              color: const Color(0xFF4CAF50),
              width: 8,
              borderRadius: BorderRadius.circular(2),
            ),
            BarChartRodData(
              toY: recaps[i].totalExpense,
              color: const Color(0xFFFF7043),
              width: 8,
              borderRadius: BorderRadius.circular(2),
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
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1, dashArray: [5, 5]),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < recaps.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('dd/MM').format(recaps[idx].tanggal),
                      style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600),
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
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatCompactNumber(value),
                  style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600),
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
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }
}

class _KpiData {
  final String title;
  final double value;
  final IconData icon;
  final Color color;

  _KpiData(this.title, this.value, this.icon, this.color);
}
