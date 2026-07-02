class AccountCategory {
  const AccountCategory({
    this.id,
    required this.parentId,
    required this.name,
    required this.type,
    this.sort = 0,
  });

  final int? id;
  final int parentId;
  final String name;
  final int type;
  final int sort;

  bool get isParent => parentId == 0;

  AccountCategory copyWith({
    int? id,
    int? parentId,
    String? name,
    int? type,
    int? sort,
  }) {
    return AccountCategory(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      type: type ?? this.type,
      sort: sort ?? this.sort,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'parent_id': parentId,
      'name': name,
      'type': type,
      'sort': sort,
    };
  }

  factory AccountCategory.fromMap(Map<String, Object?> map) {
    return AccountCategory(
      id: map['id'] as int?,
      parentId: map['parent_id'] as int,
      name: map['name'] as String,
      type: map['type'] as int,
      sort: map['sort'] as int? ?? 0,
    );
  }
}
