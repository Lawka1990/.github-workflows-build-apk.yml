class CalibrationAnchor {
  const CalibrationAnchor({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.mapX,
    required this.mapY,
    this.fieldMeasured = false,
  });

  factory CalibrationAnchor.fromJson(Map<String, Object?> json) {
    return CalibrationAnchor(
      id: json['id']! as String,
      name: json['name']! as String,
      latitude: (json['latitude']! as num).toDouble(),
      longitude: (json['longitude']! as num).toDouble(),
      mapX: (json['mapX']! as num).toDouble(),
      mapY: (json['mapY']! as num).toDouble(),
      fieldMeasured: (json['fieldMeasured'] as bool?) ?? false,
    );
  }

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double mapX;
  final double mapY;
  final bool fieldMeasured;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'mapX': mapX,
        'mapY': mapY,
        'fieldMeasured': fieldMeasured,
      };
}
