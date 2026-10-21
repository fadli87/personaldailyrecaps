import 'package:uuid/uuid.dart';

class ServiceItem {
  final String id;
  final String vehicleId;
  final String name;
  final int? intervalKm;
  final int? intervalDays;
  final DateTime? lastServiceDate;
  final double? lastServiceOdo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int isSynced;

  const ServiceItem({
    required this.id,
    required this.vehicleId,
    required this.name,
    this.intervalKm,
    this.intervalDays,
    this.lastServiceDate,
    this.lastServiceOdo,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isSynced = 0,
  });

  factory ServiceItem.fromMap(Map<String, dynamic> map) {
    int? i(dynamic v) => (v as num?)?.toInt();
    double? d(dynamic v) => (v as num?)?.toDouble();

    return ServiceItem(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      name: map['name'] as String,
      intervalKm: i(map['interval_km']),
      intervalDays: i(map['interval_days']),
      lastServiceDate: map['last_service_date'] != null
          ? DateTime.parse(map['last_service_date'] as String)
          : null,
      lastServiceOdo: d(map['last_service_odo']),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'name': name,
        'interval_km': intervalKm,
        'interval_days': intervalDays,
        'last_service_date':
            lastServiceDate?.toIso8601String().split('T').first,
        'last_service_odo': lastServiceOdo,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'is_synced': isSynced,
      };

  factory ServiceItem.create({
    required String vehicleId,
    required String name,
    int? intervalKm,
    int? intervalDays,
    DateTime? lastServiceDate,
    double? lastServiceOdo,
  }) {
    if (intervalKm == null && intervalDays == null) {
      throw ArgumentError('Minimal satu interval (km atau hari) harus diisi');
    }
    final now = DateTime.now();
    return ServiceItem(
      id: const Uuid().v4(),
      vehicleId: vehicleId,
      name: name,
      intervalKm: intervalKm,
      intervalDays: intervalDays,
      lastServiceDate: lastServiceDate,
      lastServiceOdo: lastServiceOdo,
      createdAt: now,
      updatedAt: now,
    );
  }

  ServiceItem copyWith({
    String? id,
    String? vehicleId,
    String? name,
    int? intervalKm,
    int? intervalDays,
    DateTime? lastServiceDate,
    double? lastServiceOdo,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? isSynced,
  }) {
    return ServiceItem(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      name: name ?? this.name,
      intervalKm: intervalKm ?? this.intervalKm,
      intervalDays: intervalDays ?? this.intervalDays,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      lastServiceOdo: lastServiceOdo ?? this.lastServiceOdo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
