import 'dart:io';

import '../models/geo_area.dart';
import '../models/geo_point.dart';

class KmlPolygonFeature {
  final String name;
  final List<GeoPoint> points;
  final List<List<GeoPoint>> holes;
  const KmlPolygonFeature({required this.name, required this.points,
    this.holes = const []});
}

class KmlImportResult {
  final String fileName;
  final String name;
  final List<GeoPoint> points;
  final List<KmlPolygonFeature> features;

  const KmlImportResult({
    required this.fileName,
    required this.name,
    required this.points,
    this.features = const [],
  });

  bool get isValid => features.any((feature) => feature.points.length >= 3) ||
      points.length >= 3;

  List<GeoPoint> get allPoints => features.isEmpty
      ? points : features.expand((feature) => feature.points).toList();

  double get northLatitude {
    final geometry = allPoints;
    if (geometry.isEmpty) return 0;

    var value = geometry.first.latitude;

    for (final point in geometry) {
      if (point.latitude > value) {
        value = point.latitude;
      }
    }

    return value;
  }

  double get southLatitude {
    final geometry = allPoints;
    if (geometry.isEmpty) return 0;

    var value = geometry.first.latitude;

    for (final point in geometry) {
      if (point.latitude < value) {
        value = point.latitude;
      }
    }

    return value;
  }

  double get eastLongitude {
    final geometry = allPoints;
    if (geometry.isEmpty) return 0;

    var value = geometry.first.longitude;

    for (final point in geometry) {
      if (point.longitude > value) {
        value = point.longitude;
      }
    }

    return value;
  }

  double get westLongitude {
    final geometry = allPoints;
    if (geometry.isEmpty) return 0;

    var value = geometry.first.longitude;

    for (final point in geometry) {
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

    // Read Polygon geometry only; LineString/Point coordinates must not
    // accidentally turn into a geofence. A KML may contain many Placemarks.
    final features = <KmlPolygonFeature>[];
    final placemarks = RegExp(
      r'<(?:\w+:)?Placemark\b[^>]*>([\s\S]*?)<\/(?:\w+:)?Placemark>',
      caseSensitive: false,
    ).allMatches(text).toList();
    for (final placemark in placemarks) {
      final body = placemark.group(1) ?? '';
      final placemarkName = _extractFirstTagText(text: body, tag: 'name');
      _collectPolygons(body, placemarkName.isEmpty ? name : placemarkName,
          features);
    }
    if (features.isEmpty) {
      _collectPolygons(text, name, features);
    }
    features.sort((a, b) => b.points.length.compareTo(a.points.length));
    final selectedPoints = features.isEmpty ? <GeoPoint>[] : features.first.points;
    return KmlImportResult(
      fileName: fileName,
      name: name.isEmpty ? fileName : name,
      points: selectedPoints,
      features: features,
    );
  }

  static void _collectPolygons(String xml, String name,
      List<KmlPolygonFeature> output) {
    final polygons = RegExp(
      r'<(?:\w+:)?Polygon\b[^>]*>([\s\S]*?)<\/(?:\w+:)?Polygon>',
      caseSensitive: false,
    ).allMatches(xml);
    for (final polygon in polygons) {
      final body = polygon.group(1) ?? '';
      final outer = RegExp(
        r'<(?:\w+:)?outerBoundaryIs\b[^>]*>([\s\S]*?)<\/(?:\w+:)?outerBoundaryIs>',
        caseSensitive: false,
      ).firstMatch(body)?.group(1) ?? body;
      final coordinates = _extractCoordinateBlocks(outer);
      if (coordinates.isEmpty) continue;
      final points = _parseCoordinateBlock(coordinates.first);
      if (points.length >= 3) {
        output.add(KmlPolygonFeature(
          name: name.isEmpty ? 'محدوده KML' : name,
          points: points,
          holes: RegExp(
            r'<(?:\w+:)?innerBoundaryIs\b[^>]*>([\s\S]*?)<\/(?:\w+:)?innerBoundaryIs>',
            caseSensitive: false,
          ).allMatches(body).map((match) {
            final blocks = _extractCoordinateBlocks(match.group(1) ?? '');
            return blocks.isEmpty ? <GeoPoint>[] : _parseCoordinateBlock(blocks.first);
          }).where((ring) => ring.length >= 3).toList(),
        ));
      }
    }
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

      if (latitude == null || longitude == null ||
          !latitude.isFinite || !longitude.isFinite) {
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