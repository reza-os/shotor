import 'dart:io';

import 'package:flutter/material.dart';

import '../models/area_zone.dart';
import '../models/management_report.dart';
import '../models/polygon_zone.dart';
import '../models/tag_record.dart';
import '../services/camel_detail_service.dart';
import '../services/management_report_service.dart';
import '../services/report_visit_analysis_service.dart';

/// Compact report workflow. Report calculation and Excel/export remain owned by
/// ManagementReportPage; only the selection and visualization live here.
class ManagementReportDashboard extends StatefulWidget {
  final ManagementReport report;
  final List<TagRecord> records;
  final List<AreaZone> zones;
  final List<PolygonZone> polygons;
  final DateTime date;
  final String dateLabel;
  final int maxGapMinutes;
  final VoidCallback previousDay;
  final VoidCallback nextDay;
  final VoidCallback selectDate;
  final VoidCallback selectToday;
  final VoidCallback openSettings;
  final VoidCallback openPreview;
  final VoidCallback exportExcel;
  final bool exporting;
  final bool isToday;

  const ManagementReportDashboard({super.key,
    required this.report, required this.records, required this.zones,
    required this.polygons, required this.date, required this.dateLabel,
    required this.maxGapMinutes, required this.previousDay,
    required this.nextDay, required this.selectDate, required this.selectToday,
    required this.openSettings, required this.openPreview,
    required this.exportExcel, required this.exporting, required this.isToday,
  });

  @override
  State<ManagementReportDashboard> createState() => _ManagementReportDashboardState();
}

class _ManagementReportDashboardState extends State<ManagementReportDashboard> {
  bool locationMode = true;
  String? selectedTag;
  String? selectedZone;
  String search = '';
  final TextEditingController searchController = TextEditingController();
  final Map<String, Future<String?>> _photos = {};
  List<ReportLocationSummary>? _cachedLocations;
  String? _cachedLocationTag;

