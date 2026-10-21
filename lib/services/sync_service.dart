import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_db.dart';

/// Sinkronisasi SQLite <-> Supabase.
/// Perilaku yang dipertahankan: baris lokal is_synced = 0 tidak ditimpa oleh pull.
/// Perbaikan: filter kolom pull, paginasi, isolasi error per tabel, antrean hapus tidak dibuang saat gagal.
class SyncService {
  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Urutan push/pull: tabel induk dulu (foreign key).
  static const List<String> _order = <String>[
    'accounts',
    'vehicles',
    'daily_recap',
    'daily_order',
    'petty_cash_item',
    'daily_extra',
    'fuel_fillings',
    'vehicle_logs',
    'service_items',
    'transactions',
    'service_records',
  ];

  /// Kunci utama selain 'id'.
  static const Map<String, String> _pk = <String, String>{
    'daily_extra': 'daily_recap_id',
  };

  /// Boolean di Supabase, INTEGER 0/1 di SQLite.
  static const Map<String, List<String>> _boolCols = <String, List<String>>{
    'daily_order': <String>['is_fuel_expense'],
    'accounts': <String>['is_active'],
    'vehicles': <String>['is_active'],
  };

  static final Map<String, Set<String>> _colCache = <String, Set<String>>{};

  static Future<void> sync() async {
    final client = _client;
    if (client == null) return;

    final errors = <String>[];

    Future<void> guard(String label, Future<void> Function() fn) async {
      try {
        await fn();
      } catch (e) {
        debugPrint('Sync $label gagal: $e');
        errors.add('$label: $e');
      }
    }

    // 1. Penghapusan dulu agar data yang dihapus tidak dibuat ulang.
    await guard('hapus', _syncDeletions);
    // 2. Push perubahan lokal.
    for (final t in _order) {
      await guard('push $t', () => _pushTable(t));
    }
    // 3. Pull perubahan remote.
    for (final t in _order) {
      await guard('pull $t', () => _pullTable(t));
    }

    if (errors.isNotEmpty) {
      throw StateError(
          'Sinkronisasi sebagian gagal (${errors.length}): ${errors.first}');
    }
  }

  static Future<bool> _tableExists(Database db, String table) async {
    final res = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return res.isNotEmpty;
  }

  static Future<void> _syncDeletions() async {
    final client = _client;
    if (client == null) return;
    final db = await LocalDb.instance.database;
    if (!await _tableExists(db, 'pending_deletions')) return;

    final deletions = await db.query('pending_deletions');
    for (final del in deletions) {
      final queueId = del['id'] as int;
      final table = del['table_name'] as String;
      final recordId = del['record_id'] as String;
      try {
        await client.from(table).delete().eq('id', recordId);
        await db
            .delete('pending_deletions', where: 'id = ?', whereArgs: [queueId]);
      } catch (e) {
        // JANGAN buang antrean saat gagal (mis. offline): kalau dibuang, baris remote
        // masih ada dan akan "hidup lagi" saat pull. Coba lagi pada sync berikutnya.
        debugPrint('Hapus remote gagal ($table): $e');
      }
    }
  }

  static Future<Set<String>> _localCols(Database db, String table) async {
    final cached = _colCache[table];
    if (cached != null) return cached;
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final cols = info.map((r) => r['name'] as String).toSet();
    _colCache[table] = cols;
    return cols;
  }

  static Future<void> _pushTable(String table) async {
    final client = _client;
    if (client == null) return;
    final db = await LocalDb.instance.database;
    if (!await _tableExists(db, table)) return;

    final pk = _pk[table] ?? 'id';
    final boolCols = _boolCols[table] ?? const <String>[];

    final rows = await db.query(table, where: 'is_synced = 0');
    for (final r in rows) {
      final data = Map<String, dynamic>.from(r)..remove('is_synced');
      for (final c in boolCols) {
        if (data[c] != null) data[c] = data[c] == 1;
      }
      // user_id tidak ada di SQLite: server mengisinya lewat default auth.uid().
      await client.from(table).upsert(data);
      await db.update(table, {'is_synced': 1},
          where: '$pk = ?', whereArgs: [r[pk]]);
    }
  }

  static Future<void> _pullTable(String table) async {
    final client = _client;
    if (client == null) return;
    final db = await LocalDb.instance.database;
    if (!await _tableExists(db, table)) return;

    final pk = _pk[table] ?? 'id';
    final cols = await _localCols(db, table);
    final boolCols = _boolCols[table] ?? const <String>[];

    final hasPendingTable = await _tableExists(db, 'pending_deletions');
    final pending = hasPendingTable
        ? (await db.query(
            'pending_deletions',
            columns: ['record_id'],
            where: 'table_name = ?',
            whereArgs: [table],
          ))
            .map((r) => r['record_id'] as String)
            .toSet()
        : <String>{};

    const pageSize = 1000; // batas default PostgREST
    var from = 0;
    while (true) {
      final chunk = await client
          .from(table)
          .select()
          .order(pk)
          .range(from, from + pageSize - 1);

      for (final rr in chunk) {
        final id = rr[pk].toString();
        if (pending.contains(id)) continue;

        // Buang kolom yang tidak ada di SQLite (mis. user_id), konversi boolean.
        final data = <String, dynamic>{};
        rr.forEach((k, v) {
          if (cols.contains(k)) data[k] = v;
        });
        for (final c in boolCols) {
          if (data[c] is bool) data[c] = (data[c] as bool) ? 1 : 0;
        }
        data['is_synced'] = 1;

        final local = await db.query(
          table,
          columns: ['is_synced'],
          where: '$pk = ?',
          whereArgs: [id],
        );
        if (local.isEmpty) {
          await db.insert(table, data);
        } else if ((local.first['is_synced'] as int) == 1) {
          await db.update(table, data, where: '$pk = ?', whereArgs: [id]);
        }
      }

      if (chunk.length < pageSize) break;
      from += pageSize;
    }
  }
}
