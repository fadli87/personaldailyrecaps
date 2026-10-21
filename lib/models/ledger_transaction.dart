import 'package:uuid/uuid.dart';

class LedgerTransaction {
  final String id;
  final DateTime tanggal;
  final String kind; // income | expense | transfer
  final int amount;
  final String accountId;
  final String? toAccountId;
  final String pool; // utama | tambahan
  final String? toPool; // utama | tambahan
  final String activity; // kanvasing | ojol | pribadi | kendaraan
  final String? category;
  final String? vehicleId;
  final String? fuelFillingId;
  final String status; // cleared | pending
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int isSynced;

  const LedgerTransaction({
    required this.id,
    required this.tanggal,
    required this.kind,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.pool = 'utama',
    this.toPool,
    this.activity = 'kanvasing',
    this.category,
    this.vehicleId,
    this.fuelFillingId,
    this.status = 'cleared',
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isSynced = 0,
  });

  factory LedgerTransaction.fromMap(Map<String, dynamic> map) {
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;

    return LedgerTransaction(
      id: map['id'] as String,
      tanggal: DateTime.parse(map['tanggal'] as String),
      kind: map['kind'] as String,
      amount: i(map['amount']),
      accountId: map['account_id'] as String,
      toAccountId: map['to_account_id'] as String?,
      pool: (map['pool'] as String?) ?? 'utama',
      toPool: map['to_pool'] as String?,
      activity: (map['activity'] as String?) ?? 'kanvasing',
      category: map['category'] as String?,
      vehicleId: map['vehicle_id'] as String?,
      fuelFillingId: map['fuel_filling_id'] as String?,
      status: (map['status'] as String?) ?? 'cleared',
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
      isSynced: i(map['is_synced']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'tanggal': tanggal.toIso8601String().split('T').first,
        'kind': kind,
        'amount': amount,
        'account_id': accountId,
        'to_account_id': toAccountId,
        'pool': pool,
        'to_pool': toPool,
        'activity': activity,
        'category': category,
        'vehicle_id': vehicleId,
        'fuel_filling_id': fuelFillingId,
        'status': status,
        'note': note,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'is_synced': isSynced,
      };

  factory LedgerTransaction.create({
    required DateTime tanggal,
    required String kind,
    required int amount,
    required String accountId,
    String? toAccountId,
    String pool = 'utama',
    String? toPool,
    String activity = 'kanvasing',
    String? category,
    String? vehicleId,
    String? fuelFillingId,
    String status = 'cleared',
    String? note,
  }) {
    final now = DateTime.now();
    return LedgerTransaction(
      id: const Uuid().v4(),
      tanggal: tanggal,
      kind: kind,
      amount: amount,
      accountId: accountId,
      toAccountId: toAccountId,
      pool: pool,
      toPool: toPool,
      activity: activity,
      category: category,
      vehicleId: vehicleId,
      fuelFillingId: fuelFillingId,
      status: status,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
  }

  LedgerTransaction copyWith({
    String? id,
    DateTime? tanggal,
    String? kind,
    int? amount,
    String? accountId,
    String? toAccountId,
    String? pool,
    String? toPool,
    String? activity,
    String? category,
    String? vehicleId,
    String? fuelFillingId,
    String? status,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? isSynced,
  }) {
    return LedgerTransaction(
      id: id ?? this.id,
      tanggal: tanggal ?? this.tanggal,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      pool: pool ?? this.pool,
      toPool: toPool ?? this.toPool,
      activity: activity ?? this.activity,
      category: category ?? this.category,
      vehicleId: vehicleId ?? this.vehicleId,
      fuelFillingId: fuelFillingId ?? this.fuelFillingId,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
