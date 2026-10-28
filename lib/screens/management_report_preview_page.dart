import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../models/area_zone.dart';
import '../models/camel_profile.dart';
import '../models/management_report.dart';
import '../utils/jalali_date_ui.dart';

/// The three report sections share the already-calculated daily report.
/// No database read or per-camel network request happens while swiping.
class ManagementReportPreviewPage extends StatefulWidget {
  final ManagementReport report;
  final AppSettings appSettings;
  final DateTime date;
  final List<CamelProfile> profiles;
  final List<AreaZone> zones;

  const ManagementReportPreviewPage({
    super.key,
    required this.report,
    required this.appSettings,
    required this.date,
    required this.profiles,
    required this.zones,
  });

  @override
  State<ManagementReportPreviewPage> createState() =>
      _ManagementReportPreviewPageState();
}

class _ManagementReportPreviewPageState extends State<ManagementReportPreviewPage>
    with SingleTickerProviderStateMixin {
  static const _brown = Color(0xFFAD592F);
  static const _ink = Color(0xFF273B35);
  static const _green = Color(0xFF13825B);
  static const _red = Color(0xFFC54F40);
  static const _muted = Color(0xFF807974);
  static const _paper = Color(0xFFFFFAF6);

  late final TabController _modeController;
  final PageController _problemPageController = PageController();
  final PageController _normalPageController = PageController();
  int _problemPage = 0;
  int _normalPage = 0;

  ManagementReportSummary get _summary => widget.report.summary;
  late final List<CamelLastStatusReport> _problemRows;
  late final List<CamelLastStatusReport> _normalRows;

  @override
  void initState() {
    super.initState();
    _problemRows = widget.report.lastStatusRows
        .where((row) => row.hasProblem).toList(growable: false);
    _normalRows = widget.report.lastStatusRows
        .where((row) => !row.hasProblem).toList(growable: false);
    _modeController = TabController(length: 3, vsync: this);
    _modeController.addListener(_refreshSelectedTab);
  }

  void _refreshSelectedTab() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _modeController.removeListener(_refreshSelectedTab);
    _modeController.dispose();
    _problemPageController.dispose();
    _normalPageController.dispose();
    super.dispose();
  }

  String _reportText() {
    final s = _summary;
    final buffer = StringBuffer()
      ..writeln('گزارش - ${JalaliDateUi.format(widget.date)}')
      ..writeln('ساربان: ${widget.appSettings.shepherdName}')
      ..writeln('شناسه: ${widget.appSettings.shepherdId}')
      ..writeln('کل رکوردهای روز: ${s.totalRecords}')
      ..writeln('شترهای ثبت‌شده: ${s.registeredCamelCount}')
      ..writeln('دیده‌شده: ${s.seenCamelCount}')
      ..writeln('دیده‌نشده: ${s.missingCamelCount}')
      ..writeln('مشکلات مهم: ${s.importantProblemsCount}')
      ..writeln('باتری ضعیف: ${s.lowBatteryCamelCount}')
      ..writeln('تگ باز: ${s.unlockedEventCount}')
      ..writeln('ورود به ممنوعه: ${s.forbiddenEventCount}')
      ..writeln('خارج محدوده: ${s.outsideAllowedEventCount}')
      ..writeln('\nشترهای نیازمند بررسی:');
    for (final row in _problemRows) {
      buffer.writeln('${row.camelName} | ${row.tagId} | ${row.statusText} | ${row.lastLocationText}');
    }
    buffer.writeln('\nشترهای عادی:');
    for (final row in _normalRows) {
      buffer.writeln('${row.camelName} | ${row.tagId} | ${row.statusText}');
    }
    return buffer.toString();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _reportText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('گزارش کپی شد.')),
    );
  }

  Widget _surface(Widget child, {EdgeInsets padding = const EdgeInsets.all(14)}) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0E9E3)),
          boxShadow: const [BoxShadow(
            color: Color(0x0C754631), blurRadius: 15, offset: Offset(0, 5))],
        ),
        child: child,
      );

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF26483E),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.description_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('گزارش گله', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 5),
            Text('${JalaliDateUi.format(widget.date)}  •  ${widget.appSettings.shepherdName}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFE0E9E3), fontSize: 12)),
          ])),
          Text('${_summary.registeredCamelCount} شتر', style: const TextStyle(
            color: Color(0xFFFFE5C8), fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _valueTile(String title, int value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .075),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$value', style: TextStyle(fontSize: 23, color: color,
              fontWeight: FontWeight.w900, height: 1.05)),
            const SizedBox(height: 3),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: _ink, fontWeight: FontWeight.w700)),
          ])),
        ]),
      );

  Widget _summaryTab() {
    final s = _summary;
    return SingleChildScrollView(
      key: const PageStorageKey('report-summary'),
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('خلاصه گزارش', style: TextStyle(
            color: _ink, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _valueTile('رکوردهای روز', s.totalRecords,
              Icons.receipt_long_rounded, const Color(0xFF2174A5))),
            const SizedBox(width: 9),
            Expanded(child: _valueTile('شترهای ثبت‌شده', s.registeredCamelCount,
              Icons.pets_rounded, _brown)),
          ]),
          const SizedBox(height: 9),
          Row(children: [
            Expanded(child: _valueTile('دیده‌شده', s.seenCamelCount,
              Icons.visibility_rounded, _green)),
            const SizedBox(width: 9),
            Expanded(child: _valueTile('دیده‌نشده', s.missingCamelCount,
              Icons.visibility_off_rounded, const Color(0xFFD4882C))),
          ]),
          const SizedBox(height: 9),
          Row(children: [
            Expanded(child: _valueTile('مشکلات مهم', s.importantProblemsCount,
              Icons.warning_amber_rounded, _red)),
            const SizedBox(width: 9),
            Expanded(child: _valueTile('محدوده فعال',
              widget.zones.where((zone) => zone.isActive).length,
              Icons.place_rounded, _green)),
          ]),
        ])),
        const SizedBox(height: 12),
        _surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('جزئیات هشدارهای روز', style: TextStyle(
            color: _ink, fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 8, children: [
            _chip('باتری ضعیف', s.lowBatteryCamelCount, Icons.battery_alert, _brown),
            _chip('تگ باز', s.unlockedEventCount, Icons.lock_open_rounded, _red),
            _chip('ممنوعه', s.forbiddenEventCount, Icons.block_rounded, _red),
            _chip('خارج محدوده', s.outsideAllowedEventCount, Icons.alt_route_rounded,
              const Color(0xFFD4882C)),
          ]),
        ])),
        const SizedBox(height: 12),
        _surface(Row(children: [
          Icon(s.totalRecords == 0 || _problemRows.isNotEmpty
              ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded,
            color: s.totalRecords == 0 || _problemRows.isNotEmpty ? _brown : _green),
          const SizedBox(width: 9),
          Expanded(child: Text(s.totalRecords == 0
              ? 'در تاریخ انتخاب‌شده رکوردی دریافت نشده است.'
              : _problemRows.isEmpty
                ? 'مورد نیازمند بررسی در گزارش ثبت نشده است.'
                : '${_problemRows.length} شتر نیازمند بررسی هستند؛ جزئیات در تب بعدی.',
            style: const TextStyle(color: _ink, height: 1.5, fontSize: 12))),
        ])),
      ]),
    );
  }

  Widget _chip(String label, int value, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(11)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 4),
      Text('$label: $value', style: TextStyle(fontSize: 11,
        fontWeight: FontWeight.w800, color: color)),
    ]),
  );

  Color _statusColor(CamelLastStatusReport row, bool problem) {
    if (!problem) return _green;
    if (row.statusText.contains('ممنوع') || row.statusText.contains('باز')) return _red;
    return const Color(0xFFD4882C);
  }

  /// A compact square: the full details are available on tap, not squeezed
  /// into a tall card. The preview always displays the saved report snapshot.
  Widget _camelCard(CamelLastStatusReport row, bool problem) {
    final color = _statusColor(row, problem);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        key: ValueKey('report-camel-${row.tagId}'),
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showCamelDetails(row, problem),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withValues(alpha: .23)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(problem ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded, color: color, size: 16),
                ),
                const Spacer(),
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ]),
              const Spacer(),
              Text(row.camelName, maxLines: 2, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(color: _ink, fontSize: 12,
                  fontWeight: FontWeight.w900, height: 1.2)),
              const SizedBox(height: 4),
              Directionality(textDirection: TextDirection.ltr,
                child: Text(row.tagId, maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 10, color: _muted))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .085),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(row.statusText,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: color,
                    fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showCamelDetails(CamelLastStatusReport row, bool problem) {
    final color = _statusColor(row, problem);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(problem ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded, color: color),
              const SizedBox(width: 9),
              Expanded(child: Text(row.camelName, style: const TextStyle(
                color: _ink, fontSize: 18, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 6),
            SelectableText(row.tagId, textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
              style: const TextStyle(color: _muted, fontSize: 13)),
            const SizedBox(height: 12),
            _surface(Column(children: [
              _sheetDetail('وضعیت', row.statusText),
              const Divider(height: 16),
              _sheetDetail('آخرین مشاهده', row.lastSeenText),
              const Divider(height: 16),
              _sheetDetail('آخرین مکان', row.lastLocationText),
              const Divider(height: 16),
              _sheetDetail('باتری', row.batteryText),
              const Divider(height: 16),
              _sheetDetail('قفل', row.lockText),
            ])),
          ]),
        )),
      ),
    );
  }

  Widget _sheetDetail(String label, String value) => Row(children: [
    Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
    const SizedBox(width: 12),
    Expanded(child: Text(value.trim().isEmpty ? '—' : value,
      textAlign: TextAlign.left,
      style: const TextStyle(color: _ink, fontSize: 12,
        fontWeight: FontWeight.w700))),
  ]);

  Widget _dots(int current, int count, ValueChanged<int> onTap) {
    if (count <= 1) return const SizedBox(height: 14);
    final first = math.max(0, math.min(current - 2, count - 5));
    final last = math.min(count, first + 5);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (int index = first; index < last; index++)
        InkWell(onTap: () => onTap(index), borderRadius: BorderRadius.circular(50),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: index == current ? 19 : 7, height: 7,
            decoration: BoxDecoration(
              color: index == current ? _brown : const Color(0xFFD9D0C9),
              borderRadius: BorderRadius.circular(9)),
          ),
        ),
      const SizedBox(width: 9),
      Text('${current + 1} / $count', textDirection: TextDirection.ltr,
        style: const TextStyle(fontSize: 10, color: _muted)),
    ]);
  }

  Widget _camelSection({required bool problem}) {
    final rows = problem ? _problemRows : _normalRows;
    final controller = problem ? _problemPageController : _normalPageController;
    final current = problem ? _problemPage : _normalPage;
    final title = problem ? 'شترهای نیازمند بررسی' : 'شترهای عادی';
    final color = problem ? _red : _green;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _surface(Row(children: [
          Icon(problem ? Icons.report_problem_outlined : Icons.verified_outlined,
            color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(color: _ink,
            fontSize: 14, fontWeight: FontWeight.w900))),
          Text('${rows.length} شتر', style: TextStyle(color: color,
            fontSize: 12, fontWeight: FontWeight.w800)),
        ]), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
        const SizedBox(height: 10),
        Expanded(child: rows.isEmpty
          ? _surface(Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(problem ? Icons.check_circle_outline_rounded : Icons.pets_outlined,
                size: 34, color: _muted),
              const SizedBox(height: 9),
              Text(problem ? 'شتری نیازمند بررسی نیست.' : 'شتر عادی برای این روز وجود ندارد.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 13)),
            ])))
          : LayoutBuilder(builder: (context, constraints) {
              // Up to 3 x 3 square cards per page. Shorter screens show fewer
              // rows instead of making a tall scrolling list or overflowing.
              const gap = 8.0;
              final columns = constraints.maxWidth >= 320 ? 3 : 2;
              final fullSize = (constraints.maxWidth - gap * (columns - 1)) / columns;
              const footerHeight = 46.0;
              final availableHeight = math.max(0.0, constraints.maxHeight - footerHeight);
              final fitRows = ((availableHeight + gap) / (fullSize + gap)).floor();
              final rowCount = fitRows.clamp(1, 3).toInt();
              final perPage = columns * rowCount;
              final pageCount = (rows.length / perPage).ceil();
              final shownPage = current.clamp(0, pageCount - 1).toInt();
              final squareSize = math.max(0.0, math.min(fullSize,
                (availableHeight - gap * (rowCount - 1)) / rowCount));
              final gridWidth = columns * squareSize + gap * (columns - 1);
              final gridHeight = rowCount * squareSize + gap * (rowCount - 1);

              return Column(children: [
                Expanded(child: PageView.builder(
                  key: PageStorageKey(problem ? 'problem-camels-grid'
                    : 'normal-camels-grid'),
                  controller: controller,
                  itemCount: pageCount,
                  onPageChanged: (index) => setState(() {
                    if (problem) { _problemPage = index; }
                    else { _normalPage = index; }
                  }),
                  itemBuilder: (context, pageIndex) {
                    final first = pageIndex * perPage;
                    final length = math.min(perPage, rows.length - first);
                    return Align(alignment: Alignment.topCenter,
                      child: SizedBox(width: gridWidth, height: gridHeight,
                        child: GridView.builder(
                          key: ValueKey('report-grid-${problem ? 'problem' : 'normal'}-$pageIndex'),
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: gap,
                            mainAxisSpacing: gap,
                            childAspectRatio: 1,
                          ),
                          itemCount: length,
                          itemBuilder: (context, itemIndex) => _camelCard(
                            rows[first + itemIndex], problem),
                        ),
                      ),
                    );
                  },
                )),
                const SizedBox(height: 9),
                _dots(shownPage, pageCount, (index) => controller.animateToPage(index,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic)),
                const SizedBox(height: 5),
                const Text('ورق بزنید؛ برای جزئیات، کارت شتر را لمس کنید.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: _muted)),
              ]);
            })),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        title: const Text('پیش‌نمایش گزارش'),
        centerTitle: true,
        backgroundColor: const Color(0xFF26483E),
        foregroundColor: Colors.white,
        actions: [IconButton(onPressed: _copy,
          tooltip: 'کپی متن گزارش', icon: const Icon(Icons.copy_rounded))],
      ),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Column(children: [
            _header(),
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFFF1E9E1),
                borderRadius: BorderRadius.circular(15)),
              child: TabBar(
                controller: _modeController,
                isScrollable: false,
                dividerHeight: 0,
                labelPadding: EdgeInsets.zero,
                labelColor: Colors.white,
                unselectedLabelColor: _ink,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(color: _brown,
                  borderRadius: BorderRadius.circular(12)),
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                tabs: const [
                  Tab(text: 'خلاصه'),
                  Tab(text: 'نیازمند بررسی'),
                  Tab(text: 'عادی'),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(child: TabBarView(controller: _modeController, children: [
              _summaryTab(),
              _camelSection(problem: true),
              _camelSection(problem: false),
            ])),
          ]),
        ),
      )),
    ),
  );
}
