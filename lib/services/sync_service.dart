import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_db.dart';

class SyncService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<void> sync() async {
    // 1. Sync deletions first to avoid recreating deleted records
    await _syncDeletions();

    // 2. Sync local changes (Push)
    await _syncPush();

    // 3. Sync remote changes (Pull)
    await _syncPull();
  }

  static Future<void> _syncDeletions() async {
    final db = await LocalDb.instance.database;
    final deletions = await db.query('pending_deletions');
    if (deletions.isEmpty) return;

    for (final del in deletions) {
      final id = del['id'] as int;
      final tableName = del['table_name'] as String;
      final recordId = del['record_id'] as String;

      try {
        await _client.from(tableName).delete().eq('id', recordId);
        // Delete from local queue
        await db.delete('pending_deletions', where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        // If record is not found or already deleted on server, we can remove it from queue
        await db.delete('pending_deletions', where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  static Future<void> _syncPush() async {
    final db = await LocalDb.instance.database;

    // --- 1. daily_recap ---
    final recaps = await db.query('daily_recap', where: 'is_synced = 0');
    for (final r in recaps) {
      final data = Map<String, dynamic>.from(r)..remove('is_synced');
      await _client.from('daily_recap').upsert(data);
      await db.update('daily_recap', {'is_synced': 1}, where: 'id = ?', whereArgs: [r['id']]);
    }

    // --- 2. daily_order ---
    final orders = await db.query('daily_order', where: 'is_synced = 0');
    for (final o in orders) {
      final data = Map<String, dynamic>.from(o)..remove('is_synced');
      if (data['is_fuel_expense'] != null) {
        data['is_fuel_expense'] = data['is_fuel_expense'] == 1;
      }
      await _client.from('daily_order').upsert(data);
      await db.update('daily_order', {'is_synced': 1}, where: 'id = ?', whereArgs: [o['id']]);
    }

    // --- 3. petty_cash_item ---
    final pettyItems = await db.query('petty_cash_item', where: 'is_synced = 0');
    for (final pi in pettyItems) {
      final data = Map<String, dynamic>.from(pi)..remove('is_synced');
      await _client.from('petty_cash_item').upsert(data);
      await db.update('petty_cash_item', {'is_synced': 1}, where: 'id = ?', whereArgs: [pi['id']]);
    }

    // --- 4. daily_extra ---
    final extras = await db.query('daily_extra', where: 'is_synced = 0');
    for (final ex in extras) {
      final data = Map<String, dynamic>.from(ex)..remove('is_synced');
      await _client.from('daily_extra').upsert(data);
      await db.update('daily_extra', {'is_synced': 1}, where: 'daily_recap_id = ?', whereArgs: [ex['daily_recap_id']]);
    }
  }

  static Future<void> _syncPull() async {
    final db = await LocalDb.instance.database;

    // 1. Pull daily_recap
    final remoteRecaps = await _client.from('daily_recap').select();
    for (final rr in remoteRecaps) {
      final local = await db.query('daily_recap', where: 'id = ?', whereArgs: [rr['id']]);
      if (local.isEmpty) {
        final data = Map<String, dynamic>.from(rr)..['is_synced'] = 1;
        await db.insert('daily_recap', data);
      } else {
        final localIsSynced = local.first['is_synced'] as int;
        if (localIsSynced == 1) {
          final data = Map<String, dynamic>.from(rr)..['is_synced'] = 1;
          await db.update('daily_recap', data, where: 'id = ?', whereArgs: [rr['id']]);
        }
      }
    }

    // 2. Pull daily_order
    final remoteOrders = await _client.from('daily_order').select();
    for (final ro in remoteOrders) {
      final local = await db.query('daily_order', where: 'id = ?', whereArgs: [ro['id']]);
      if (local.isEmpty) {
        final data = Map<String, dynamic>.from(ro)..['is_synced'] = 1;
        if (data['is_fuel_expense'] != null) {
          data['is_fuel_expense'] = (data['is_fuel_expense'] as bool) ? 1 : 0;
        }
        await db.insert('daily_order', data);
      } else {
        final localIsSynced = local.first['is_synced'] as int;
        if (localIsSynced == 1) {
          final data = Map<String, dynamic>.from(ro)..['is_synced'] = 1;
          if (data['is_fuel_expense'] != null) {
            data['is_fuel_expense'] = (data['is_fuel_expense'] as bool) ? 1 : 0;
          }
          await db.update('daily_order', data, where: 'id = ?', whereArgs: [ro['id']]);
        }
      }
    }

    // 3. Pull petty_cash_item
    final remotePetty = await _client.from('petty_cash_item').select();
    for (final rp in remotePetty) {
      final local = await db.query('petty_cash_item', where: 'id = ?', whereArgs: [rp['id']]);
      if (local.isEmpty) {
        final data = Map<String, dynamic>.from(rp)..['is_synced'] = 1;
        await db.insert('petty_cash_item', data);
      } else {
        final localIsSynced = local.first['is_synced'] as int;
        if (localIsSynced == 1) {
          final data = Map<String, dynamic>.from(rp)..['is_synced'] = 1;
          await db.update('petty_cash_item', data, where: 'id = ?', whereArgs: [rp['id']]);
        }
      }
    }

    // 4. Pull daily_extra
    final remoteExtras = await _client.from('daily_extra').select();
    for (final re in remoteExtras) {
      final local = await db.query('daily_extra', where: 'daily_recap_id = ?', whereArgs: [re['daily_recap_id']]);
      if (local.isEmpty) {
        final data = Map<String, dynamic>.from(re)..['is_synced'] = 1;
        await db.insert('daily_extra', data);
      } else {
        final localIsSynced = local.first['is_synced'] as int;
        if (localIsSynced == 1) {
          final data = Map<String, dynamic>.from(re)..['is_synced'] = 1;
          await db.update('daily_extra', data, where: 'daily_recap_id = ?', whereArgs: [re['daily_recap_id']]);
        }
      }
    }
  }
}
