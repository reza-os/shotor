import '../services/map_data_events.dart';
import '../services/tag_records_events.dart';
import '../services/record_day_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import '../models/camel_detail.dart';
import '../models/camel_profile.dart';
import '../services/local_storage_service.dart';
import '../services/area_zone_service.dart';
import '../services/polygon_zone_service.dart';
import '../services/current_geo_area_service.dart';
import '../services/map_herd_status.dart';

class CamelDetailInfoPage extends StatelessWidget {
  final CamelProfile? profile;
  final CamelDetail detail;

  final String? camelName;
  final String? camelNo;
  final String? tagId;

  const CamelDetailInfoPage({
    super.key,
    required CamelProfile this.profile,
    required this.detail,
  })  : camelName = null,
        camelNo = null,
        tagId = null;

  const CamelDetailInfoPage.byValues({
    super.key,
    required this.detail,
    required this.camelName,
    required this.camelNo,
    required this.tagId,
  }) : profile = null;

  @override
  Widget build(BuildContext context) {
    final displayCamelName =
        profile?.camelName ?? camelName ?? 'شتر';

    final displayCamelNo =
        profile?.camelNo ?? camelNo ?? '-';

    final displayTagId =
        profile?.tagId ?? tagId ?? detail.tagId;

    final lines = detail.toDescriptionLines(
      camelName: displayCamelName,
      camelNo: displayCamelNo,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('توضیحات شتر'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFFEAF2FF),
                    child: Icon(
                      Icons.pets_rounded,
                      color: Color(0xFF086EBB),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayCamelName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$displayTagId / شماره $displayCamelNo',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            _CamelGeofenceInfo(displayTagId),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'شرح اطلاعات ثبت‌شده',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF062C5E),
                    ),
                  ),

                  const SizedBox(height: 12),

                  ...lines.map(
                    (line) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                line,
                                style: const TextStyle(
                                  height: 1.8,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
/// A geofence is derived from the most recent stored GPS record; it is not
/// written to the camel's editable profile because it changes with GPS.
class _CamelGeofenceInfo extends StatefulWidget {
  final String tagId;
  const _CamelGeofenceInfo(this.tagId);
  @override
  State<_CamelGeofenceInfo> createState() => _CamelGeofenceInfoState();
}

class _CamelGeofenceInfoState extends State<_CamelGeofenceInfo> {
  late Future<String> _status;
  Timer? _refreshTimer;
  String _dayKey = RecordDayService.todayKey;
  Timer? _dayTimer;

  void _onUpdated() {
    if (_refreshTimer?.isActive == true) return;
    _refreshTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _status = _load());
    });
  }

  @override
  void initState() {
    super.initState();
    _status = _load();
    TagRecordsEvents.revision.addListener(_onUpdated);
    MapDataEvents.revision.addListener(_onUpdated);
    _dayTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_dayKey == RecordDayService.todayKey) return;
      _dayKey = RecordDayService.todayKey;
      _onUpdated();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _dayTimer?.cancel();
    TagRecordsEvents.revision.removeListener(_onUpdated);
    MapDataEvents.revision.removeListener(_onUpdated);
    super.dispose();
  }

  Future<String> _load() async {
    final record = await LocalStorageService.latestGpsForTagAndDay(
      widget.tagId, RecordDayService.today);
    final circles = await AreaZoneService.loadZones();
    final polygons = await PolygonZoneService.loadActiveZones();
    final area = await CurrentGeoAreaService.load();
    if (record != null) {
      return MapHerdStatus.assess(record, area, circles, polygons,
        useLegacyOverallBounds: area != null).description;
    }
    return 'امروز موقعیت GPS برای این شتر ثبت نشده است.';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _status,
    builder: (context, snapshot) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFEAF5ED),
        borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        const Icon(Icons.location_on_rounded, color: Color(0xFF16845D)),
        const SizedBox(width: 9),
        Expanded(child: Text(snapshot.hasError ? 'خطا در خواندن محدوده‌ها'
          : snapshot.data ?? 'در حال بررسی محدوده‌ها...',
          style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    ),
  );
}
