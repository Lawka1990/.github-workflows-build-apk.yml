class Place {
  const Place({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.x,
    required this.y,
    required this.icon,
    required this.color,
    required this.verified,
    this.custom = false,
  });

  factory Place.fromJson(Map<String, Object?> json) {
    return Place(
      id: json['id']! as String,
      name: json['name']! as String,
      subtitle: (json['subtitle'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'inne',
      x: (json['x']! as num).toDouble(),
      y: (json['y']! as num).toDouble(),
      icon: (json['icon'] as String?) ?? 'place',
      color: (json['color'] as String?) ?? 'gold',
      verified: (json['verified'] as bool?) ?? false,
      custom: (json['custom'] as bool?) ?? false,
    );
  }

  final String id;
  final String name;
  final String subtitle;
  final String description;
  final String category;
  final double x;
  final double y;
  final String icon;
  final String color;
  final bool verified;
  final bool custom;

  Place copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? description,
    String? category,
    double? x,
    double? y,
    String? icon,
    String? color,
    bool? verified,
    bool? custom,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      category: category ?? this.category,
      x: x ?? this.x,
      y: y ?? this.y,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      verified: verified ?? this.verified,
      custom: custom ?? this.custom,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'description': description,
      'category': category,
      'x': x,
      'y': y,
      'icon': icon,
      'color': color,
      'verified': verified,
      'custom': custom,
    };
  }
}
