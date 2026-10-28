import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/area_zone.dart';
import '../models/geo_area.dart';
import '../models/polygon_zone.dart';
import '../models/tag_record.dart';
import '../services/map_herd_status.dart';
import '../services/map_cluster_service.dart';

/// The online backdrop is a slippy map. GPS, geofences and labels always come
/// from local app data; they do not depend on a tiles provider being reachable.
/// Only tiles the user actually views are stored for later revisits.
class OnlineHerdMap extends StatefulWidget {
  final List<TagRecord> records;
  final List<AreaZone> zones;
  final List<PolygonZone> polygons;
  final List<TagRecord> routeRecords;
  final GeoArea? area;
  final String? selectedTagId;
  final ValueChanged<TagRecord> onCamelSelected;
  final String Function(TagRecord) nameForRecord;
  const OnlineHerdMap({super.key, required this.records,
    required this.zones, required this.polygons, required this.area,
    this.routeRecords = const [],
    required this.selectedTagId, required this.onCamelSelected,
    required this.nameForRecord});

  @override
  State<OnlineHerdMap> createState() => _OnlineHerdMapState();
}

class _OnlineHerdMapState extends State<OnlineHerdMap> {
  final MapController _controller = MapController();
  late final Future<FileCacheStore> _tileStore;
  bool _ready = false;
  double _zoom = 12;
  List<MapCamelCluster> _clusters = const [];

  void _computeClusters() {
    _clusters = MapClusterService.build(widget.records, widget.area,
      widget.zones, widget.polygons);
  }

  @override
  void initState() {
    super.initState();
    _tileStore = _initCache();
    _computeClusters();
  }

  Future<FileCacheStore> _initCache() async {
    final directory = await getApplicationSupportDirectory();
    return FileCacheStore('${directory.path}/openstreetmap_visible_tiles');
  }

  LatLng get _initialCenter {
    if (widget.records.isNotEmpty) {
      final r = widget.records.first;
      return LatLng(r.latitude!, r.longitude!);
    }
    if (widget.polygons.isNotEmpty && widget.polygons.first.points.isNotEmpty) {
      final p = widget.polygons.first.points.first;
      return LatLng(p.latitude, p.longitude);
    }
    if (widget.zones.isNotEmpty) {
      final z = widget.zones.first;
      return LatLng(z.centerLatitude, z.centerLongitude);
    }
    if (widget.area != null) {
      return LatLng(widget.area!.centerLatitude, widget.area!.centerLongitude);
    }
    return const LatLng(31.8, 54.4);
  }

  bool _sameIdentities<T>(List<T> before, List<T> after) {
    if (before.length != after.length) return false;
    for (var i = 0; i < before.length; i++) {
      if (!identical(before[i], after[i])) return false;
    }
    return true;
  }

