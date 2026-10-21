import 'package:uuid/uuid.dart';

class Vehicle {
  final String id;
  final String name; // 'Aerox', 'Jupiter Z'
  final String? plateHint; // opsional, 4 digit / petunjuk singkat saja
  final double odoInitial;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int isSynced;

  const Vehicle({
    required this.id,
    required this.name,
    this.plateHint,
    this.odoInitial = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isSynced = 0,
  });

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;

    return Vehicle(
      id: map['id'] as String,
      name: map['name'] as String,
      plateHint: map['plate_hint'] as String?,
      odoInitial: d(map['odo_initial']),
      isActive: map['is_active'] == 1 || map['is_active'] == true,
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
        'name': name,
        'plate_hint': plateHint,
        'odo_initial': odoInitial,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'is_synced': isSynced,
      };

  factory Vehicle.create({
    required String name,
    String? plateHint,
    double odoInitial = 0,
    bool isActive = true,
  }) {
    final now = DateTime.now();
    return Vehicle(
      id: const Uuid().v4(),
      name: name,
      plateHint: plateHint,
      odoInitial: odoInitial,
      isActive: isActive,
      createdAt: now,
      updatedAt: now,
    );
  }

  Vehicle copyWith({
    String? id,
    String? name,
    String? plateHint,
    double? odoInitial,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? isSynced,
  }) {
    return Vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      plateHint: plateHint ?? this.plateHint,
      odoInitial: odoInitial ?? this.odoInitial,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
