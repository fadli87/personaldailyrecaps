import 'package:uuid/uuid.dart';

class FuelFilling {
  final String id;
  final String dailyRecapId;
  final DateTime tanggal;
  final double liter;
  final double hargaPerLiter;
  final double totalBiaya;
  final double? odometer;
  final String? catatan;
  final String? vehicleId;
  final DateTime createdAt;
  final int isSynced;

  FuelFilling({
    required this.id,
    required this.dailyRecapId,
    required this.tanggal,
    required this.liter,
    this.hargaPerLiter = 0,
    this.totalBiaya = 0,
    this.odometer,
    this.catatan,
    this.vehicleId,
    required this.createdAt,
    this.isSynced = 0,
  });

  factory FuelFilling.fromMap(Map<String, dynamic> map) {
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;

    return FuelFilling(
      id: map['id'] as String,
      dailyRecapId: map['daily_recap_id'] as String,
      tanggal: DateTime.parse(map['tanggal'] as String),
      liter: d(map['liter']),
      hargaPerLiter: d(map['harga_per_liter']),
      totalBiaya: d(map['total_biaya']),
      odometer: map['odometer'] != null ? d(map['odometer']) : null,
      catatan: map['catatan'] as String?,
      vehicleId: map['vehicle_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      isSynced: i(map['is_synced']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'id': id,
        'daily_recap_id': dailyRecapId,
        'tanggal': tanggal.toIso8601String().split('T').first,
        'liter': liter,
        'harga_per_liter': hargaPerLiter,
        'total_biaya': totalBiaya,
        'odometer': odometer,
        'catatan': catatan,
        'vehicle_id': vehicleId,
        'created_at': createdAt.toIso8601String(),
        'is_synced': isSynced,
      };

  Map<String, dynamic> toMap() => toInsertMap();

  // Helper untuk membuat instance baru dengan UUID otomatis
  factory FuelFilling.create({
    required String dailyRecapId,
    required DateTime tanggal,
    required double liter,
    double hargaPerLiter = 0,
    double totalBiaya = 0,
    double? odometer,
    String? catatan,
    String? vehicleId,
  }) {
    return FuelFilling(
      id: const Uuid().v4(),
      dailyRecapId: dailyRecapId,
      tanggal: tanggal,
      liter: liter,
      hargaPerLiter: hargaPerLiter,
      totalBiaya: totalBiaya,
      odometer: odometer,
      catatan: catatan,
      vehicleId: vehicleId,
      createdAt: DateTime.now(),
    );
  }

  FuelFilling copyWith({
    String? id,
    String? dailyRecapId,
    DateTime? tanggal,
    double? liter,
    double? hargaPerLiter,
    double? totalBiaya,
    double? odometer,
    String? catatan,
    String? vehicleId,
    DateTime? createdAt,
    int? isSynced,
  }) {
    return FuelFilling(
      id: id ?? this.id,
      dailyRecapId: dailyRecapId ?? this.dailyRecapId,
      tanggal: tanggal ?? this.tanggal,
      liter: liter ?? this.liter,
      hargaPerLiter: hargaPerLiter ?? this.hargaPerLiter,
      totalBiaya: totalBiaya ?? this.totalBiaya,
      odometer: odometer ?? this.odometer,
      catatan: catatan ?? this.catatan,
      vehicleId: vehicleId ?? this.vehicleId,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
