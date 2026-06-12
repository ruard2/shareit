// lib/models/item.dart
class Item {
  final int id;
  final String name;
  final String? info;
  final double? leenkosten; // null = gratis
  final String? imagePath; // maps to image_path
  final int ownerId; // owner_id
  final int groupId; // group_id
  final List<int> availableGroupIds; // available_group_ids
  final String status; // "free" | "reserved" | "loaned" | "expired"
  final int? lenderId; // lender_id
  final DateTime? reservedAt; // reserved_at
  final DateTime? listedAt;   // when free item was listed (for expiry)
  final String? category;   // Feature 5
  final String? condition;  // Feature 5
  final String? ownerName;    // Feature 2
  final String? lenderName;   // Feature 2
  final int? maxBorrowDays;   // max uitleentermijn in dagen

  const Item({
    required this.id,
    required this.name,
    this.info,
    this.leenkosten,
    this.imagePath,
    required this.ownerId,
    required this.groupId,
    required this.availableGroupIds,
    required this.status,
    this.lenderId,
    this.reservedAt,
    this.listedAt,
    this.category,
    this.condition,
    this.ownerName,
    this.lenderName,
    this.maxBorrowDays,
  });

  /// Convenience getters for UI logic
  bool get isGratis => leenkosten == null;
  bool get isVrij => status.toLowerCase() == 'free';
  bool get isVerlopen => status.toLowerCase() == 'expired';

  /// Days remaining before expiry (null if not applicable)
  int? get daysUntilExpiry {
    if (!isGratis || listedAt == null || !isVrij) return null;
    const expiryDays = 60;
    final expireDate = listedAt!.add(const Duration(days: expiryDays));
    final remaining = expireDate.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    // Defensive parsing for robust null/mixed payloads
    final rawLeenkosten = json['leenkosten'];
    double? parsedLeenkosten;
    if (rawLeenkosten is num) {
      parsedLeenkosten = rawLeenkosten.toDouble();
    } else if (rawLeenkosten is String) {
      parsedLeenkosten = double.tryParse(rawLeenkosten);
    }

    final List<int> parsedAvailableGroups =
        (json['available_group_ids'] as List?)
                ?.map((e) {
                  if (e is int) return e;
                  if (e is String) return int.tryParse(e) ?? -1;
                  return -1;
                })
                .where((e) => e >= 0)
                .toList() ??
            const [];

    DateTime? parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return Item(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      info: json['info'] as String?,
      leenkosten: parsedLeenkosten,
      imagePath: json['image_path'] as String?,
      ownerId: (json['owner_id'] as num).toInt(),
      groupId: (json['group_id'] as num).toInt(),
      availableGroupIds: parsedAvailableGroups,
      status: (json['status'] as String?) ?? 'free',
      lenderId: (json['lender_id'] as num?)?.toInt(),
      reservedAt: parseDate(json['reserved_at']),
      listedAt: parseDate(json['listed_at']),
      category: json['category'] as String?,
      condition: json['condition'] as String?,
      ownerName: json['owner_name'] as String?,
      lenderName: json['lender_name'] as String?,
      maxBorrowDays: (json['max_borrow_days'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'info': info,
      'leenkosten': leenkosten,
      'image_path': imagePath,
      'owner_id': ownerId,
      'group_id': groupId,
      'available_group_ids': availableGroupIds,
      'status': status,
      'lender_id': lenderId,
      'reserved_at': reservedAt?.toIso8601String(),
      'listed_at': listedAt?.toIso8601String(),
      'category': category,
      'condition': condition,
      'max_borrow_days': maxBorrowDays,
    };
  }

  Item copyWith({
    String? name,
    String? info,
    double? leenkosten,
    String? imagePath,
    int? ownerId,
    int? groupId,
    List<int>? availableGroupIds,
    String? status,
    int? lenderId,
    DateTime? reservedAt,
    DateTime? listedAt,
    String? category,
    String? condition,
    String? ownerName,
    String? lenderName,
    int? maxBorrowDays,
  }) {
    return Item(
      id: id,
      name: name ?? this.name,
      info: info ?? this.info,
      leenkosten: leenkosten ?? this.leenkosten,
      imagePath: imagePath ?? this.imagePath,
      ownerId: ownerId ?? this.ownerId,
      groupId: groupId ?? this.groupId,
      availableGroupIds: availableGroupIds ?? this.availableGroupIds,
      status: status ?? this.status,
      lenderId: lenderId ?? this.lenderId,
      reservedAt: reservedAt ?? this.reservedAt,
      listedAt: listedAt ?? this.listedAt,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      ownerName: ownerName ?? this.ownerName,
      lenderName: lenderName ?? this.lenderName,
      maxBorrowDays: maxBorrowDays ?? this.maxBorrowDays,
    );
  }

  @override
  String toString() {
    return 'Item(id: $id, name: $name, status: $status, gratis: ${leenkosten == null})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Item &&
        other.id == id &&
        other.name == name &&
        other.info == info &&
        other.leenkosten == leenkosten &&
        other.imagePath == imagePath &&
        other.ownerId == ownerId &&
        other.groupId == groupId &&
        _listEquals(other.availableGroupIds, availableGroupIds) &&
        other.status == status &&
        other.lenderId == lenderId &&
        _dateEquals(other.reservedAt, reservedAt);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      info,
      leenkosten,
      imagePath,
      ownerId,
      groupId,
      Object.hashAll(availableGroupIds),
      status,
      lenderId,
      reservedAt?.millisecondsSinceEpoch,
    );
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _dateEquals(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.isAtSameMomentAs(b);
  }
}
