import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_providers.dart';
import '../../services/sync_service.dart';
import '../home_screen.dart' show currency;
import '../fuel_filling_sheet.dart';
import 'transaction_form_sheet.dart';
import 'vehicle_log_sheet.dart';

class FinanceSummaryTab extends ConsumerWidget {
  final void Function(int tabIndex) onNavigateToTab;

  const FinanceSummaryTab({
    super.key,
    required this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(financeMonthProvider);
    final summaryAsync = ref.watch(monthSummaryProvider);
    final poolBalancesAsync = ref.watch(poolBalancesProvider);
    final accountBalancesAsync = ref.watch(accountBalancesProvider);
    final serviceDueAsync = ref.watch(serviceDueProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);

    final monthFormat = DateFormat('MMMM yyyy', 'id_ID');

    return RefreshIndicator(
      color: const Color(0xFF2E7D32),
      onRefresh: () async {
        try {
          await SyncService.sync();
        } catch (_) {}
        ref.invalidate(monthSummaryProvider);
        ref.invalidate(poolBalancesProvider);
        ref.invalidate(accountBalancesProvider);
        ref.invalidate(serviceDueProvider);
        ref.invalidate(vehiclesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // --- PEMILIH BULAN ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    ref.read(financeMonthProvider.notifier).previousMonth();
                  },
                ),
                Text(
                  monthFormat.format(selectedMonth),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    ref.read(financeMonthProvider.notifier).nextMonth();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- KARTU SALDO KAS & TOTAL REKENING ---
          _buildCashPoolCard(context, poolBalancesAsync, accountBalancesAsync),
          const SizedBox(height: 16),

          // --- AKSI CEPAT ---
          _buildQuickActions(context, ref, vehiclesAsync),
          const SizedBox(height: 16),

          // --- RINGKASAN DATA FINANSIAL BULAN INI ---
          summaryAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Gagal memuat ringkasan keuangan: $e'),
              ),
            ),
            data: (summary) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Profit per Pekerjaan
                  _buildProfitBreakdownCard(context, summary),
                  const SizedBox(height: 16),

                  // 2. Komisi Belum Cair (Jika ada)
                  if (summary.pendingIncome > 0) ...[
                    _buildPendingIncomeCard(
                        context, ref, summary.pendingIncome),
                    const SizedBox(height: 16),
                  ],

                  // 3. Efisiensi & Telemetri
                  _buildEfficiencyCard(context, summary),
                  const SizedBox(height: 16),

                  // 4. Ojol Rekap Harian Lama (Tampilan Terpisah)
                  _buildLegacyOjolCard(context, summary.legacyOjolNetEarning),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),

          // --- REMINDER SERVIS KENDARAAN JATUH TEMPO ---
          _buildServiceDueCard(context, serviceDueAsync),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCashPoolCard(
    BuildContext context,
    AsyncValue<Map<String, int>> poolAsync,
    AsyncValue<List<dynamic>> accountsAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saldo Kas & Rekening',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              InkWell(
                onTap: () => onNavigateToTab(2), // Buka tab rekening
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rekening',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          color: Colors.white, size: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          poolAsync.when(
            loading: () =>
                const Text('Memuat...', style: TextStyle(color: Colors.white)),
            error: (e, _) =>
                Text('Error: $e', style: const TextStyle(color: Colors.white)),
            data: (pools) {
              final utama = pools['utama'] ?? 0;
              final tambahan = pools['tambahan'] ?? 0;

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kas Utama (Kanvasing)',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currency.format(utama),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 36, width: 1, color: Colors.white24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kas Tambahan (Ojol)',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currency.format(tambahan),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  accountsAsync.when(
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                    data: (accounts) {
                      var total = 0;
                      for (final a in accounts) {
                        total += (a.balance as int);
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Likuiditas Semua Rekening',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            currency.format(total),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<dynamic>> vehiclesAsync,
  ) {
    return Row(
      children: [
        // Catat Komisi
        Expanded(
          child: _buildActionBtn(
            icon: Icons.payments,
            color: const Color(0xFF2E7D32),
            label: 'Catat Komisi',
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => const TransactionFormSheet(
                  initialKind: 'income',
                  initialActivity: 'kanvasing',
                  initialPool: 'utama',
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),

        // Catat BBM
        Expanded(
          child: _buildActionBtn(
            icon: Icons.local_gas_station,
            color: Colors.orange.shade800,
            label: 'Catat BBM',
            onTap: () {
              showFuelFillingSheet(context, null);
            },
          ),
        ),
        const SizedBox(width: 10),

        // Km Hari Ini
        Expanded(
          child: _buildActionBtn(
            icon: Icons.speed,
            color: Colors.blue.shade700,
            label: 'Km Hari Ini',
            onTap: () {
              vehiclesAsync.whenData((vehicles) {
                if (vehicles.isEmpty) {
                  onNavigateToTab(3); // Arahkan ke tab motor
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Tambahkan motor terlebih dahulu.')),
                  );
                  return;
                }
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => VehicleLogSheet(vehicle: vehicles.first),
                );
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitBreakdownCard(BuildContext context, dynamic summary) {
    final profits = summary.activityProfits as Map<String, dynamic>;
    final kanvasing = profits['kanvasing'];
    final ojol = profits['ojol'];
    final pribadi = profits['pribadi'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Profit per Pekerjaan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline,
                    size: 20, color: Colors.blueGrey),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Alokasi Biaya Motor'),
                      content: const Text(
                        'Biaya motor bersama (BBM & servis) dialokasikan secara adil ke Kanvasing, Ojol, dan Pribadi proporsional terhadap km masing-masing dengan metode sisa terbesar (Hamilton-Hare).\n\nProfit = Pemasukan − Biaya Langsung − Alokasi Biaya Motor.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Mengerti'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Peringatan Biaya Motor Belum Teralokasi
          if (summary.unallocatedVehicleCost > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Biaya motor belum teralokasi: ${currency.format(summary.unallocatedVehicleCost)} (karena km bulan ini belum dicatat di tab Motor).',
                      style:
                          TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Baris Kanvasing
          _buildJobProfitRow(
            label: 'Kanvasing (XL Satu)',
            color: Colors.green.shade700,
            income: kanvasing?.income ?? 0,
            directExpense: kanvasing?.directExpense ?? 0,
            allocatedVehicle: kanvasing?.allocatedVehicleCost ?? 0,
            profit: kanvasing?.profit ?? 0,
          ),
          const Divider(height: 24),

          // Baris Ojol
          _buildJobProfitRow(
            label: 'Ojol (Kas Tambahan)',
            color: Colors.blue.shade700,
            income: ojol?.income ?? 0,
            directExpense: ojol?.directExpense ?? 0,
            allocatedVehicle: ojol?.allocatedVehicleCost ?? 0,
            profit: ojol?.profit ?? 0,
          ),
          const Divider(height: 24),

          // Baris Pribadi
          _buildJobProfitRow(
            label: 'Pribadi',
            color: Colors.purple.shade700,
            income: pribadi?.income ?? 0,
            directExpense: pribadi?.directExpense ?? 0,
            allocatedVehicle: pribadi?.allocatedVehicleCost ?? 0,
            profit: pribadi?.profit ?? 0,
            isPersonal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildJobProfitRow({
    required String label,
    required Color color,
    required int income,
    required int directExpense,
    required int allocatedVehicle,
    required int profit,
    bool isPersonal = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            Text(
              currency.format(profit),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color:
                    profit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isPersonal
                  ? 'Pengeluaran: ${currency.format(directExpense)} · Motor: ${currency.format(allocatedVehicle)}'
                  : 'Masuk: ${currency.format(income)} · Biaya: ${currency.format(directExpense)} · Motor: ${currency.format(allocatedVehicle)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPendingIncomeCard(
      BuildContext context, WidgetRef ref, int pendingAmount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_top, color: Colors.amber.shade900, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Komisi Belum Cair',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  Text(
                    currency.format(pendingAmount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () =>
                onNavigateToTab(1), // Buka tab transaksi untuk melihat pending
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child:
                const Text('Lihat Transaksi', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEfficiencyCard(BuildContext context, dynamic summary) {
    final biayaPerKm = summary.biayaMotorPerKm as double?;
    final ojolPerKm = summary.ojolIncomePerKm as double?;
    final ojolPerHour = summary.ojolIncomePerHour as double?;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Efisiensi & Rasio',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  title: 'Biaya Motor/km',
                  value: biayaPerKm != null
                      ? 'Rp ${biayaPerKm.toStringAsFixed(0)}/km'
                      : '-',
                  icon: Icons.two_wheeler,
                  color: Colors.orange.shade800,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  title: 'Ojol/km',
                  value: ojolPerKm != null
                      ? 'Rp ${ojolPerKm.toStringAsFixed(0)}/km'
                      : '-',
                  icon: Icons.near_me,
                  color: Colors.blue.shade700,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  title: 'Ojol/Jam',
                  value: ojolPerHour != null
                      ? 'Rp ${ojolPerHour.toStringAsFixed(0)}/jam'
                      : '-',
                  icon: Icons.timer,
                  color: Colors.teal.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildLegacyOjolCard(BuildContext context, int legacyOjolNetEarning) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Slate 100
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history_toggle_off,
                      size: 18, color: Colors.blueGrey.shade700),
                  const SizedBox(width: 6),
                  const Text(
                    'Ojol (Rekap Harian Lama)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Data ShopeeFood/Grab/Mandiri/BCA rekap lama.\nTerpisah dari kas ledger baru.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          Text(
            currency.format(legacyOjolNetEarning),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: legacyOjolNetEarning >= 0
                  ? Colors.green.shade800
                  : Colors.red.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDueCard(
      BuildContext context, AsyncValue<List<dynamic>> serviceDueAsync) {
    return serviceDueAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (dueList) {
        final urgentItems = dueList.where((d) => d.isUrgent).toList();
        if (urgentItems.isEmpty) return const SizedBox();

        return InkWell(
          onTap: () => onNavigateToTab(3), // Tab Motor
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.build_circle, color: Colors.red.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${urgentItems.length} Servis Motor Jatuh Tempo / Segera',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.red.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        urgentItems.map((u) => u.item.name).join(', '),
                        style:
                            TextStyle(fontSize: 12, color: Colors.red.shade800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: Colors.red),
              ],
            ),
          ),
        );
      },
    );
  }
}
