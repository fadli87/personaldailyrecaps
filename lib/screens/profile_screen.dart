import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../providers/finance_providers.dart';
import '../providers/recap_providers.dart';
import '../services/sync_service.dart';
import 'pin_lock_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();

  // Rekening Bank
  final _mandiriAccCtrl = TextEditingController();
  final _mandiriNameCtrl = TextEditingController();
  final _bcaAccCtrl = TextEditingController();
  final _bcaNameCtrl = TextEditingController();

  bool _isPinEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text = prefs.getString('user_name') ?? '';
      _phoneCtrl.text = prefs.getString('user_phone') ?? '';
      _vehicleCtrl.text = prefs.getString('user_vehicle') ?? '';

      _mandiriAccCtrl.text = prefs.getString('bank_mandiri_acc') ?? '';
      _mandiriNameCtrl.text = prefs.getString('bank_mandiri_name') ?? '';
      _bcaAccCtrl.text = prefs.getString('bank_bca_acc') ?? '';
      _bcaNameCtrl.text = prefs.getString('bank_bca_name') ?? '';

      _isPinEnabled = prefs.getBool('pin_lock_enabled') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameCtrl.text.trim());
    await prefs.setString('user_phone', _phoneCtrl.text.trim());
    await prefs.setString('user_vehicle', _vehicleCtrl.text.trim());

    await prefs.setString('bank_mandiri_acc', _mandiriAccCtrl.text.trim());
    await prefs.setString('bank_mandiri_name', _mandiriNameCtrl.text.trim());
    await prefs.setString('bank_bca_acc', _bcaAccCtrl.text.trim());
    await prefs.setString('bank_bca_name', _bcaNameCtrl.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil disimpan'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  Future<void> _togglePinLock(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final currentPin = prefs.getString('app_pin');

    if (value) {
      // Mengaktifkan kunci PIN
      if (currentPin == null || currentPin.isEmpty) {
        // Belum ada PIN, arahkan ke layar pembuatan PIN baru
        if (!mounted) return;
        final newPin = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => const PinLockScreen(mode: PinMode.setup),
          ),
        );
        if (newPin != null && newPin.isNotEmpty) {
          await prefs.setString('app_pin', newPin);
          await prefs.setBool('pin_lock_enabled', true);
          setState(() {
            _isPinEnabled = true;
          });
        } else {
          // Batal membuat PIN
          setState(() {
            _isPinEnabled = false;
          });
        }
      } else {
        // PIN sudah ada, langsung aktifkan
        await prefs.setBool('pin_lock_enabled', true);
        setState(() {
          _isPinEnabled = true;
        });
      }
    } else {
      // Menonaktifkan kunci PIN -> butuh verifikasi PIN saat ini terlebih dahulu
      if (!mounted) return;
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const PinLockScreen(mode: PinMode.verify),
        ),
      );
      if (verified == true) {
        await prefs.setBool('pin_lock_enabled', false);
        setState(() {
          _isPinEnabled = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kunci PIN dinonaktifkan')),
          );
        }
      } else {
        // Verifikasi gagal atau dibatalkan, biarkan switch tetap aktif
        setState(() {
          _isPinEnabled = true;
        });
      }
    }
  }

  Future<void> _changePin() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Verifikasi PIN lama
    if (!mounted) return;
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const PinLockScreen(mode: PinMode.verify),
      ),
    );

    if (verified == true) {
      // 2. Set PIN baru
      if (!mounted) return;
      final newPin = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => const PinLockScreen(mode: PinMode.setup),
        ),
      );
      if (newPin != null && newPin.isNotEmpty) {
        await prefs.setString('app_pin', newPin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN Keamanan berhasil diperbarui'),
              backgroundColor: Color(0xFF2E7D32),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _vehicleCtrl.dispose();
    _mandiriAccCtrl.dispose();
    _mandiriNameCtrl.dispose();
    _bcaAccCtrl.dispose();
    _bcaNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final syncLogs = ref.watch(syncLogsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // CARD PROFIL
          Card(
            color: Colors.white,
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFE2F1E8),
                        radius: 24,
                        child: Icon(Icons.person,
                            color: Color(0xFF2E7D32), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Profil Pengemudi',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Telepon / WA',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _vehicleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kendaraan / Plat Nomor',
                      prefixIcon: Icon(Icons.directions_car_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan Profil'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // CARD KEAMANAN
          Card(
            color: Colors.white,
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFFEE2E2),
                        radius: 24,
                        child:
                            Icon(Icons.security, color: Colors.red, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Keamanan Aplikasi',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    activeThumbColor: const Color(0xFF2E7D32),
                    title: const Text(
                      'Kunci PIN Aplikasi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                        'Minta kode PIN keamanan setiap kali aplikasi dibuka.'),
                    value: _isPinEnabled,
                    onChanged: _togglePinLock,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_isPinEnabled) ...[
                    const Divider(height: 16),
                    ListTile(
                      leading: const Icon(Icons.lock_reset,
                          color: Color(0xFF2E7D32)),
                      title: const Text(
                        'Ubah PIN Keamanan',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle:
                          const Text('Ganti kode akses PIN 4-digit Anda.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changePin,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // CARD REKENING BANK
          Card(
            color: Colors.white,
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFEFF6FF),
                        radius: 24,
                        child: Icon(Icons.account_balance,
                            color: Colors.blue, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Informasi Rekening Bank',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Bank Mandiri',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _mandiriAccCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Rekening Mandiri',
                      prefixIcon: Icon(Icons.credit_card),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _mandiriNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Pemilik Rekening',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Bank BCA',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bcaAccCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Rekening BCA',
                      prefixIcon: Icon(Icons.credit_card),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bcaNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Pemilik Rekening',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // CARD CADANGAN & EKSPOR DATA
          Card(
            color: Colors.white,
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFE8F5E9),
                        radius: 24,
                        child: Icon(Icons.storage_outlined,
                            color: Color(0xFF2E7D32), size: 24),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cadangan Data & Ekspor',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Database lokal SQLite & laporan CSV',
                            style:
                                TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEFF6FF),
                      child: Icon(Icons.backup_outlined, color: Colors.blue),
                    ),
                    title: const Text(
                      'Cadangkan Database (.db)',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Salin dan bagikan file sf_daily_recap.db (berisi semua tabel & data lokal)',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    trailing: OutlinedButton(
                      onPressed: _backupDatabase,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cadangkan'),
                    ),
                  ),
                  const Divider(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFF0FDF4),
                      child: Icon(Icons.table_chart_outlined,
                          color: Color(0xFF2E7D32)),
                    ),
                    title: const Text(
                      'Ekspor CSV Transaksi',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Unduh data transaksi bulanan (bisa dibuka di Excel / Google Sheets)',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    trailing: OutlinedButton(
                      onPressed: _exportMonthlyTransactionsCsv,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Ekspor'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // CARD SINKRONISASI
          Card(
            color: Colors.white,
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFEFF6FF),
                            radius: 24,
                            child: Icon(Icons.cloud_sync,
                                color: Colors.blue, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Supabase Cloud Sync',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.sync_outlined, color: Colors.blue),
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
                                  content: Text('Sinkronisasi selesai dipicu')),
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
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Email Akun:',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      Expanded(
                        child: Text(
                          supabaseUser?.email ?? 'Tidak Terdeteksi',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Keluar Akun'),
                            content: const Text(
                                'Apakah Anda yakin ingin keluar dari akun Anda?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Batal'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Keluar',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await Supabase.instance.client.auth.signOut();

                          // Hapus pin keamanan lokal demi keamanan
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('app_pin');
                          await prefs.setBool('pin_lock_enabled', false);

                          if (context.mounted) {
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text('Anda telah keluar dari akun')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text('KELUAR DARI AKUN',
                          style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Riwayat Log Sinkronisasi:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListView.builder(
                      itemCount: syncLogs.length,
                      itemBuilder: (context, idx) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            syncLogs[syncLogs.length -
                                1 -
                                idx], // logs terbaru di atas
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontFamily: 'monospace'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Aplikasi Rekap Harian v1.0.0\n© 2026 D\'Azhars Studio',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black38, fontSize: 11),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _backupDatabase() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dbPath = await getDatabasesPath();
      final originalFile = File(p.join(dbPath, 'sf_daily_recap.db'));
      if (!await originalFile.exists()) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
                'File database sf_daily_recap.db belum ditemukan di perangkat'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final tempDir = await getTemporaryDirectory();
      final backupPath =
          p.join(tempDir.path, 'sf_daily_recap_backup_$timestamp.db');
      await originalFile.copy(backupPath);

      await Share.shareXFiles(
        [
          XFile(backupPath,
              mimeType: 'application/x-sqlite3',
              name: 'sf_daily_recap_$timestamp.db')
        ],
        subject: 'Cadangan Database SF Daily Recap ($timestamp)',
        text: 'File cadangan database lokal SF Daily Recap (sf_daily_recap.db)',
      );

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('File cadangan database siap dibagikan/disimpan'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Gagal mencadangkan database: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _exportMonthlyTransactionsCsv() async {
    DateTime selectedMonth =
        DateTime(DateTime.now().year, DateTime.now().month, 1);

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final monthFormat = DateFormat('MMMM yyyy', 'id_ID');
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.table_chart_outlined,
                          color: Color(0xFF2E7D32)),
                      const SizedBox(width: 10),
                      Text(
                        'Ekspor CSV Transaksi',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pilih bulan transaksi yang ingin diekspor ke file CSV:',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            setSheetState(() {
                              selectedMonth = DateTime(
                                selectedMonth.year,
                                selectedMonth.month - 1,
                                1,
                              );
                            });
                          },
                        ),
                        Text(
                          monthFormat.format(selectedMonth),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            setSheetState(() {
                              selectedMonth = DateTime(
                                selectedMonth.year,
                                selectedMonth.month + 1,
                                1,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _generateAndShareCsv(selectedMonth);
                      },
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text(
                        'EKSPOR & BAGIKAN CSV',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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

  Future<void> _generateAndShareCsv(DateTime month) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ledgerService = ref.read(ledgerServiceProvider);
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);

      final txs = await ledgerService.getTransactions(
        startDate: startDate,
        endDate: endDate,
      );

      if (txs.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Tidak ada transaksi pada ${DateFormat("MMMM yyyy", "id_ID").format(month)}',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final accounts = await ledgerService.getAccounts();
      final accountsMap = {for (var a in accounts) a.id: a.name};

      final buffer = StringBuffer();
      // CSV Header
      buffer.writeln(
        'Tanggal,Jenis,Nominal,Rekening Sumber,Kas Sumber,Rekening Tujuan,Kas Tujuan,Aktivitas,Kategori,Status,Catatan',
      );

      for (final tx in txs) {
        final dateStr = tx.tanggal.toIso8601String().split('T').first;
        final kindStr = tx.kind == 'income'
            ? 'Pemasukan'
            : (tx.kind == 'expense' ? 'Pengeluaran' : 'Transfer');
        final amountStr = tx.amount.toString();
        final fromAcc = _escapeCsv(accountsMap[tx.accountId] ?? tx.accountId);
        final fromPool = tx.pool == 'utama' ? 'Kas Utama' : 'Kas Tambahan';
        final toAcc = tx.toAccountId != null
            ? _escapeCsv(accountsMap[tx.toAccountId] ?? tx.toAccountId!)
            : '';
        final toPool = tx.toPool != null
            ? (tx.toPool == 'utama' ? 'Kas Utama' : 'Kas Tambahan')
            : '';
        final activityStr = tx.activity;
        final categoryStr = _escapeCsv(tx.category ?? '');
        final statusStr = tx.status == 'cleared' ? 'Cair' : 'Pending';
        final noteStr = _escapeCsv(tx.note ?? '');

        buffer.writeln(
          '$dateStr,$kindStr,$amountStr,$fromAcc,$fromPool,$toAcc,$toPool,$activityStr,$categoryStr,$statusStr,$noteStr',
        );
      }

      final tempDir = await getTemporaryDirectory();
      final monthLabel = DateFormat('yyyy_MM').format(month);
      final csvPath = p.join(tempDir.path, 'transaksi_sf_$monthLabel.csv');
      final csvFile = File(csvPath);
      await csvFile.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [
          XFile(csvPath,
              mimeType: 'text/csv', name: 'transaksi_sf_$monthLabel.csv')
        ],
        subject:
            'Ekspor Transaksi SF Daily Recap (${DateFormat("MMMM yyyy", "id_ID").format(month)})',
        text:
            'File CSV Transaksi Keuangan SF Daily Recap bulan ${DateFormat("MMMM yyyy", "id_ID").format(month)}',
      );

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content:
                Text('File CSV berhasil dibuat dan siap dibagikan/disimpan'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor CSV: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
