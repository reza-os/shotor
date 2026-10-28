import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/camel_detail.dart';
import '../models/live_herd_status.dart';
import '../models/tag_record.dart';
import '../services/antenna_session_controller.dart';
import '../services/camel_detail_service.dart';
import '../services/live_herd_status_service.dart';
import '../services/record_day_service.dart';
import '../services/tag_records_events.dart';
import '../services/unseen_reconciliation.dart';
import 'all_received_records_page.dart';
import 'camel_detail_info_page.dart';
import 'received_record_detail_page.dart';
import 'map_page.dart';

class LiveHerdPage extends StatefulWidget {
  /// In the main shell, opens the existing map tab instead of creating a second map.
  final ValueChanged<String>? onShowCamelRoute;

  const LiveHerdPage({super.key, this.onShowCamelRoute});

  @override
  State<LiveHerdPage> createState() => _LiveHerdPageState();
}

class _LiveHerdPageState extends State<LiveHerdPage> with WidgetsBindingObserver {
  final AntennaSessionController receiver = AntennaSessionController.instance;
  final TextEditingController liveSearchController = TextEditingController();

  LiveHerdStatus? status;

  Timer? _dayChangeTimer;
  Timer? _unseenTimer;
  static const _unseenIntervalKey = 'herd_unseen_interval_minutes';
  int _unseenIntervalMinutes = 5;
  Timer? receiverRefreshDebounce;

  bool isLoading = true;
  bool isRefreshing = false;
  bool receiverExpanded = false;
  // Prevent double taps while the connection request is being prepared.
  bool _connectTapPending = false;
  String selectedLiveFilter = 'all';
  int _lastReceiverRecordCount = -1;
  Timer? _uiThrottle;
  bool _statusDirty = false;
  final Set<String> expandedCamels = <String>{};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    receiver.addListener(_onReceiverChanged);
    TagRecordsEvents.revision.addListener(_onTagChanged);
    unawaited(receiver.initialize());

