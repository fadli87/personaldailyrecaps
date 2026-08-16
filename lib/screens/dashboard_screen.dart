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
          error: (err, stack) => Center(child: Text('Gagal memuat data dashboard: $err')),
          data: (recaps) {
            return platformAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Gagal memuat data platform: $err')),
              data: (platformData) {
                if (recaps.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 100),
                      Center(child: Text('Belum ada data untuk dianalisis.')),
                    ],
                  );
                }

                // Ambil data dalam urutan kronologis (terlama -> terbaru) untuk grafik tren
                final chronologicalRecaps = recaps.reversed.toList();
                
                // Hitung KPI ringkasan
                double totalIncome = 0;
                double totalExpense = 0;
                double totalNetEarnings = 0;
                double totalPettyCash = 0;

                for (var r in recaps) {
                  totalIncome += r.totalIncome;
                  totalExpense += r.totalExpense;
                  totalNetEarnings += r.netEarning;
                }
                if (recaps.isNotEmpty) {
                  totalPettyCash = recaps.first.pettyCashTotal; // Petty cash terbaru
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 850;
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Section 1: KPI Cards
                        _buildKpiGrid(
                          isDesktop: isDesktop,
                          income: totalIncome,
                          expense: totalExpense,
                          earnings: totalNetEarnings,
                          pettyCash: totalPettyCash,
                        ),
                        const SizedBox(height: 24),

                        // Section 2: Charts
                        if (isDesktop) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildChartCard(
                                  title: 'Tren Keuntungan Bersih (7 Hari Terakhir)',
                                  chart: _buildLineChart(chronologicalRecaps.take(7).toList()),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: _buildChartCard(
                                  title: 'Distribusi Penjualan per Platform',
                                  chart: _buildPieChart(platformData),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildChartCard(
                            title: 'Perbandingan Pemasukan vs Pengeluaran Harian',
                            chart: _buildBarChart(chronologicalRecaps.take(7).toList()),
                          ),
                        ] else ...[
                          _buildChartCard(
                            title: 'Tren Keuntungan Bersih (7 Hari Terakhir)',
                            chart: _buildLineChart(chronologicalRecaps.take(7).toList()),
                          ),
                          const SizedBox(height: 16),
                          _buildChartCard(
                            title: 'Distribusi Penjualan per Platform',
                            chart: _buildPieChart(platformData),
                          ),
                          const SizedBox(height: 16),
                          _buildChartCard(
                            title: 'Perbandingan Pemasukan vs Pengeluaran Harian',
                            chart: _buildBarChart(chronologicalRecaps.take(7).toList()),
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

  // --- UI Widget Helpers ---

  Widget _buildKpiGrid({
    required bool isDesktop,
    required double income,
    required double expense,
    required double earnings,
    required double pettyCash,
  }) {
    final kpis = [
      _KpiData(
        title: 'Total Pemasukan',
        value: income,
        colors: [const Color(0xFF4CAF50), const Color(0xFF2E7D32)],
        icon: Icons.trending_up,
      ),
      _KpiData(
        title: 'Total Pengeluaran',
        value: expense,
        colors: [const Color(0xFFFF7043), const Color(0xFFD84315)],
        icon: Icons.trending_down,
      ),
      _KpiData(
        title: 'Keuntungan Bersih',
        value: earnings,
        colors: [const Color(0xFF00ACC1), const Color(0xFF006064)],
        icon: Icons.payments,
      ),
      _KpiData(
        title: 'Petty Cash Terakhir',
        value: pettyCash,
        colors: [const Color(0xFF7E57C2), const Color(0xFF4527A0)],
        icon: Icons.account_balance_wallet,
      ),
    ];

    if (isDesktop) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.2,
        ),
        itemCount: kpis.length,
        itemBuilder: (_, i) => _buildKpiCard(kpis[i]),
      );
    } else {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
        ),
        itemCount: kpis.length,
        itemBuilder: (_, i) => _buildKpiCard(kpis[i]),
      );
    }
  }

  Widget _buildKpiCard(_KpiData kpi) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: kpi.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  kpi.title,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Icon(kpi.icon, color: Colors.white70, size: 20),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                currency.format(kpi.value),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget chart}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: chart,
            ),
          ],
        ),
      ),
    );
  }

  // --- Charts Building ---

  Widget _buildLineChart(List<DailyRecap> recaps) {
    if (recaps.isEmpty) return const Center(child: Text('Tidak cukup data'));

    final spots = <FlSpot>[];
    for (int i = 0; i < recaps.length; i++) {
      spots.add(FlSpot(i.toDouble(), recaps[i].netEarning));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
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
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
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
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatCompactNumber(value),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
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
            color: const Color(0xFF2E7D32),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0x262E7D32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> data) {
    if (data.isEmpty) return const Center(child: Text('Belum ada data penjualan platform'));

    final colors = [
      const Color(0xFF2E7D32),
      const Color(0xFF1565C0),
      const Color(0xFFD84315),
      const Color(0xFFAD1457),
      const Color(0xFFF9A825),
      const Color(0xFF4527A0),
      const Color(0xFF00838F),
    ];

    int colorIdx = 0;
    final sections = data.entries.map((entry) {
      final color = colors[colorIdx % colors.length];
      colorIdx++;
      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: entry.key,
        radius: 65,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
        ),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 40,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Legend
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.entries.toList().asMap().entries.map((item) {
            final idx = item.key;
            final entry = item.value;
            final color = colors[idx % colors.length];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.key}: ${_formatCompactNumber(entry.value)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBarChart(List<DailyRecap> recaps) {
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
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: recaps[i].totalExpense,
              color: const Color(0xFFFF7043),
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
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
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
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
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatCompactNumber(value),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
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

  // --- Math/Helpers ---

  static String _formatCompactNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toStringAsFixed(0);
  }
}

class _KpiData {
  final String title;
  final double value;
  final List<Color> colors;
  final IconData icon;

  _KpiData({
    required this.title,
    required this.value,
    required this.colors,
    required this.icon,
  });
}
