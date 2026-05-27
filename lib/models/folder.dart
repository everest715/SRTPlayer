class Folder {
  final int? id;
  final String name;
  final DateTime createdAt;
  final int sortOrder;

  Folder({
    this.id,
    required this.name,
    required this.createdAt,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'sortOrder': sortOrder,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  Folder copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    int? sortOrder,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