    _scheduleDayBoundary();
    unawaited(initializePage());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayChangeTimer?.cancel();
    _unseenTimer?.cancel();
    receiverRefreshDebounce?.cancel();
    receiver.removeListener(_onReceiverChanged);
    TagRecordsEvents.revision.removeListener(_onTagChanged);
    _uiThrottle?.cancel();
    liveSearchController.dispose();
    super.dispose();
  }

  void _onTagChanged() => _scheduleRefresh();

  void _scheduleRefresh() {
    if (_uiThrottle?.isActive == true) {
      _statusDirty = true;
      return;
    }
    _uiThrottle = Timer(const Duration(milliseconds: 1200), () async {
      if (!mounted) return;
      await refreshStatus();
      if (_statusDirty) {
        _statusDirty = false;
        _scheduleRefresh();
      }
    });
  }

  void _onReceiverChanged() {
    if (!mounted) return;
    if (receiver.recordCount != _lastReceiverRecordCount) {
      _lastReceiverRecordCount = receiver.recordCount;
      _scheduleRefresh();
    }
    // Limit screen updates during bursts, but keep connection buttons fresh.
    if (receiverRefreshDebounce?.isActive == true) return;
    receiverRefreshDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  /// Reload settings, then calculate freshness from the latest phone reception.
  Future<void> initializePage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _unseenIntervalMinutes = UnseenReconciliation.normalizeInterval(
          prefs.getInt(_unseenIntervalKey) ?? 5);
    } catch (_) {
      // Keep the safe default if preferences are not yet available.
    }
    if (!mounted) return;
    await refreshStatus();
  }

  /// Schedule the next exact expiry, even when the antenna stays silent.
  /// There is no repeated full DB scan for every second or every packet.
  void _scheduleUnseenReconciliation() {
    _unseenTimer?.cancel();
    if (!mounted || status == null) return;
    final now = RecordDayService.today;
    final due = UnseenReconciliation.nextExpiry(
      seenReceivedTimes: status!.camels
          .where((camel) => camel.seenInSession)
          .map((camel) => camel.lastSeenAt),
      now: now,
      intervalMinutes: _unseenIntervalMinutes,
    );
    if (due == null) return;
    final delay = due.difference(now);
    _unseenTimer = Timer(delay + const Duration(milliseconds: 250), () {
      if (mounted) unawaited(refreshStatus());
    });
  }

  Future<void> _changeUnseenInterval(int minutes) async {
    _unseenIntervalMinutes = UnseenReconciliation.normalizeInterval(minutes);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unseenIntervalKey, _unseenIntervalMinutes);
    } catch (_) {
      // The selected interval continues to work in this session.
    }
    if (!mounted) return;
    await refreshStatus();
  }

  void _scheduleDayBoundary() {
    _dayChangeTimer?.cancel();
    // A calendar day is defined by Iran wall-clock time, not phone timezone.
    final wallClock = RecordDayService.today;
    final wallClockAsUtc = DateTime.utc(
      wallClock.year, wallClock.month, wallClock.day,
      wallClock.hour, wallClock.minute, wallClock.second,
      wallClock.millisecond, wallClock.microsecond,
    );
    final nextDay = DateTime.utc(
      wallClock.year, wallClock.month, wallClock.day + 1,
    );
    _dayChangeTimer = Timer(
      nextDay.difference(wallClockAsUtc) + const Duration(milliseconds: 250),
      () {
        if (!mounted) return;
        _scheduleRefresh();
        _scheduleDayBoundary();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleDayBoundary();
      _scheduleRefresh();
    }
  }

  Future<void> refreshStatus() async {
    if (isRefreshing) {
      // No concurrent DB scans while many tags arrive at once.
      _statusDirty = true;
      return;
    }
    if (mounted) setState(() => isRefreshing = true);
    try {
      final nextStatus = await LiveHerdStatusService.buildStatus(
        unseenIntervalMinutes: _unseenIntervalMinutes,
      );
      if (!mounted) return;
      setState(() {
        status = nextStatus;
        isLoading = false;
      });
      _scheduleUnseenReconciliation();
    } finally {
      if (mounted) setState(() => isRefreshing = false);
      if (mounted && _statusDirty) {
        _statusDirty = false;
        _scheduleRefresh();
      }
    }
  }

  Future<void> _connect() async {
    if (_connectTapPending || receiver.isAntennaConnecting ||
        receiver.isAntennaConnected) {
      return;
    }

    // Disable immediately (before connect() reaches its async Wi-Fi setup).
    setState(() => _connectTapPending = true);
    try {
      final connected = await receiver.connect();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connected ? 'آنتن متصل شد و آماده دریافت است.' : receiver.antennaStatus,
          ),
          backgroundColor:
              connected ? const Color(0xFF23845B) : const Color(0xFFC44F43),
        ),
      );
    } finally {
      if (mounted) setState(() => _connectTapPending = false);
    }
  }

  Future<void> _disconnect() async {
    await receiver.disconnect();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('اتصال آنتن قطع شد.')),
    );
  }

  Color levelColor(LiveCamelLevel level) {
    switch (level) {
      case LiveCamelLevel.normal:
        return const Color(0xFF23845B);
      case LiveCamelLevel.warning:
        return const Color(0xFFE39A28);
      case LiveCamelLevel.danger:
        return const Color(0xFFD95D4F);
      case LiveCamelLevel.unseen:
        return const Color(0xFF8D8580);
    }
  }

  String twoDigit(int value) => value.toString().padLeft(2, '0');
  String timeText(DateTime value) => '${twoDigit(value.hour)}:${twoDigit(value.minute)}';

  Future<void> openCamelInfo(LiveCamelStatus camel) async {
    final detail = await CamelDetailService.getDetailByTagId(camel.tagId) ??
        CamelDetail.emptyForTag(camel.tagId);
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CamelDetailInfoPage.byValues(
          detail: detail,
          camelName: camel.camelName,
          camelNo: camel.camelNo,
          tagId: camel.tagId,
        ),
      ),
    );
  }

  void _showCamelRoute(LiveCamelStatus camel) {
    // Reuse the map tab when available, preserving its day picker and GPS path.
    if (widget.onShowCamelRoute != null) {
      widget.onShowCamelRoute!(camel.tagId);
      return;
    }
    // Some older app entry points open the herd as a separate route.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapPage(initialRouteTagId: camel.tagId),
      ),
    );
  }

  void _showCamelPhoto(LiveCamelStatus camel) {
    final path = camel.photoPath.trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برای این شتر هنوز عکسی ثبت نشده است.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        backgroundColor: const Color(0xFF211D1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      camel.camelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'بستن',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: (MediaQuery.sizeOf(dialogContext).height * 0.60)
                  .clamp(200.0, 550.0).toDouble(),
              width: double.infinity,
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text(
                      'عکس شتر در حافظه گوشی پیدا نشد.',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'برای بزرگ‌نمایی از دو انگشت استفاده کنید',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool camelMatchesSearch(LiveCamelStatus camel) {
    final query = liveSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return camel.camelName.toLowerCase().contains(query) ||
        camel.camelNo.toLowerCase().contains(query) ||
        camel.tagId.toLowerCase().contains(query) ||
        camel.statusText.toLowerCase().contains(query) ||
        camel.lastLocationText.toLowerCase().contains(query);
  }

  bool camelMatchesFilter(LiveCamelStatus camel) {
    switch (selectedLiveFilter) {
      case 'seen':
        return camel.seenInSession;
      case 'active':
        return camel.activeToday;
      case 'missing':
        return camel.missing;
      case 'danger':
        return camel.level == LiveCamelLevel.danger;
      case 'all':
      default:
        return true;
    }
  }

  List<LiveCamelStatus> visibleLiveCamels(LiveHerdStatus current) {
    return current.camels
        .where((camel) => camelMatchesSearch(camel) && camelMatchesFilter(camel))
        .toList();
  }

  void selectFilter(String value) {
    setState(() {
      selectedLiveFilter = selectedLiveFilter == value ? 'all' : value;
    });
  }

  Widget _surface({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E8E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D3218).withValues(alpha: 0.055),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget buildReceiverPanel() {
    final latest = receiver.latestRecord;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFF1F8FD), Color(0xFFFFFBF7)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCEAF3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF315C78).withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  _ConnectionButton(
                    icon: receiver.isAntennaConnecting
                        ? Icons.sync_rounded
                        : Icons.link_rounded,
                    color: const Color(0xFF23845B),
                    tooltip: receiver.isAntennaConnected
                        ? 'آنتن متصل است'
                        : (receiver.isAntennaConnecting || _connectTapPending)
                            ? 'در حال اتصال...'
                            : 'اتصال به آنتن',
                    enabled: !receiver.isAntennaConnected &&
                        !receiver.isAntennaConnecting &&
                        !_connectTapPending,
                    onTap: _connect,
                  ),
                  const SizedBox(height: 8),
                  _ConnectionButton(
                    icon: Icons.link_off_rounded,
                    color: const Color(0xFFD95D4F),
                    tooltip: 'قطع',
                    enabled: receiver.isAntennaConnected,
                    onTap: _disconnect,
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.15,
                  children: [
                    _ReceiverMetric(
                      icon: Icons.receipt_long_rounded,
                      label: 'رکوردها',
                      value: '${receiver.recordCount}',
                      color: const Color(0xFF2C6EAA),
                    ),
                    _ReceiverMetric(
                      icon: Icons.content_copy_rounded,
                      label: 'تکراری',
                      value: '${receiver.duplicateCount}',
                      color: const Color(0xFF9A6BC7),
                    ),
                    _ReceiverMetric(
                      icon: receiver.isAntennaConnected
                          ? Icons.wifi_rounded
                          : Icons.wifi_off_rounded,
                      label: 'اتصال',
                      value: receiver.isAntennaConnected ? 'وصل' : 'قطع',
                      color: receiver.isAntennaConnected
                          ? const Color(0xFF23845B)
                          : const Color(0xFFD95D4F),
                    ),
                    _ReceiverMetric(
                      icon: receiver.gpsReady
                          ? Icons.gps_fixed_rounded
                          : Icons.gps_not_fixed_rounded,
                      label: 'GPS گوشی',
                      value: receiver.isGettingLocation
                          ? 'در حال دریافت'
                          : receiver.gpsReady
                              ? 'آماده'
                              : 'نامعتبر',
                      color: receiver.gpsReady
                          ? const Color(0xFF23845B)
                          : const Color(0xFFE39A28),
                      onTap: () => unawaited(receiver.refreshGpsStatus()),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  receiver.antennaStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF55636E),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AllReceivedRecordsPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: const Text('تمام رکوردها'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2C6EAA),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 2),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() => receiverExpanded = !receiverExpanded),
                child: AnimatedRotation(
                  turns: receiverExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F2FA),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD3E7F5)),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF2C6EAA),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!receiver.gpsReady)
            InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => unawaited(receiver.refreshGpsStatus()),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  const Icon(Icons.gps_not_fixed_rounded,
                      size: 14, color: Color(0xFFB97C2E)),
                  const SizedBox(width: 5),
                  Expanded(child: Text(receiver.gpsDetails,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5,
                          color: Color(0xFF946D42)))),
                  const Icon(Icons.refresh_rounded,
                      size: 15, color: Color(0xFFB97C2E)),
                ]),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: receiverExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: latest == null
                        ? const _EmptyLatestRecord()
                        : _LatestRecordCard(record: latest),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget buildStatusFilters(LiveHerdStatus current) {
    return Row(
      children: [
        Expanded(
          child: _RoundFilter(
            label: 'دیده شده',
            value: '${current.seenInSessionCount}/${current.totalCamelCount}',
            icon: Icons.visibility_rounded,
            color: const Color(0xFF23845B),
            selected: selectedLiveFilter == 'seen',
            onTap: () => selectFilter('seen'),
          ),
        ),
        Expanded(
          child: _RoundFilter(
            label: 'فعال',
            value: '${current.activeTodayCount}',
            icon: Icons.bolt_rounded,
            color: const Color(0xFF2C6EAA),
            selected: selectedLiveFilter == 'active',
            onTap: () => selectFilter('active'),
          ),
        ),
        Expanded(
          child: _RoundFilter(
            label: 'دیده نشده',
            value: '${current.missingCount}',
            icon: Icons.visibility_off_rounded,
            color: const Color(0xFFE39A28),
            selected: selectedLiveFilter == 'missing',
            onTap: () => selectFilter('missing'),
          ),
        ),
        Expanded(
          child: _RoundFilter(
            label: 'خطر',
            value: '${current.dangerCount}',
            icon: Icons.warning_rounded,
            color: const Color(0xFFD95D4F),
            selected: selectedLiveFilter == 'danger',
            onTap: () => selectFilter('danger'),
          ),
        ),
      ],
    );
  }

  Widget buildUnseenIntervalControl() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Icon(Icons.schedule_rounded, size: 15, color: Color(0xFF9B5535)),
        const SizedBox(width: 5),
        const Text('بازبینی دیده‌نشده‌ها هر',
          style: TextStyle(fontSize: 11, color: Color(0xFF7D746E))),
        PopupMenuButton<int>(
          tooltip: 'فاصله محاسبه شترهای دیده‌نشده',
          initialValue: _unseenIntervalMinutes,
          onSelected: (value) => unawaited(_changeUnseenInterval(value)),
          itemBuilder: (_) => UnseenReconciliation.allowedIntervals
              .map((minutes) => PopupMenuItem<int>(
                value: minutes,
                child: Text('$minutes دقیقه'),
              )).toList(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$_unseenIntervalMinutes دقیقه',
                style: const TextStyle(fontWeight: FontWeight.w800,
                  fontSize: 11, color: Color(0xFF9B5535))),
              const Icon(Icons.expand_more_rounded,
                size: 17, color: Color(0xFF9B5535)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget buildSearch() {
    return _surface(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: TextField(
        controller: liveSearchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'جستجو با نام، شماره یا تگ شتر',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9A918B)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7E746F)),
          suffixIcon: liveSearchController.text.trim().isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    liveSearchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget buildCamelGrid(List<LiveCamelStatus> camels) {
    if (camels.isEmpty) {
      return _surface(
        padding: const EdgeInsets.all(18),
        child: const Center(
          child: Text(
            'شتر مطابق این جستجو یا فیلتر پیدا نشد.',
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    final rowCount = (camels.length + 1) ~/ 2;
    return SizedBox(
      height: (rowCount * 190.0).clamp(200.0, 455.0).toDouble(),
      child: Scrollbar(
        child: ListView.builder(
          key: const PageStorageKey('live_herd_camels'),
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(),
          cacheExtent: 240,
          itemCount: rowCount,
          itemBuilder: (context, row) {
            final first = row * 2;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: buildCamelCard(camels[first])),
                  const SizedBox(width: 10),
                  Expanded(child: first + 1 < camels.length
                      ? buildCamelCard(camels[first + 1])
                      : const SizedBox.shrink()),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _miniCamelAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4ED),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: const Color(0xFF9B5535)),
        const SizedBox(height: 2),
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
            color: Color(0xFF7C4D38))),
      ]),
    ),
  );

  Widget buildCamelCard(LiveCamelStatus camel) {
    final color = levelColor(camel.level);
    final expanded = expandedCamels.contains(camel.tagId);

    return InkWell(
      borderRadius: BorderRadius.circular(19),
      onTap: () {
        if (camel.lastRecord != null) {
          ReceivedRecordDetailPage.open(context, camel.lastRecord!);
        } else {
          openCamelInfo(camel);
        }
      },
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: expanded ? color.withValues(alpha: 0.45) : const Color(0xFFF0E8E1),
          width: expanded ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D3218).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      camel.camelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      camel.tagId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: Color(0xFF8B817B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              _CamelAvatar(camel: camel, color: color),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              camel.statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              if (camel.lastRecord != null) ...[
                Icon(Icons.battery_std_rounded, size: 15,
                  color: camel.lastRecord!.isBatteryLow
                      ? const Color(0xFFD97723) : const Color(0xFF13855E)),
                Text(camel.lastRecord!.batteryText,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF9A918B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  camel.lastSeenText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF7D746E), fontSize: 10.5),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  setState(() {
                    if (expanded) {
                      expandedCamels.remove(camel.tagId);
                    } else {
                      expandedCamels.add(camel.tagId);
                    }
                  });
                },
                child: AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.keyboard_arrow_down_rounded, size: 21),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 230),
            curve: Curves.easeOutCubic,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 9),
                        _CompactDetail(
                          icon: Icons.location_on_outlined,
                          text: camel.lastLocationText,
                        ),
                        const SizedBox(height: 7),
                        Row(children: [
                          Expanded(child: _miniCamelAction(
                            icon: Icons.route_rounded,
                            title: 'مسیر',
                            onTap: () => _showCamelRoute(camel),
                          )),
                          const SizedBox(width: 5),
                          Expanded(child: _miniCamelAction(
                            icon: Icons.photo_outlined,
                            title: 'عکس',
                            onTap: () => _showCamelPhoto(camel),
                          )),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          if (camel.lastRecord != null) ...[
                            Expanded(child: _miniCamelAction(
                              icon: Icons.data_object_rounded,
                              title: 'JSON',
                              onTap: () => ReceivedRecordDetailPage.open(
                                context, camel.lastRecord!),
                            )),
                            const SizedBox(width: 5),
                          ],
                          Expanded(child: _miniCamelAction(
                            icon: Icons.info_outline_rounded,
                            title: 'اطلاعات',
                            onTap: () => openCamelInfo(camel),
                          )),
                        ]),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ));
  }

  Widget buildPage(LiveHerdStatus current) {
    final visibleCamels = visibleLiveCamels(current);

    return RefreshIndicator(
      onRefresh: () async {
        await receiver.refreshRecords();
        await refreshStatus();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
        children: [
          buildReceiverPanel(),
          const SizedBox(height: 12),
          buildStatusFilters(current),
          buildUnseenIntervalControl(),
          const SizedBox(height: 8),
          buildSearch(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'وضعیت زنده گله',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
                ),
              ),
              if (selectedLiveFilter != 'all')
                TextButton.icon(
                  onPressed: () => setState(() => selectedLiveFilter = 'all'),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('حذف فیلتر'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8B817B),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              Text(
                '${visibleCamels.length} مورد',
                style: const TextStyle(
                  color: Color(0xFF8B817B),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          buildCamelGrid(visibleCamels),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = status;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF9F5),
        appBar: AppBar(
          title: const Text(
            'گله',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFFFFF9F5),
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          actions: [
            if (isRefreshing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              IconButton(
                tooltip: 'بروزرسانی',
                onPressed: () => unawaited(refreshStatus()),
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
        body: isLoading || current == null
            ? const Center(child: CircularProgressIndicator())
            : buildPage(current),
      ),
    );
  }
}

class _ConnectionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _ConnectionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: enabled ? color.withValues(alpha: 0.12) : const Color(0xFFF2EFED),
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled ? color.withValues(alpha: 0.25) : const Color(0xFFE5DFDB),
            ),
          ),
          child: Icon(icon, size: 21, color: enabled ? color : const Color(0xFFB3AAA5)),
        ),
      ),
    );
  }
}

