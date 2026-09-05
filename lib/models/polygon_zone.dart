import 'geo_point.dart';

enum PolygonZoneType {
  grazing,
  barn,
  forbidden,
  water,
  custom,
}

class PolygonZone {
  final String id;
  final String name;
  final PolygonZoneType type;
  final List<GeoPoint> points;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PolygonZone({
    required this.id,
    required this.name,
    required this.type,
    required this.points,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isValid {
    return points.length >= 3;
  }

  factory PolygonZone.fromMap(Map<String, dynamic> map) {
    final rawPoints = map['points'];

    return PolygonZone(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: polygonZoneTypeFromString(
        map['type'] ?? 'custom',
      ),
      points: rawPoints is List
          ? rawPoints
              .whereType<Map<String, dynamic>>()
              .map(GeoPoint.fromMap)
              .toList()
          : <GeoPoint>[],
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.tryParse(
            map['createdAt'] ?? '',
          ) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(
            map['updatedAt'] ?? '',
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': polygonZoneTypeToString(type),
      'points': points.map((e) => e.toMap()).toList(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  PolygonZone copyWith({
    String? id,
    String? name,
    PolygonZoneType? type,
    List<GeoPoint>? points,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PolygonZone(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      points: points ?? this.points,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

String polygonZoneTypeToString(
  PolygonZoneType type,
) {
  switch (type) {
    case PolygonZoneType.grazing:
      return 'grazing';

    case PolygonZoneType.barn:
      return 'barn';

    case PolygonZoneType.forbidden:
      return 'forbidden';

    case PolygonZoneType.water:
      return 'water';

    case PolygonZoneType.custom:
      return 'custom';
  }
}

PolygonZoneType polygonZoneTypeFromString(
  String value,
) {
  switch (value) {
    case 'grazing':
      return PolygonZoneType.grazing;

    case 'barn':
      return PolygonZoneType.barn;

    case 'forbidden':
      return PolygonZoneType.forbidden;

    case 'water':
      return PolygonZoneType.water;

    default:
      return PolygonZoneType.custom;
  }
}