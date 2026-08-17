import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/recap_providers.dart';
import '../services/sync_service.dart';
import 'daily_recap_detail_screen.dart';
import 'dashboard_screen.dart';
import 'report_screen.dart';
import 'profile_screen.dart';
import 'pin_lock_screen.dart';

final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final dateFmt = DateFormat('EEEE, d MMM yyyy', 'id_ID');

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  bool _isLockScreenShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndShowPinLock();
    }
  }

  Future<void> _checkAndShowPinLock() async {
    if (_isLockScreenShowing) return;

    final prefs = await SharedPreferences.getInstance();
    final isPinEnabled = prefs.getBool('pin_lock_enabled') ?? false;
    final hasPin = prefs.getString('app_pin') != null;

    if (isPinEnabled && hasPin) {
      setState(() {
        _isLockScreenShowing = true;
      });
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PinLockScreen(mode: PinMode.normalLock),
        ),
      );
      setState(() {
        _isLockScreenShowing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(homeTabProvider);
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
      // Halaman 3: Profil & Keamanan
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentIndex == 0
              ? 'Dashboard Eksekutif'
              : (currentIndex == 1
                  ? 'Personal Finance & Recap'
                  : (currentIndex == 2 ? 'Laporan Bulanan & Ekspor' : 'Profil & Keamanan')),
        ),
        actions: currentIndex == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () async {
                    if (!context.mounted) return;
                    final scaffold = ScaffoldMessenger.of(context);
                    scaffold.showSnackBar(
                      const SnackBar(content: Text('Sinkronisasi data sedang berjalan...')),
                    );
                    try {
                      await SyncService.sync();
                      ref.invalidate(recapsProvider);
                      ref.invalidate(platformDistributionProvider);
                      scaffold.showSnackBar(
                        const SnackBar(content: Text('Sinkronisasi data sukses!')),
                      );
                    } catch (e) {
                      scaffold.showSnackBar(
                        SnackBar(content: Text('Sinkronisasi gagal: $e')),
                      );
                    }
                  },
                )
              ]
            : null,
      ),
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(homeTabProvider.notifier).change(index);
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
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
      floatingActionButton: currentIndex == 1
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
