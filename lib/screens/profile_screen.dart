import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        child: Icon(Icons.person, color: Color(0xFF2E7D32), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Profil Pengemudi',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        child: Icon(Icons.security, color: Colors.red, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Keamanan Aplikasi',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    activeColor: const Color(0xFF2E7D32),
                    title: const Text(
                      'Kunci PIN Aplikasi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Minta kode PIN keamanan setiap kali aplikasi dibuka.'),
                    value: _isPinEnabled,
                    onChanged: _togglePinLock,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_isPinEnabled) ...[
                    const Divider(height: 16),
                    ListTile(
                      leading: const Icon(Icons.lock_reset, color: Color(0xFF2E7D32)),
                      title: const Text(
                        'Ubah PIN Keamanan',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Ganti kode akses PIN 4-digit Anda.'),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        child: Icon(Icons.account_balance, color: Colors.blue, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Informasi Rekening Bank',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Bank Mandiri',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
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
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
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

          // CARD SINKRONISASI
          Card(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                            child: Icon(Icons.cloud_sync, color: Colors.blue, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Supabase Cloud Sync',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.sync_outlined, color: Colors.blue),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final nowStr = DateFormat('HH:mm:ss').format(DateTime.now());
                          ref.read(syncLogsProvider.notifier).addLog('$nowStr: Memulai sinkronisasi Supabase...');
                          try {
                            await SyncService.sync();
                            final successStr = DateFormat('HH:mm:ss').format(DateTime.now());
                            ref.read(syncLogsProvider.notifier).addLog('$successStr: Sinkronisasi data sukses (Supabase synced).');
                            ref.invalidate(recapsProvider);
                            ref.invalidate(platformDistributionProvider);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Sinkronisasi selesai dipicu')),
                            );
                          } catch (e) {
                            final failStr = DateFormat('HH:mm:ss').format(DateTime.now());
                            ref.read(syncLogsProvider.notifier).addLog('$failStr: Sinkronisasi gagal: $e');
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
                      Text(
                        (supabaseUser?.isAnonymous ?? true) ? 'ID Sesi Anonim:' : 'Email Akun:',
                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      Expanded(
                        child: Text(
                          (supabaseUser?.isAnonymous ?? true)
                              ? (supabaseUser?.id ?? 'Tidak Terdeteksi')
                              : (supabaseUser?.email ?? 'Tidak Terdeteksi'),
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                            content: const Text('Apakah Anda yakin ingin keluar dari akun Anda?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Batal'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Keluar', style: TextStyle(color: Colors.red)),
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
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Anda telah keluar dari akun')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text('KELUAR DARI AKUN', style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            syncLogs[syncLogs.length - 1 - idx], // logs terbaru di atas
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontFamily: 'monospace'),
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
}
