class CategoryModel {
  final int? id;
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
    return CategoryModel(
      id: map['id'],
      name: map['name'] ?? '',
      type: map['type'] ?? 'EXPENSE',
      color: map['color'] ?? '#6366F1',
      icon: map['icon'] ?? 'category',
      isActive: map['isActive'] ?? 1,
    );
  }

  CategoryModel copyWith({
    int? id,
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
