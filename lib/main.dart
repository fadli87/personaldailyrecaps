import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/sync_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Inisialisasi data format tanggal lokalisasi
  await initializeDateFormatting('id_ID', null);

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.get('SUPABASE_URL'),
    publishableKey: dotenv.get('SUPABASE_ANON_KEY'),
  );

  // Sign-in anonim supaya app bisa langsung dipakai tanpa layar login.
  // Pastikan "Allow anonymous sign-ins" sudah diaktifkan di
  // Supabase Dashboard -> Authentication -> Sign In / Providers.
  if (Supabase.instance.client.auth.currentSession == null) {
    try {
      await Supabase.instance.client.auth.signInAnonymously();
    } catch (e) {
      debugPrint('Failed to sign in anonymously (offline): $e');
    }
  }

  // Jalankan sinkronisasi awal di background secara async
  Future.microtask(() => SyncService.sync());

  runApp(
    const ProviderScope(
      child: SFDailyRecapApp(),
    ),
  );
}

class SFDailyRecapApp extends StatelessWidget {
  const SFDailyRecapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SF Daily Recap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E7D32),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}
