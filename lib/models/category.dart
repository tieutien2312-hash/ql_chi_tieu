class CategoryModel {
  final dynamic id;
  final String name;
  final String type; // 'EXPENSE' or 'INCOME'
  final String color; // Hex color string e.g. '#F97316'
  final String icon; // Icon name e.g. 'restaurant'
  final int isActive; // 1 for active, 0 for inactive

  CategoryModel({
    this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
    this.isActive = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'color': color,
      'icon': icon,
      'isActive': isActive,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    bool activeBool = map['isActive'] ?? map['IsActive'] ?? true;
    return CategoryModel(
      id: map['id'] ?? map['Id'],
      name: map['name'] ?? map['Name'] ?? '',
      type: map['type'] ?? map['Type'] ?? 'EXPENSE',
      color: map['color'] ?? map['Color'] ?? '#6366F1',
      icon: map['icon'] ?? map['Icon'] ?? 'category',
      isActive: activeBool ? 1 : 0,
    );
  }

  CategoryModel copyWith({
    dynamic id,
    String? name,
    String? type,
    String? color,
    String? icon,
    int? isActive,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isActive: isActive ?? this.isActive,
    );
  }
}
