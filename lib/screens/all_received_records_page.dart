import 'dart:async';
import 'package:flutter/material.dart';
import '../models/tag_record.dart';
import 'received_record_detail_page.dart';
import '../services/local_storage_service.dart';
import '../utils/jalali_date_ui.dart';
import '../services/record_day_service.dart';
import '../services/tag_records_events.dart';

class AllReceivedRecordsPage extends StatefulWidget {
  const AllReceivedRecordsPage({super.key});
  @override
  State<AllReceivedRecordsPage> createState() => _AllReceivedRecordsPageState();
}

class _AllReceivedRecordsPageState extends State<AllReceivedRecordsPage> {
  static const _pageSize = 80;
  final ScrollController _scroll = ScrollController();
  DateTime _day = RecordDayService.today;
  bool _followToday = true;
  bool _loading = false;
  bool _hasMore = true;
  int _requestVersion = 0;
  String _latestKey = RecordDayService.todayKey;
  final List<TagRecord> _records = [];
  Timer? _refreshTimer;
  Timer? _dayTimer;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    TagRecordsEvents.revision.addListener(_onDataChanged);
    _dayTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      if (_followToday && _latestKey != RecordDayService.todayKey) {
        _latestKey = RecordDayService.todayKey;
        _day = RecordDayService.today;
        _resetAndLoad();
      }
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _refreshTimer?.cancel();
    _dayTimer?.cancel();
    TagRecordsEvents.revision.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 300) _loadMore();
  }

  void _onDataChanged() {
    if (!_followToday || _refreshTimer?.isActive == true) return;
    _refreshTimer = Timer(const Duration(seconds: 2), _resetAndLoad);
  }

  void _resetAndLoad() {
    ++_requestVersion;
    _loading = false;
    _hasMore = true;
    setState(() => _records.clear());
    _loadMore();
  }

  Future<void> _pickDay() async {
    final selected = await JalaliDateUi.pick(context,
      initialDate: _day, firstDate: RecordDayService.oldestDay,
      lastDate: RecordDayService.today,
      helpText: 'انتخاب روز رکوردها');
    if (!mounted || selected == null) return;
    _day = selected;
    _followToday = RecordDayService.isToday(selected);
    _resetAndLoad();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    final version = _requestVersion;
    final offset = _records.length;
    try {
      final next = await LocalStorageService.loadRecordsForDay(_day,
        limit: _pageSize, offset: offset);
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _records.addAll(next);
        _hasMore = next.length == _pageSize;
      });
    } catch (_) {
      if (mounted && version == _requestVersion) {
        setState(() => _hasMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خواندن رکوردها ناموفق بود.')));
      }
    } finally {
      if (version == _requestVersion) _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xFFFFF9F5),
      appBar: AppBar(title: const Text('تمام رکوردها'), centerTitle: true,
        backgroundColor: const Color(0xFFFFF9F5),
        actions: [IconButton(tooltip: 'بازخوانی',
          onPressed: _resetAndLoad, icon: const Icon(Icons.refresh_rounded))]),
      body: Column(children: [
        ListTile(
          leading: const Icon(Icons.calendar_month_rounded,
            color: Color(0xFFB65C2E)),
          title: Text('رکوردهای ${JalaliDateUi.format(_day)}${_followToday ? ' • امروز' : ''}'),
          subtitle: const Text('امروز و ۹ روز گذشته'),
          trailing: const Icon(Icons.keyboard_arrow_down_rounded),
          onTap: _pickDay,
        ),
        Expanded(child: _records.isEmpty && !_loading
          ? const Center(child: Text('برای این روز رکوردی ثبت نشده است.'))
          : ListView.separated(controller: _scroll,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              itemCount: _records.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                if (index == _records.length) {
                  return const Center(child: Padding(padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator()));
                }
                return _RecordCard(record: _records[index]);
              })),
      ]),
    ),
  );
}

class _RecordCard extends StatelessWidget {
  final TagRecord record;

  const _RecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final attached = record.lock == 1;
    final statusColor = attached
        ? const Color(0xFF198754)
        : record.lock == null
            ? const Color(0xFF8B817B)
            : const Color(0xFFD95D4F);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => ReceivedRecordDetailPage.open(context, record),
      child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1E8E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF67361F).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.pets_rounded, color: statusColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.camelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      record.receivedTime,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${record.tagId}  •  شماره ${record.camelNo}',
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _MiniChip(
                      icon: attached
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      text: record.lockText,
                      color: statusColor,
                    ),
                    _MiniChip(
                      icon: Icons.battery_5_bar_rounded,
                      text: record.batteryText,
                      color: record.isBatteryLow
                          ? const Color(0xFFE29522)
                          : const Color(0xFF198754),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MiniChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
