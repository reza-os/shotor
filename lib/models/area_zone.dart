enum AreaZoneType {
  stable,
  pasture,
  water,
  route,
  forbidden,
}

class AreaZone {
  final String id;
  final String name;
  final AreaZoneType type;
  final double centerLatitude;
  final double centerLongitude;
  final double radiusMeters;
  final bool isActive;
  final String createdAt;

  const AreaZone({
    required this.id,
    required this.name,
    required this.type,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusMeters,
    this.isActive = true,
    required this.createdAt,
  });

  String get typeText {
    switch (type) {
      case AreaZoneType.stable:
        return 'آغل';
      case AreaZoneType.pasture:
        return 'چراگاه';
      case AreaZoneType.water:
        return 'آبشخور';
      case AreaZoneType.route:
        return 'مسیر';
      case AreaZoneType.forbidden:
        return 'ممنوعه';
    }
  }

  AreaZone copyWith({
    String? id,
    String? name,
    AreaZoneType? type,
    double? centerLatitude,
    double? centerLongitude,
    double? radiusMeters,
    bool? isActive,
    String? createdAt,
  }) {
    return AreaZone(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      centerLatitude: centerLatitude ?? this.centerLatitude,
      centerLongitude: centerLongitude ?? this.centerLongitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
      'radiusMeters': radiusMeters,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }

  factory AreaZone.fromJson(Map<String, dynamic> json) {
    return AreaZone(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: AreaZoneType.values.firstWhere(
        (item) => item.name == json['type'],
        orElse: () => AreaZoneType.pasture,
      ),
      centerLatitude: (json['centerLatitude'] as num?)?.toDouble() ?? 0,
      centerLongitude: (json['centerLongitude'] as num?)?.toDouble() ?? 0,
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 300,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] ?? '',
    );
  }
}