import 'package:flutter/material.dart';

enum ZoneType {
  stable,
  pasture,
  water,
  route,
  warning,
  forbidden,
}

class ZoneArea {
  final String name;
  final String description;
  final ZoneType type;
  final double left;
  final double top;
  final double width;
  final double height;
  final Color color;

  const ZoneArea({
    required this.name,
    required this.description,
    required this.type,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.color,
  });

  bool get isDanger => type == ZoneType.warning || type == ZoneType.forbidden;

  String get typeText {
    switch (type) {
      case ZoneType.stable:
        return 'آغل';
      case ZoneType.pasture:
        return 'چراگاه';
      case ZoneType.water:
        return 'آبشخور';
      case ZoneType.route:
        return 'مسیر مجاز';
      case ZoneType.warning:
        return 'محدوده هشدار';
      case ZoneType.forbidden:
        return 'محدوده ممنوع';
    }
  }
}