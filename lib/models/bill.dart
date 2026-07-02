class Bill {
  const Bill({
    this.id,
    required this.money,
    required this.billType,
    required this.categoryId,
    required this.billTime,
    this.remark,
    this.createTime,
  });

  final int? id;
  final double money;
  final int billType;
  final int categoryId;
  final DateTime billTime;
  final String? remark;
  final DateTime? createTime;

  Bill copyWith({
    int? id,
    double? money,
    int? billType,
    int? categoryId,
    DateTime? billTime,
    String? remark,
    DateTime? createTime,
  }) {
    return Bill(
      id: id ?? this.id,
      money: money ?? this.money,
      billType: billType ?? this.billType,
      categoryId: categoryId ?? this.categoryId,
      billTime: billTime ?? this.billTime,
      remark: remark ?? this.remark,
      createTime: createTime ?? this.createTime,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'money': money,
      'bill_type': billType,
      'category_id': categoryId,
      'bill_time': billTime.toIso8601String(),
      'remark': remark,
      if (createTime != null) 'create_time': createTime!.toIso8601String(),
    };
  }

  factory Bill.fromMap(Map<String, Object?> map) {
    return Bill(
      id: map['id'] as int?,
      money: (map['money'] as num).toDouble(),
      billType: map['bill_type'] as int,
      categoryId: map['category_id'] as int,
      billTime: DateTime.parse(map['bill_time'] as String),
      remark: map['remark'] as String?,
      createTime: map['create_time'] == null
          ? null
          : DateTime.tryParse(map['create_time'] as String),
    );
  }
}

class BillView extends Bill {
  const BillView({
    required super.id,
    required super.money,
    required super.billType,
    required super.categoryId,
    required super.billTime,
    super.remark,
    super.createTime,
    required this.parentCategoryId,
    required this.parentCategoryName,
    required this.childCategoryName,
  });

  final int parentCategoryId;
  final String parentCategoryName;
  final String childCategoryName;

  factory BillView.fromMap(Map<String, Object?> map) {
    return BillView(
      id: map['id'] as int,
      money: (map['money'] as num).toDouble(),
      billType: map['bill_type'] as int,
      categoryId: map['category_id'] as int,
      billTime: DateTime.parse(map['bill_time'] as String),
      remark: map['remark'] as String?,
      createTime: map['create_time'] == null
          ? null
          : DateTime.tryParse(map['create_time'] as String),
      parentCategoryId: map['parent_category_id'] as int,
      parentCategoryName: map['parent_category_name'] as String,
      childCategoryName: map['child_category_name'] as String,
    );
  }
}
