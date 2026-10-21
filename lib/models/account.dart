import 'package:uuid/uuid.dart';

class Account {
  final String id;
  final String name;
  final String kind; // cash | bank | ewallet
  final int openingBalance;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int isSynced;

  const Account({
    required this.id,
    required this.name,
    required this.kind,
    this.openingBalance = 0,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isSynced = 0,
  });

  String get kindText {
    switch (kind) {
      case 'cash':
        return 'Tunai';
      case 'bank':
        return 'Bank';
      case 'ewallet':
        return 'E-Wallet';
      default:
        return kind;
    }
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;

    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      kind: map['kind'] as String,
      openingBalance: i(map['opening_balance']),
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      sortOrder: i(map['sort_order']),
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
        'kind': kind,
        'opening_balance': openingBalance,
        'is_active': isActive ? 1 : 0,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'is_synced': isSynced,
      };

  factory Account.create({
    required String name,
    required String kind,
    int openingBalance = 0,
    bool isActive = true,
    int sortOrder = 0,
  }) {
    final now = DateTime.now();
    return Account(
      id: const Uuid().v4(),
      name: name,
      kind: kind,
      openingBalance: openingBalance,
      isActive: isActive,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  Account copyWith({
    String? id,
    String? name,
    String? kind,
    int? openingBalance,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? isSynced,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      openingBalance: openingBalance ?? this.openingBalance,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
