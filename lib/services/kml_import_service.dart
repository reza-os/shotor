import 'dart:io';

import '../models/geo_area.dart';
import '../models/geo_point.dart';

class KmlImportResult {
  final String fileName;
  final String name;
  final List<GeoPoint> points;

  const KmlImportResult({
    required this.fileName,
    required this.name,
    required this.points,
  });

  bool get isValid {
    return points.length >= 3;
  }

  double get northLatitude {
    if (points.isEmpty) return 0;

    var value = points.first.latitude;

    for (final point in points) {
      if (point.latitude > value) {
        value = point.latitude;
      }
    }

    return value;
  }

  double get southLatitude {
    if (points.isEmpty) return 0;

    var value = points.first.latitude;

    for (final point in points) {
      if (point.latitude < value) {
        value = point.latitude;
      }
    }

    return value;
  }

  double get eastLongitude {
    if (points.isEmpty) return 0;

    var value = points.first.longitude;

    for (final point in points) {
      if (point.longitude > value) {
        value = point.longitude;
      }
    }

    return value;
  }

  double get westLongitude {
    if (points.isEmpty) return 0;

    var value = points.first.longitude;

    for (final point in points) {
      if (point.longitude < value) {
        value = point.longitude;
      }
    }

    return value;
  }

  double get centerLatitude {
    return (northLatitude + southLatitude) / 2;
  }

  double get centerLongitude {
    return (eastLongitude + westLongitude) / 2;
  }
}

class KmlImportService {
  static Future<KmlImportResult> parseKmlFile(
    String path,
  ) async {
    final file = File(path);

    final text = await file.readAsString();

    final fileName = path.split(Platform.pathSeparator).last;

    return parseKmlText(
      text,
      fileName: fileName,
    );
  }

  static KmlImportResult parseKmlText(
    String text, {
    required String fileName,
  }) {
    final name = _extractFirstTagText(
      text: text,
      tag: 'name',
    );

    final coordinateBlocks =
        _extractCoordinateBlocks(text);

    final polygons = <List<GeoPoint>>[];

    for (final block in coordinateBlocks) {
      final points = _parseCoordinateBlock(block);

      if (points.length >= 3) {
        polygons.add(points);
      }
    }

    polygons.sort(
      (a, b) => b.length.compareTo(a.length),
    );

    final selectedPoints =
        polygons.isEmpty ? <GeoPoint>[] : polygons.first;

    return KmlImportResult(
      fileName: fileName,
      name: name.isEmpty ? fileName : name,
      points: selectedPoints,
    );
  }

  static GeoArea applyResultToArea({
    required GeoArea area,
    required KmlImportResult result,
  }) {
    return GeoArea(
      id: area.id,
      name: area.name,
      province: area.province,
      city: area.city,

      northLatitude: result.northLatitude,
      southLatitude: result.southLatitude,

      eastLongitude: result.eastLongitude,
      westLongitude: result.westLongitude,

      centerLatitude: result.centerLatitude,
      centerLongitude: result.centerLongitude,

      defaultZoom: area.defaultZoom,
      mapImagePath: area.mapImagePath,
    );
  }

  static List<String> _extractCoordinateBlocks(
    String text,
  ) {
    final regExp = RegExp(
      r'<(?:\w+:)?coordinates\b[^>]*>([\s\S]*?)<\/(?:\w+:)?coordinates>',
      caseSensitive: false,
      multiLine: true,
    );

    return regExp
        .allMatches(text)
        .map(
          (match) => match.group(1)?.trim() ?? '',
        )
        .where(
          (value) => value.isNotEmpty,
        )
        .toList();
  }

  static List<GeoPoint> _parseCoordinateBlock(
    String block,
  ) {
    final points = <GeoPoint>[];

    final cleanBlock = block
        .replaceAll('<![CDATA[', '')
        .replaceAll(']]>', '')
        .trim();

    final tuples = cleanBlock.split(
      RegExp(r'\s+'),
    );

    for (final tuple in tuples) {
      final parts = tuple.split(',');

      if (parts.length < 2) {
        continue;
      }

      final longitude =
          double.tryParse(parts[0].trim());

      final latitude =
          double.tryParse(parts[1].trim());

      if (latitude == null || longitude == null) {
        continue;
      }

      if (latitude < -90 || latitude > 90) {
        continue;
      }

      if (longitude < -180 || longitude > 180) {
        continue;
      }

      points.add(
        GeoPoint(
          latitude: latitude,
          longitude: longitude,
        ),
      );
    }

    if (points.length >= 2) {
      final first = points.first;
      final last = points.last;

      final sameAsFirst =
          (first.latitude - last.latitude).abs() < 0.0000001 &&
          (first.longitude - last.longitude).abs() < 0.0000001;

      if (sameAsFirst) {
        points.removeLast();
      }
    }

    return points;
  }

  static String _extractFirstTagText({
    required String text,
    required String tag,
  }) {
    final regExp = RegExp(
      '<$tag\\b[^>]*>([\\s\\S]*?)<\\/$tag>',
      caseSensitive: false,
      multiLine: true,
    );

    final match = regExp.firstMatch(text);

    if (match == null) {
      return '';
    }

    return _stripXml(
      match.group(1)?.trim() ?? '',
    );
  }

  static String _stripXml(
    String text,
  ) {
    return text
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .trim();
  }
}