  @override
  void didUpdateWidget(covariant OnlineHerdMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameIdentities(oldWidget.records, widget.records) ||
        !_sameIdentities(oldWidget.zones, widget.zones) ||
        !_sameIdentities(oldWidget.polygons, widget.polygons) ||
        oldWidget.area != widget.area) {
      _computeClusters();
    }
    if (_ready && oldWidget.routeRecords.isEmpty &&
        widget.routeRecords.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusRoute();
      });
    } else if (_ready && oldWidget.selectedTagId != widget.selectedTagId) {
      _focusSelected();
    }
  }

  void _focusSelected() {
    if (!_ready || widget.selectedTagId == null) return;
    for (final camel in widget.records) {
      if (camel.tagId == widget.selectedTagId) {
        _controller.move(LatLng(camel.latitude!, camel.longitude!),
            _controller.camera.zoom < MapClusterService.expandAtZoom ?
              MapClusterService.expandAtZoom + .2 : _controller.camera.zoom);
        return;
      }
    }
  }

  void _focusRoute() {
    if (!_ready) return;
    final coordinates = widget.routeRecords.where((r) =>
      r.latitude != null && r.longitude != null)
        .map((r) => LatLng(r.latitude!, r.longitude!)).toList();
    if (coordinates.length > 1) {
      _controller.fitCamera(CameraFit.coordinates(
        coordinates: coordinates,
        padding: const EdgeInsets.all(35), maxZoom: 17));
    }
  }

  void _focusAll() {
    if (!_ready) return;
    final points = <LatLng>[
      ...widget.records.map((r) => LatLng(r.latitude!, r.longitude!)),
      ...widget.polygons.where((p) => p.isActive).expand((p) =>
          p.points.map((g) => LatLng(g.latitude, g.longitude))),
      ...widget.zones.where((z) => z.isActive).map((z) =>
          LatLng(z.centerLatitude, z.centerLongitude)),
    ];
    if (points.isEmpty) {
      _controller.move(_initialCenter, 12);
    } else if (points.length == 1) {
      _controller.move(points.single, 15);
    } else {
      _controller.fitCamera(CameraFit.coordinates(
        coordinates: points, padding: const EdgeInsets.all(48), maxZoom: 16));
    }
  }

  Future<void> _openExternal() async {
    TagRecord? selected;
    for (final camel in widget.records) {
      if (camel.tagId == widget.selectedTagId) {
        selected = camel;
        break;
      }
    }
    final coordinate = selected != null
        ? LatLng(selected.latitude!, selected.longitude!)
        : (_ready ? _controller.camera.center : _initialCenter);
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${coordinate.latitude},${coordinate.longitude}',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('برنامه نقشه خارجی در دسترس نیست.')));
    }
  }

  Color _zoneColor(bool isForbidden) => isForbidden
      ? const Color(0xFFD14553) : const Color(0xFF16845D);

  @override
  Widget build(BuildContext context) {
    final polygons = widget.polygons.where((p) => p.isActive && p.isValid).map((p) {
      final color = _zoneColor(p.type == PolygonZoneType.forbidden);
      return Polygon(
        points: p.points.map((e) => LatLng(e.latitude, e.longitude)).toList(),
        holePointsList: p.holes.map((ring) => ring.map((e) =>
            LatLng(e.latitude, e.longitude)).toList()).toList(),
        color: color.withValues(alpha: .16), borderColor: color,
        borderStrokeWidth: 2.5,
      );
    }).toList();
    final circles = widget.zones.where((z) => z.isActive).map((z) {
      final color = _zoneColor(z.type == AreaZoneType.forbidden);
      return CircleMarker(
        point: LatLng(z.centerLatitude, z.centerLongitude),
        radius: z.radiusMeters, useRadiusInMeter: true,
        color: color.withValues(alpha: .13), borderColor: color,
        borderStrokeWidth: 2.2,
      );
    }).toList();

    // Keep camel names small. Below zoom 16 only selected names appear;
    // below zoom 17 physically close, same-zone camels merge into a cluster.
    final markerSize = (_zoom * 1.6 + 1).clamp(18.0, 29.0).toDouble();
    final labelSize = (_zoom * .24 + 5.7).clamp(8.0, 10.0).toDouble();
    final showClusters = _zoom < MapClusterService.expandAtZoom;
    final clusters = showClusters ? _clusters : widget.records.map((record) =>
      MapCamelCluster(members: [record], latitude: record.latitude!,
        longitude: record.longitude!, zoneKey: '')).toList();
    final markers = clusters.map((cluster) {
      if (showClusters && cluster.isGroup) {
        return Marker(
          key: ValueKey('cluster_${cluster.zoneKey}_${cluster.members.first.tagId}'),
          point: LatLng(cluster.latitude, cluster.longitude),
          width: 43, height: 43,
          child: Tooltip(
            message: '${cluster.members.length} شتر نزدیک به هم',
            child: GestureDetector(
              onTap: () => _controller.move(LatLng(cluster.latitude, cluster.longitude),
                  MapClusterService.expandAtZoom + .2),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFB75C2D), shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]),
                child: Text('${cluster.members.length}',
                  style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 13)),
              ),
            ),
          ),
        );
      }
      final r = cluster.members.first;
      final selected = r.tagId == widget.selectedTagId;
      final assessment = MapHerdStatus.assess(
        r, widget.area, widget.zones, widget.polygons);
      final color = assessment.forbiddenNames.isNotEmpty ||
          assessment.state == MapBoundaryState.outside
          ? const Color(0xFFCA4153) : selected
          ? const Color(0xFFB75C2D) : const Color(0xFF16845D);
      final showLabel = _zoom >= 16 || selected;
      return Marker(
        key: ValueKey('camel_${r.tagId}'),
        point: LatLng(r.latitude!, r.longitude!),
        width: showLabel ? 96 : markerSize + 7,
        height: showLabel ? markerSize + 24 : markerSize + 7,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () => widget.onCamelSelected(r),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: markerSize, height: markerSize,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: selected ? 2.5 : 1.5),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
              child: Icon(Icons.pets_rounded, color: Colors.white,
                size: markerSize * .56)),
            if (showLabel)
              Container(
                constraints: const BoxConstraints(maxWidth: 94),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(5)),
                child: Text(widget.nameForRecord(r), maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: labelSize, height: 1.1,
                    fontWeight: FontWeight.w600, color: color)),
              ),
          ]),
        ),
      );
    }).toList();

    final zoneLabels = <Marker>[
      if (_zoom >= 10)
        ...widget.polygons.where((z) => z.isActive && z.isValid).map((z) {
          final averageLat = z.points.map((p) => p.latitude).reduce((a,b) => a+b) / z.points.length;
          final averageLon = z.points.map((p) => p.longitude).reduce((a,b) => a+b) / z.points.length;
          return _zoneLabel(LatLng(averageLat, averageLon), z.name,
            z.type == PolygonZoneType.forbidden, labelSize);
        }),
      if (_zoom >= 10)
        ...widget.zones.where((z) => z.isActive).map((z) => _zoneLabel(
          LatLng(z.centerLatitude, z.centerLongitude), z.name,
          z.type == AreaZoneType.forbidden, labelSize)),
    ];

    final routePoints = widget.routeRecords.where((r) =>
      r.latitude != null && r.longitude != null &&
      r.latitude!.isFinite && r.longitude!.isFinite)
      .map((r) => LatLng(r.latitude!, r.longitude!)).toList();
    return SizedBox(height: 380, child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: FutureBuilder<FileCacheStore>(future: _tileStore, builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: snapshot.hasError
            ? const Text('خطا در آماده‌سازی کش نقشه')
            : const CircularProgressIndicator());
        }
        return Stack(children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _initialCenter, initialZoom: 12,
              minZoom: 3, maxZoom: 19,
              onPositionChanged: (camera, _) {
                // Rebuild at half-zoom steps, not every camera pixel.
                final quantized = (camera.zoom * 2).round() / 2;
                if (mounted && (_zoom - quantized).abs() >= .5) {
                  setState(() => _zoom = quantized);
                }
              },
              onMapReady: () {
                _ready = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (widget.routeRecords.length > 1) {
                    _focusRoute();
                  } else if (widget.selectedTagId != null) {
                    _focusSelected();
                  } else {
                    _focusAll();
                  }
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.saraban_app',
                // Compliant on-view cache (no automatic region prefetch).
                tileProvider: CachedTileProvider(
                  store: snapshot.data!, maxStale: const Duration(days: 7)),
              ),
              if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
              if (circles.isNotEmpty) CircleLayer(circles: circles),
              if (zoneLabels.isNotEmpty) MarkerLayer(markers: zoneLabels),
              if (routePoints.length >= 2)
                PolylineLayer(polylines: [Polyline(
                  points: routePoints,
                  strokeWidth: 3.5, color: const Color(0xFFCE6031))]),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
              const RichAttributionWidget(attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ]),
            ],
          ),
          Positioned(right: 8, top: 8,
            child: Column(children: [
              _control(Icons.center_focus_strong_rounded, _focusAll, 'نمایش همه'),
              const SizedBox(height: 6),
              _control(Icons.open_in_new_rounded, _openExternal, 'باز کردن در برنامه نقشه'),
            ])),
          Positioned(left: 8, top: 8,
            child: Column(children: [
              _control(Icons.add, () => _controller.move(_controller.camera.center,
                  (_controller.camera.zoom + 1).clamp(3.0, 19.0).toDouble()), 'بزرگ‌نمایی'),
              const SizedBox(height: 6),
              _control(Icons.remove, () => _controller.move(_controller.camera.center,
                  (_controller.camera.zoom - 1).clamp(3.0, 19.0).toDouble()), 'کوچک‌نمایی'),
            ])),
        ]);
      }),
    ));
  }

  Marker _zoneLabel(LatLng point, String name, bool forbidden, double fontSize) {
    return Marker(
      point: point, width: 132, height: 30,
      child: IgnorePointer(child: Center(child: DecoratedBox(
        decoration: BoxDecoration(
          color: (forbidden ? const Color(0xFFFEE6E8) : const Color(0xFFE6F5EC))
              .withValues(alpha: .92),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(name, textDirection: TextDirection.rtl, maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold,
              color: _zoneColor(forbidden))),
        ),
      ))),
    );
  }

  Widget _control(IconData icon, VoidCallback onTap, String tooltip) =>
      Material(color: Colors.white, borderRadius: BorderRadius.circular(12),
        child: IconButton(onPressed: onTap, icon: Icon(icon),
          tooltip: tooltip, iconSize: 21));
}
