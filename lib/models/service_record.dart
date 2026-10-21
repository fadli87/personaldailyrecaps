import 'package:uuid/uuid.dart';

class ServiceRecord {
  final String id;
  final String vehicleId;
  final String? serviceItemId;
  final DateTime tanggal;
  final double? odometer;
  final int cost;
  final String? shop;
  final String? note;
  final String? transactionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int isSynced;

  const ServiceRecord({
    required this.id,
    required this.vehicleId,
    this.serviceItemId,
    required this.tanggal,
    this.odometer,
    this.cost = 0,
    this.shop,
    this.note,
    this.transactionId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isSynced = 0,
  });

  factory ServiceRecord.fromMap(Map<String, dynamic> map) {
    double? d(dynamic v) => (v as num?)?.toDouble();
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;

    return ServiceRecord(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      serviceItemId: map['service_item_id'] as String?,
      tanggal: DateTime.parse(map['tanggal'] as String),
      odometer: d(map['odometer']),
      cost: i(map['cost']),
      shop: map['shop'] as String?,
      note: map['note'] as String?,
      transactionId: map['transaction_id'] as String?,
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
        'vehicle_id': vehicleId,
        'service_item_id': serviceItemId,
        'tanggal': tanggal.toIso8601String().split('T').first,
        'odometer': odometer,
        'cost': cost,
        'shop': shop,
        'note': note,
        'transaction_id': transactionId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'is_synced': isSynced,
      };

  factory ServiceRecord.create({
    required String vehicleId,
    String? serviceItemId,
    required DateTime tanggal,
    double? odometer,
    int cost = 0,
    String? shop,
    String? note,
    String? transactionId,
  }) {
    final now = DateTime.now();
    return ServiceRecord(
      id: const Uuid().v4(),
      vehicleId: vehicleId,
      serviceItemId: serviceItemId,
      tanggal: tanggal,
      odometer: odometer,
      cost: cost,
      shop: shop,
      note: note,
      transactionId: transactionId,
      createdAt: now,
      updatedAt: now,
    );
  }

  ServiceRecord copyWith({
    String? id,
    String? vehicleId,
    String? serviceItemId,
    DateTime? tanggal,
    double? odometer,
    int? cost,
    String? shop,
    String? note,
    String? transactionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? isSynced,
  }) {
    return ServiceRecord(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      serviceItemId: serviceItemId ?? this.serviceItemId,
      tanggal: tanggal ?? this.tanggal,
      odometer: odometer ?? this.odometer,
      cost: cost ?? this.cost,
      shop: shop ?? this.shop,
      note: note ?? this.note,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
