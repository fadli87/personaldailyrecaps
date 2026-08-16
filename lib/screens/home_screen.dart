import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/recap_providers.dart';
import '../services/sync_service.dart';
import 'daily_recap_detail_screen.dart';
import 'dashboard_screen.dart';
import 'report_screen.dart';

final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final dateFmt = DateFormat('EEEE, d MMM yyyy', 'id_ID');

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final recapsAsync = ref.watch(recapsProvider);

    final List<Widget> pages = [
      // Halaman 0: Dashboard Eksekutif
      const DashboardScreen(),
      // Halaman 1: Daftar Rekap Harian
      RefreshIndicator(
        onRefresh: () async {
          await SyncService.sync();
          ref.invalidate(recapsProvider);
          try {
            await ref.read(recapsProvider.future);
          } catch (_) {}
        },
        child: recapsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: ListView(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Center(child: Text('Gagal memuat data: $err')),
                const SizedBox(height: 8),
                Center(
                  child: ElevatedButton(
                    onPressed: () => ref.invalidate(recapsProvider),
                    child: const Text('Coba Lagi'),
                  ),
                ),
              ],
            ),
          ),
          data: (recaps) {
            if (recaps.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100),
                  Center(child: Text('Belum ada rekap. Tekan + untuk mulai.')),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: recaps.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = recaps[i];
                final positif = r.netEarning >= 0;
                return ListTile(
                  title: Text(dateFmt.format(r.tanggal)),
                  subtitle: Text(
                    'Cash Akhir: ${currency.format(r.cashAkhir)}  ·  Saldo App: ${currency.format(r.saldoAkhirApp)}',
                  ),
                  trailing: Text(
                    (positif ? '+' : '') + currency.format(r.netEarning),
                    style: TextStyle(
                      color: positif ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DailyRecapDetailScreen(recapId: r.id),
                      ),
                    );
                    ref.invalidate(recapsProvider);
                  },
                );
              },
            );
          },
        ),
      ),
      // Halaman 2: Laporan Periodik & Ekspor
      const ReportScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 
            ? 'Dashboard Eksekutif' 
            : (_currentIndex == 1 ? 'SF Daily Recap' : 'Laporan Bulanan & Ekspor')),
        actions: _currentIndex == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    ref.invalidate(recapsProvider);
                    ref.invalidate(platformDistributionProvider);
                  },
                )
              ]
            : null,
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Segarkan data saat ganti tab agar dashboard selalu up-to-date
          ref.invalidate(recapsProvider);
          ref.invalidate(platformDistributionProvider);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Rekap Harian',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment_outlined),
            activeIcon: Icon(Icons.assessment),
            label: 'Laporan',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Rekap Hari Ini'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DailyRecapDetailScreen(recapId: null)),
                );
                ref.invalidate(recapsProvider);
              },
            )
          : null,
    );
  }
}