class _ReceiverMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _ReceiverMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF8B817B), fontSize: 9.5),
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

class _LatestRecordCard extends StatelessWidget {
  final TagRecord record;

  const _LatestRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final lockColor = record.lock == 1 ? const Color(0xFF23845B) : const Color(0xFFD95D4F);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE9F1)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: lockColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.pets_rounded, color: lockColor, size: 21),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.camelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.tagId}  •  ${record.receivedTime}',
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF807771), fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                record.lockText,
                style: TextStyle(color: lockColor, fontSize: 9.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                'باتری ${record.batteryText}',
                style: const TextStyle(color: Color(0xFF807771), fontSize: 9.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyLatestRecord extends StatelessWidget {
  const _EmptyLatestRecord();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Text(
        'هنوز رکوردی دریافت نشده است.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF8B817B), fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _RoundFilter extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _RoundFilter({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 57,
              height: 57,
              decoration: BoxDecoration(
                color: color.withValues(alpha: selected ? 0.17 : 0.09),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? color : color.withValues(alpha: 0.16),
                  width: selected ? 2.2 : 1,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(top: 8, child: Icon(icon, color: color, size: 19)),
                  Positioned(
                    bottom: 7,
                    child: Text(
                      value,
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? color : const Color(0xFF625A55),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CamelAvatar extends StatelessWidget {
  final LiveCamelStatus camel;
  final Color color;

  const _CamelAvatar({required this.camel, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: color.withValues(alpha: 0.7), width: 2),
          ),
          child: ClipOval(
            child: camel.hasPhoto
                ? Image.file(
                    File(camel.photoPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultAvatar(),
                  )
                : _defaultAvatar(),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: color.withValues(alpha: 0.08),
      child: Icon(Icons.pets_rounded, color: color, size: 23),
    );
  }
}

class _CompactDetail extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CompactDetail({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF9A918B)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF6E6661), fontSize: 10.5, height: 1.35),
          ),
        ),
      ],
    );
  }
}
