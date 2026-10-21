import 'package:uuid/uuid.dart';

class VehicleLog {
  final String id;
  final String vehicleId;
  final DateTime tanggal;
  final double odoEnd;
  final double kmKanvasing;
  final double kmOjol;
  final double kmPribadi;
  final double? jamOnlineOjol;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int isSynced;

  const VehicleLog({
    required this.id,
    required this.vehicleId,
    required this.tanggal,
    required this.odoEnd,
    this.kmKanvasing = 0,
    this.kmOjol = 0,
    this.kmPribadi = 0,
    this.jamOnlineOjol,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isSynced = 0,
  });

  factory VehicleLog.fromMap(Map<String, dynamic> map) {
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;

    return VehicleLog(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      tanggal: DateTime.parse(map['tanggal'] as String),
      odoEnd: d(map['odo_end']),
      kmKanvasing: d(map['km_kanvasing']),
      kmOjol: d(map['km_ojol']),
      kmPribadi: d(map['km_pribadi']),
      jamOnlineOjol:
          map['jam_online_ojol'] != null ? d(map['jam_online_ojol']) : null,
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
        'vehicle_id': vehicleId,
        'tanggal': tanggal.toIso8601String().split('T').first,
        'odo_end': odoEnd,
        'km_kanvasing': kmKanvasing,
        'km_ojol': kmOjol,
        'km_pribadi': kmPribadi,
        'jam_online_ojol': jamOnlineOjol,
        'note': note,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'is_synced': isSynced,
      };

  factory VehicleLog.create({
    required String vehicleId,
    required DateTime tanggal,
    required double odoEnd,
    double kmKanvasing = 0,
    double kmOjol = 0,
    double kmPribadi = 0,
    double? jamOnlineOjol,
    String? note,
  }) {
    final now = DateTime.now();
    return VehicleLog(
      id: const Uuid().v4(),
      vehicleId: vehicleId,
      tanggal: tanggal,
      odoEnd: odoEnd,
      kmKanvasing: kmKanvasing,
      kmOjol: kmOjol,
      kmPribadi: kmPribadi,
      jamOnlineOjol: jamOnlineOjol,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
  }

  VehicleLog copyWith({
    String? id,
    String? vehicleId,
    DateTime? tanggal,
    double? odoEnd,
    double? kmKanvasing,
    double? kmOjol,
    double? kmPribadi,
    double? jamOnlineOjol,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? isSynced,
  }) {
    return VehicleLog(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      tanggal: tanggal ?? this.tanggal,
      odoEnd: odoEnd ?? this.odoEnd,
      kmKanvasing: kmKanvasing ?? this.kmKanvasing,
      kmOjol: kmOjol ?? this.kmOjol,
      kmPribadi: kmPribadi ?? this.kmPribadi,
      jamOnlineOjol: jamOnlineOjol ?? this.jamOnlineOjol,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