  @override
  void didUpdateWidget(covariant ManagementReportDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report != widget.report ||
        oldWidget.zones != widget.zones ||
        oldWidget.polygons != widget.polygons ||
        oldWidget.date != widget.date ||
        oldWidget.maxGapMinutes != widget.maxGapMinutes) {
      _cachedLocations = null;
      _cachedLocationTag = null;
    }
  }

  static const ink = Color(0xFF192D29);
  static const brown = Color(0xFFA55731);
  static const green = Color(0xFF137959);
  static const muted = Color(0xFF817974);

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<String?> _photo(String tagId) =>
      _photos.putIfAbsent(tagId, () async =>
        (await CamelDetailService.getDetailByTagId(tagId))?.photoPath);

  Widget _panel(Widget child, {EdgeInsets padding = const EdgeInsets.all(14)}) =>
      Container(padding: padding, decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFF1E9E3)),
        boxShadow: [BoxShadow(color: brown.withValues(alpha: 0.045), blurRadius: 16,
          offset: const Offset(0, 5))],
      ), child: child);

  void _selectTag(String tagId) {
    setState(() { selectedTag = tagId; selectedZone = null;
      _cachedLocations = null; _cachedLocationTag = null; });
  }

  Widget _modeButton(String title, IconData icon, bool mode) {
    final active = locationMode == mode;
    return Expanded(child: InkWell(
      onTap: () => setState(() { locationMode = mode; selectedZone = null; }),
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
        decoration: BoxDecoration(
          color: active ? brown : const Color(0xFFF8F2ED),
          borderRadius: BorderRadius.circular(13)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 19, color: active ? Colors.white : brown),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(fontWeight: FontWeight.w800,
            color: active ? Colors.white : ink)),
        ]),
      ),
    ));
  }

  Widget _selector() => _panel(Column(children: [
    Row(children: [
      _modeButton('گزارش مکان', Icons.place_outlined, true),
      const SizedBox(width: 10),
      _modeButton('گزارش زمان', Icons.access_time_rounded, false),
      IconButton(onPressed: widget.openSettings,
        tooltip: 'تنظیم بازه و فاصله معتبر', icon: const Icon(Icons.tune_rounded, color: brown)),
    ]),
    const SizedBox(height: 12),
    Row(children: [
      IconButton(onPressed: widget.previousDay,
        tooltip: 'روز قبل', icon: const Icon(Icons.chevron_right_rounded)),
      Expanded(child: InkWell(onTap: widget.selectDate,
        child: Column(children: [
          const Text('تاریخ گزارش', style: TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 3),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.calendar_month_rounded, size: 17, color: green),
            const SizedBox(width: 6),
            Text(widget.dateLabel, style: const TextStyle(fontSize: 18,
              fontWeight: FontWeight.w900, color: ink)),
          ]),
        ]),
      )),
      IconButton(onPressed: widget.nextDay,
        tooltip: 'روز بعد', icon: const Icon(Icons.chevron_left_rounded)),
      if (!widget.isToday) InkWell(onTap: widget.selectToday,
        child: const Padding(padding: EdgeInsets.all(6),
          child: Text('امروز', style: TextStyle(color: green, fontWeight: FontWeight.bold)))),
    ]),
  ]));

  Widget _photoCard(CamelTimeSlotReport camel) => InkWell(
    onTap: () => _selectTag(camel.tagId),
    borderRadius: BorderRadius.circular(19),
    child: ClipRRect(borderRadius: BorderRadius.circular(19), child: Stack(
      fit: StackFit.expand, children: [
        FutureBuilder<String?>(future: _photo(camel.tagId), builder: (context, snapshot) {
          final path = snapshot.data;
          if (path == null || path.isEmpty) {
            return Image.asset('assets/images/camel_hero.jpg', fit: BoxFit.cover);
          }
          return Image.file(File(path), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.asset('assets/images/camel_hero.jpg', fit: BoxFit.cover));
        }),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xDB1D1C1B)],
        ))),
        Positioned(bottom: 11, right: 9, left: 8, child: Text(camel.camelName,
          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 12,
            fontWeight: FontWeight.w900))),
      ],
    )),
  );

  Widget _camelChooser() {
    final camels = widget.report.timeSlotRows.where((c) {
      final normalized = '${c.camelName} ${c.camelNo} ${c.tagId}'.toLowerCase();
      return normalized.contains(search);
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(children: [
          const Expanded(child: Text('انتخاب شتر', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w900, color: ink))),
          Text('${camels.length} شتر', style: const TextStyle(color: muted, fontSize: 12)),
        ])),
      const SizedBox(height: 9),
      TextField(controller: searchController,
        onChanged: (value) => setState(() => search = value.trim().toLowerCase()),
        decoration: InputDecoration(hintText: 'جستجو با نام، شماره یا شناسه تگ',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(16)),
          isDense: true,
        )),
      const SizedBox(height: 12),
      // A bounded, lazy vertical grid prevents a large herd from making
      // the report screen taller and taller.
      SizedBox(height: 350,
        child: camels.isEmpty
          ? _panel(const Center(child: Text('شتری مطابق جستجو پیدا نشد.')))
          : GridView.builder(
              padding: const EdgeInsets.symmetric(vertical: 2),
              scrollDirection: Axis.vertical,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
                childAspectRatio: 1.20,
              ),
              itemCount: camels.length,
              cacheExtent: 180,
              itemBuilder: (context, index) => _photoCard(camels[index]),
            ),
      ),
      const SizedBox(height: 10),
      const Text('برای نمایش نمودار، تصویر یک شتر را انتخاب کنید.',
        style: TextStyle(fontSize: 11, color: muted)),
    ]);
  }

  Widget _selectedHeader(CamelTimeSlotReport camel) => _panel(
    Row(children: [
      CircleAvatar(radius: 23, backgroundColor: const Color(0xFFF6E9DD),
        child: const Icon(Icons.pets_rounded, color: brown)),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(camel.camelName, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        Text(camel.tagId, textDirection: TextDirection.ltr,
          style: const TextStyle(color: muted, fontSize: 10)),
      ])),
      TextButton.icon(onPressed: () => setState(() { selectedTag = null; selectedZone = null; }),
        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
        label: const Text('تغییر شتر')),
    ]), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
  );

  Widget _timeline(CamelTimeSlotReport camel) {
    final slots = widget.report.timeSlots;
    final count = slots.where((slot) => _isObserved(camel.slotLocations[slot.label])).length;
    // A compact, non-scrolling grid replaces hundreds of separate camel rows.
    final columns = slots.length > 30 ? 6 : slots.length > 12 ? 4 : 3;
    return _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('ساعت‌های مشاهده',
          style: TextStyle(fontWeight: FontWeight.w900, color: ink))),
        Text('$count از ${slots.length} بازه', style: const TextStyle(color: green,
          fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 7),
      const Row(children: [
        Icon(Icons.circle, size: 10, color: green), SizedBox(width: 4),
        Text('دیده‌شده', style: TextStyle(color: muted, fontSize: 10)),
        SizedBox(width: 13), Icon(Icons.circle, size: 10, color: Color(0xFFE4E7EB)),
        SizedBox(width: 4), Text('بدون دریافت', style: TextStyle(color: muted, fontSize: 10)),
      ]),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, constraints) {
        final width = (constraints.maxWidth - (columns - 1) * 6) / columns;
        return Wrap(spacing: 6, runSpacing: 7,
          children: slots.map((slot) {
            final active = _isObserved(camel.slotLocations[slot.label]);
            return Container(width: width, height: 49,
              decoration: BoxDecoration(color: active
                  ? const Color(0xFFDDF4E9) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: active
                  ? const Color(0xFF76C7A5) : const Color(0xFFE8E8E8))),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(slot.label, textDirection: TextDirection.ltr,
                  style: TextStyle(color: active ? green : muted,
                    fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 4),
                Container(width: 23, height: 4, decoration: BoxDecoration(
                  color: active ? green : const Color(0xFFD0D3D6),
                  borderRadius: BorderRadius.circular(3))),
              ]));
          }).toList(),
        );
      }),
    ]));
  }

  bool _isObserved(String? value) =>
      value != null && value.trim().isNotEmpty && value != '-';

  Widget _locations(CamelTimeSlotReport camel) {
    if (_cachedLocationTag != camel.tagId || _cachedLocations == null) {
      _cachedLocations = ReportVisitAnalysisService.calculate(
        tagId: camel.tagId, records: widget.records,
        zones: widget.zones, polygons: widget.polygons,
        day: widget.date, maxGapMinutes: widget.maxGapMinutes);
      _cachedLocationTag = camel.tagId;
    }
    final locations = _cachedLocations!;
    if (locations.isEmpty) return _panel(const Center(child: Padding(
      padding: EdgeInsets.all(16),
      child: Text('هنوز محدوده‌ای تعریف نشده است. محدوده‌ها را از نقشه ثبت کنید.',
        textAlign: TextAlign.center))));
    final active = locations.where((l) => l.id == selectedZone).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('محدوده‌های تعریف‌شده',
          style: TextStyle(fontWeight: FontWeight.w900, color: ink)),
        const SizedBox(height: 4),
        const Text('محدوده روشن یعنی GPS شتر در روز انتخابی داخل آن ثبت شده است.',
          style: TextStyle(fontSize: 11, color: muted)),
        const SizedBox(height: 13),
        SizedBox(height: 109, child: ListView.separated(
          scrollDirection: Axis.horizontal, itemCount: locations.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            final entry = locations[index];
            final selected = selectedZone == entry.id;
            final active = entry.wasVisited;
            final color = entry.forbidden ? const Color(0xFFC44A3D) : green;
            return SizedBox(width: 86, child: InkWell(
              onTap: active ? () => setState(() => selectedZone = entry.id) : null,
              borderRadius: BorderRadius.circular(16),
              child: Column(children: [
                AnimatedContainer(duration: const Duration(milliseconds: 170),
                  width: 66, height: 66,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: active ? color.withValues(alpha: selected ? 0.22 : 0.10)
                      : const Color(0xFFF1F1F1),
                    border: Border.all(color: active ? color : const Color(0xFFE1E1E1),
                      width: selected ? 3 : 1)),
                  child: Icon(entry.forbidden ? Icons.warning_amber_rounded
                    : Icons.location_on_rounded,
                    color: active ? color : const Color(0xFFB5B5B5), size: 29)),
                const SizedBox(height: 6),
                Text(entry.name, textAlign: TextAlign.center, maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10.5,
                    color: active ? ink : muted)),
              ]),
            ));
          },
        )),
      ])),
      const SizedBox(height: 10),
      if (active != null && active.wasVisited) _locationDetail(active)
      else _panel(const Padding(padding: EdgeInsets.all(14),
        child: Text('برای دیدن مدت و ساعت حضور، یکی از محدوده‌های روشن را انتخاب کنید.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 12)))),
    ]);
  }

  Widget _locationDetail(ReportLocationSummary zone) => _panel(
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(zone.forbidden ? Icons.warning_amber_rounded : Icons.place_rounded,
          color: zone.forbidden ? const Color(0xFFC44A3D) : green),
        const SizedBox(width: 7),
        Expanded(child: Text(zone.name, style: const TextStyle(
          color: ink, fontWeight: FontWeight.w900))),
        Text('حدود ${ManagementReportService.minutesText(zone.totalMinutes)}',
          style: const TextStyle(color: green, fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
      const SizedBox(height: 8),
      ...zone.visits.take(8).map((visit) => Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(children: [
          const Icon(Icons.schedule_rounded, size: 15, color: muted),
          const SizedBox(width: 6),
          Expanded(child: Text('شروع ${ManagementReportService.timeText(visit.firstSeen)}'
            '   •   پایان ${ManagementReportService.timeText(visit.lastSeen)}',
            style: const TextStyle(fontSize: 11, color: ink))),
          Text('${ManagementReportService.minutesText(visit.estimatedMinutes)}',
            style: const TextStyle(fontSize: 11, color: green)),
        ]),
      )),
      if (zone.visits.length > 8) Text('${zone.visits.length - 8} بازه دیگر',
        style: const TextStyle(color: muted, fontSize: 11)),
      const SizedBox(height: 8),
      const Text('زمان‌ها براساس مشاهده GPS و فاصله معتبر بین دریافت‌ها تخمینی‌اند.',
        style: TextStyle(fontSize: 10, color: muted)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final all = widget.report.timeSlotRows;
    final selected = selectedTag == null ? null :
      all.where((row) => row.tagId == selectedTag).firstOrNull;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 28), children: [
      _selector(),
      const SizedBox(height: 13),
      if (selected == null) _camelChooser() else ...[
        _selectedHeader(selected),
        const SizedBox(height: 12),
        if (locationMode) _locations(selected) else _timeline(selected),
      ],
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        TextButton.icon(onPressed: widget.openPreview,
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: const Text('پیش‌نمایش گزارش')),
        const SizedBox(width: 8),
        TextButton.icon(onPressed: widget.exporting ? null : widget.exportExcel,
          icon: const Icon(Icons.table_chart_outlined, size: 16),
          label: Text(widget.exporting ? 'در حال ساخت…' : 'خروجی اکسل')),
      ]),
    ]);
  }
}
