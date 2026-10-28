import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'services/sms_service.dart';
import 'auth/auth_gate.dart';
import 'auth/app_auth_controller.dart';

import 'models/area_zone.dart';
import 'services/area_zone_service.dart';
import 'services/polygon_zone_service.dart';

import 'services/sms_auto_sender_service.dart';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'models/camel_profile.dart';
import 'services/camel_profile_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart'
    show PersianMaterialLocalizations, PersianCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/tag_record.dart';
import 'utils/jalali_date_ui.dart';
import 'utils/iran_time.dart';
import 'models/app_alert.dart';

import 'services/record_day_service.dart';
import 'services/local_storage_service.dart';

import 'services/alert_service.dart';
import 'models/app_settings.dart';
import 'services/app_setting_service.dart';
import 'models/antenna_log.dart';
import 'services/antenna_log_service.dart';



import 'models/management_report.dart';
import 'models/polygon_zone.dart';
import 'screens/management_report_dashboard.dart';
import 'screens/management_report_preview_page.dart';
import 'services/management_report_service.dart';

import 'services/management_excel_export_service.dart';

import 'screens/live_herd_page.dart';
import 'screens/map_page.dart';


import 'screens/camel_info_dashboard_page.dart';
import 'screens/home_dashboard_view.dart';
import 'screens/unified_settings_page.dart';
import 'screens/all_received_records_page.dart';
import 'services/antenna_session_controller.dart';
import 'widgets/floating_nav_bar.dart';
import 'services/saraban_export_service.dart';
import 'services/herd_settings_service.dart';

import 'services/tag_records_events.dart';





void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SmsAutoSenderService.initialize();
  } catch (_) {
    // SMS scheduler failure must never prevent starting the herd app.
  }
  runApp(const SarabanApp());
}

class AppColors {
  static const Color primary = Color(0xFF062C5E);
  static const Color secondary = Color(0xFF003B7A);
  static const Color success = Color(0xFF008B62);
  static const Color warning = Color(0xFFE87500);
  static const Color danger = Color(0xFFD32F2F);
  static const Color background = Color(0xFFF5F7FA);
  static const Color card = Colors.white;
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5EAF0);

  static const Color successLight = Color(0xFFEAF8F2);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color dangerLight = Color(0xFFFFEBEE);
  static const Color blueLight = Color(0xFFEAF1FB);
}

BoxDecoration cardDecoration({
  Color color = AppColors.card,
  double radius = 20,
  bool bordered = false,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: bordered
        ? Border.all(
            color: AppColors.border,
          )
        : null,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

class SarabanApp extends StatelessWidget {
  const SarabanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saraban',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        PersianMaterialLocalizations.delegate,
        PersianCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5A3)),
      ),
      home: const AuthGate(
        shell: Directionality(
          textDirection: TextDirection.rtl,
          child: SarabanShell(),
        ),
      ),
    );
  }
}

class SarabanShell extends StatefulWidget {
  const SarabanShell({super.key});

  @override
  State<SarabanShell> createState() => _SarabanShellState();
}

class _SarabanShellState extends State<SarabanShell> {
  int selectedIndex = 0;

  final GlobalKey<MapPageState> _mapPageKey = GlobalKey<MapPageState>();

  late final List<Widget> pages = [
    const HomePage(),
    LiveHerdPage(onShowCamelRoute: _showCamelRouteOnMapTab),
    MapPage(key: _mapPageKey),
    const MorePage(),
  ];

  void _showCamelRouteOnMapTab(String tagId) {
    setState(() => selectedIndex = 2);
    // Wait until the IndexedStack displays the already-mounted map tab.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapPageKey.currentState?.showCamelRoute(tagId);
    });
  }

  @override
  void initState() {
    super.initState();

    unawaited(AntennaSessionController.instance.initialize());
    unawaited(SmsAutoSenderService.start().catchError((Object _) {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F5),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFCF9),
              Color(0xFFFFF7F2),
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: IndexedStack(
              index: selectedIndex,
              children: pages,
            ),
          ),
        ),
      ),
      bottomNavigationBar: ColoredBox(
        color: const Color(0xFFFFF7F2),
        child: FloatingNavBar(
          currentIndex: selectedIndex,
          onTap: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
        ),
      ),
    );
  }
}
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLoading = true;
  List<TagRecord> records = [];
  List<TagRecord> _mostRecentToday = [];
  int _unsentTodayCount = 0;
  int _homeRequest = 0;

  Timer? homeRefreshTimer;
  Timer? homeRecordsReloadTimer;
  String _homeDayKey = '${IranTime.nowWallClock().year}-${IranTime.nowWallClock().month}-${IranTime.nowWallClock().day}';

  void _onRecordsChanged() {
    if (homeRecordsReloadTimer?.isActive == true) return;
    homeRecordsReloadTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) unawaited(loadRecords());
    });
  }

  @override
  void initState() {
    super.initState();

    TagRecordsEvents.revision.addListener(_onRecordsChanged);
    loadRecords();

    homeRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      final today = IranTime.nowWallClock();
      final dayKey = '${today.year}-${today.month}-${today.day}';
      if (_homeDayKey != dayKey) {
        _homeDayKey = dayKey;
        unawaited(loadRecords());
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    TagRecordsEvents.revision.removeListener(_onRecordsChanged);
    homeRecordsReloadTimer?.cancel();
    homeRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadRecords() async {
    final request = ++_homeRequest;
    final day = IranTime.nowWallClock();
    final results = await Future.wait<dynamic>([
      LocalStorageService.loadLatestByTagForDay(day),
      LocalStorageService.loadLatestRecordsForDay(day, limit: 3),
      LocalStorageService.countPendingRecordsForDay(day),
    ]);
    if (!mounted || request != _homeRequest) return;
    setState(() {
      records = results[0] as List<TagRecord>;
      _mostRecentToday = results[1] as List<TagRecord>;
      _unsentTodayCount = results[2] as int;
      isLoading = false;
    });
  }

  DateTime? recordDateTime(TagRecord record) {
    final text = record.receivedDateTime.trim();

    if (text.isEmpty) return null;

    return IranTime.parseForDisplay(text);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Home loads only today's indexed records. Do not apply a second date
  // filter, which would discard antenna packets without a reliable ESP clock.
  List<TagRecord> getTodayRecords(List<TagRecord> source) => source;

  List<TagRecord> getLatestTodayRecordsByTag(List<TagRecord> source) {
    final todayRecords = getTodayRecords(source);

    final result = <String, TagRecord>{};

    for (final record in todayRecords) {
      if (!result.containsKey(record.tagId)) {
        result[record.tagId] = record;
      }
    }

    return result.values.toList();
  }

  int getTodayQueuedCount(List<TagRecord> source) {
    final todayRecords = getTodayRecords(source);

    return todayRecords.where((record) {
      return record.sendStatus == TagSendStatus.queued ||
          record.sendStatus == TagSendStatus.failed;
    }).length;
  }

  int getTodayLowBatteryCount(List<TagRecord> source) {
    final latestTodayRecords = getLatestTodayRecordsByTag(source);

    return latestTodayRecords.where((record) {
      return record.isBatteryLow;
    }).length;
  }

  String getTodayLastReceiveText(List<TagRecord> source) {
    final todayRecords = getTodayRecords(source);

    if (todayRecords.isEmpty) return '-';

    return todayRecords.first.receivedTime;
  }

  void goToTab(int index) {
    final shellState = context.findAncestorStateOfType<_SarabanShellState>();

    shellState?.setState(() {
      shellState.selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final todayRecords = getTodayRecords(records);
    final latestTodayTags = getLatestTodayRecordsByTag(records);

    final totalTags = latestTodayTags.length;
    final lowBatteryCount = getTodayLowBatteryCount(records);
    final queuedCount = _unsentTodayCount;
    final lastReceiveText = getTodayLastReceiveText(_mostRecentToday);

    return HomeDashboardView(
      isLoading: isLoading,
      totalTags: totalTags,
      lowBatteryCount: lowBatteryCount,
      queuedCount: queuedCount,
      lastReceiveText: lastReceiveText,
      recentRecords: _mostRecentToday,
      onRefresh: loadRecords,
      onOpenHerd: () => goToTab(1),
      onOpenManagementReport: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ManagementReportPage(),
          ),
        );
      },
      onOpenMap: () => goToTab(2),
      onOpenCamelDashboard: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CamelInfoDashboardPage(),
          ),
        );
      },
      onOpenRecords: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AllReceivedRecordsPage(),
          ),
        );
      },
      onOpenSettings: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SystemSettingsPage(),
          ),
        );
      },
    );
  }
}




// ReceivePage removed: antenna session is now app-level and rendered in LiveHerdPage.

class TagDetailPage extends StatefulWidget {
  final TagRecord record;

  const TagDetailPage({super.key, required this.record});

  @override
  State<TagDetailPage> createState() => _TagDetailPageState();
}

class _TagDetailPageState extends State<TagDetailPage> {
  late TagRecord record;

  @override
  void initState() {
    super.initState();
    record = widget.record;
  }

  Future<void> editCamelName() async {
    final camelNoController = TextEditingController(text: record.camelNo);
    final camelNameController = TextEditingController(text: record.camelName);

    final result = await showDialog<CamelProfile>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('ویرایش نام شتر'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.tagId,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF062C5E),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: camelNoController,
                  decoration: const InputDecoration(
                    labelText: 'شماره شتر',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: camelNameController,
                  decoration: const InputDecoration(
                    labelText: 'نام شتر',
                    hintText: 'مثلاً شتر قهوه‌ای',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('انصراف'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final camelNo = camelNoController.text.trim().isEmpty
                      ? record.camelNo
                      : camelNoController.text.trim();

                  final camelName = camelNameController.text.trim().isEmpty
                      ? 'شتر شماره $camelNo'
                      : camelNameController.text.trim();

                  Navigator.of(context).pop(
                    CamelProfile(
                      tagId: record.tagId,
                      camelNo: camelNo,
                      camelName: camelName,
                    ),
                  );
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('ذخیره'),
              ),
            ],
          ),
        );
      },
    );

    camelNoController.dispose();
    camelNameController.dispose();

    if (result == null) {
      return;
    }

    await CamelProfileService.updateProfile(result);

    await LocalStorageService.updateCamelInfoForTag(
      tagId: result.tagId,
      camelNo: result.camelNo,
      camelName: result.camelName,
    );

    if (!mounted) return;

    setState(() {
      record = record.copyWith(
        camelNo: result.camelNo,
        camelName: result.camelName,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('نام شتر به «${result.camelName}» تغییر کرد.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLowBattery = record.isBatteryLow;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
       appBar: AppBar(
         title: Text('جزئیات تگ ${record.tagId}'),
         centerTitle: true,
         backgroundColor: const Color(0xFF062C5E),
         foregroundColor: Colors.white,
         actions: [
           IconButton(
             onPressed: editCamelName,
             icon: const Icon(Icons.edit_rounded),
             tooltip: 'ویرایش نام شتر',
           ),
         ],
       ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: cardDecoration(),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: const Color(0xFFF3E8D6),
                          child: Text(
                            record.camelNo,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          record.tagId,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF062C5E),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          record.camelName,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isLowBattery
                                ? Colors.red.withValues(alpha: 0.10)
                                : Colors.green.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isLowBattery ? 'نیازمند بررسی باتری' : 'وضعیت عادی',
                            style: TextStyle(
                              color: isLowBattery ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: cardDecoration(),
                    child: Column(
                      children: [
                        DetailRow(
                          icon: Icons.battery_full_rounded,
                          title: 'وضعیت شارژ باتری',
                          value: record.batteryText,
                          valueColor: isLowBattery ? Colors.red : Colors.green,
                        ),
                        DetailRow(
                          icon: Icons.access_time_rounded,
                          title: 'آخرین زمان دریافت',
                          value: record.receivedTime,
                        ),
                        DetailRow(
                          icon: Icons.location_on_rounded,
                          title: 'آخرین محل ثبت‌شده',
                          value: record.locationName,
                        ),
                        if (record.latitude != null && record.longitude != null)
                          DetailRow(
                            icon: Icons.my_location_rounded,
                            title: 'مختصات GPS',
                            value:
                                '${record.latitude!.toStringAsFixed(5)}, ${record.longitude!.toStringAsFixed(5)}',
                          ),
                        if (record.accuracy != null)
                          DetailRow(
                            icon: Icons.gps_fixed_rounded,
                            title: 'دقت موقعیت',
                            value: '${record.accuracy!.toStringAsFixed(1)} متر',
                          ),
                        DetailRow(
                          icon: Icons.network_check_rounded,
                          title: 'قدرت سیگنال',
                          value: '${record.signalPower} از ۵',
                        ),
                        if (record.state != null)
                          DetailRow(
                            icon: Icons.sensors_rounded,
                            title: 'State خام دستگاه',
                            value: record.state.toString(),
                          ),
                        if (record.lock != null)
                          DetailRow(
                            icon: Icons.lock_rounded,
                          title: 'وضعیت بسته بودن تگ',
                            value: record.lockText,
                          ),
                        if (record.counterLock != null)
                          DetailRow(
                            icon: Icons.confirmation_number_rounded,
                            title: 'تعداد باز و بسته شدن تگ',
                            value: record.counterLock.toString(),
                          ),
                        if (record.count != null)
                          DetailRow(
                            icon: Icons.numbers_rounded,
                            title: 'Count خام دستگاه',
                            value: record.count.toString(),
                          ),
                        DetailRow(
                          icon: Icons.cloud_upload_rounded,
                          title: 'وضعیت ارسال',
                          value: record.sendStatusText,
                          valueColor: record.isGood
                              ? Colors.green
                              : Colors.orange,
                        ),
                        DetailRow(
                          icon: Icons.my_location_rounded,
                          title: 'عرض جغرافیایی',
                          value: record.latitude == null
                              ? 'ثبت نشده'
                              : record.latitude!.toStringAsFixed(6),
                        ),
                        DetailRow(
                          icon: Icons.explore_rounded,
                          title: 'طول جغرافیایی',
                          value: record.longitude == null
                              ? 'ثبت نشده'
                              : record.longitude!.toStringAsFixed(6),
                        ),
                        DetailRow(
                          icon: Icons.gps_fixed_rounded,
                          title: 'دقت GPS',
                          value: record.accuracy == null
                              ? 'ثبت نشده'
                              : '${record.accuracy!.toStringAsFixed(1)} متر',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('ارسال مجدد'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF086EBB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.warning_rounded),
                          label: const Text('ثبت هشدار'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE87500),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  const DetailRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE8EDF3))),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF062C5E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  bool isLoading = true;
  bool isSyncing = false;
  AppSettings appSettings = const AppSettings();

  List<TagRecord> allRecords = [];
  DateTime selectedDate = IranTime.nowWallClock();

  @override
  void initState() {
   super.initState();
    loadSavedRecords();
    loadAppSettings();
  }




  Future<void> sendDailySmsSummary() async {
    final records = dailyRecords;

    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('برای این روز رکوردی جهت پیامک وجود ندارد.'),
        ),
      );
      return;
    }

    if (!appSettings.smsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ارسال پیامک در تنظیمات سامانه غیرفعال است.'),
        ),
      );
      return;
    }

    if (appSettings.centerPhone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('شماره مرکز در تنظیمات سامانه ثبت نشده است.'),
        ),
      );
      return;
    }

    final smsText = buildDailySmsSummary();

    try {
      final launched = await SmsService.openSmsApp(
        phoneNumber: appSettings.centerPhone,
        message: smsText,
      );

      if (!mounted) return;

      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('برنامه پیامک روی گوشی باز نشد.'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('برنامه پیامک باز شد. پیام را بررسی و ارسال کن.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در آماده‌سازی پیامک: $e'),
        ),
      );
    }
  }



Future<void> createSystemJson() async {


  final herd =
      await HerdSettingsService.load();


  final settings =
      await AppSettingsService.loadSettings();


  final records =
      await LocalStorageService.loadTagRecords();



  final jsonText =
      SarabanExportService.createJson(

        herd: herd,

        shepherdName:
            settings.shepherdName,

        shepherdId:
            settings.shepherdId,

        deviceId:
            settings.deviceId,

        records: records,

      );



  if(!mounted) return;



  showDialog(

    context: context,

    builder: (_) {

      return AlertDialog(

        title:
            const Text('خروجی سامانه'),


        content:

        SizedBox(

          width: double.maxFinite,

          child:

          SingleChildScrollView(

            child:

            SelectableText(
              jsonText,
            ),

          ),

        ),


        actions:[


          TextButton(

            onPressed:(){

              Clipboard.setData(
                ClipboardData(
                  text: jsonText,
                ),
              );


              Navigator.pop(context);

            },

            child:
              const Text('کپی'),

          ),


        ],

      );

    },

  );

}



  Future<void> loadAppSettings() async {
    final loadedSettings = await AppSettingsService.loadSettings();

    if (!mounted) return;

    setState(() {
      appSettings = loadedSettings;
    });
  }


  Future<void> loadSavedRecords() async {
    final records = await LocalStorageService.loadRecordsForDay(
      selectedDate, limit: 100000);

    if (!mounted) return;

    setState(() {
      allRecords = records;
      isLoading = false;
    });
  }

  DateTime? recordDate(TagRecord record) {
    if (record.receivedDateTime.trim().isEmpty) {
      return null;
    }

    return IranTime.parseForDisplay(record.receivedDateTime);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // The in-memory list is already limited to the selected day in SQLite.
  bool isRecordInSelectedDate(TagRecord record) => true;

  List<TagRecord> get dailyRecords => allRecords;

  String twoDigit(int value) {
    return value.toString().padLeft(2, '0');
  }

  String dateText(DateTime date) {
    return JalaliDateUi.format(date);
  }

  bool get isToday {
    return isSameDay(selectedDate, IranTime.nowWallClock());
  }

  void changeDay(int offset) {
    final next = selectedDate.add(Duration(days: offset));
    if (RecordDayService.key(next).compareTo(RecordDayService.oldestKey) < 0 ||
        RecordDayService.key(next).compareTo(RecordDayService.todayKey) > 0) return;
    setState(() { selectedDate = next; isLoading = true; });
    unawaited(loadSavedRecords());
  }

  void goToToday() {
    setState(() { selectedDate = RecordDayService.today; isLoading = true; });
    unawaited(loadSavedRecords());
  }

  Future<void> syncQueuedRecords() async {
    final todayRecords = dailyRecords;

    final queuedCount = todayRecords
        .where((record) => record.sendStatus == TagSendStatus.queued)
        .length;

    if (queuedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هیچ رکوردی برای این روز در صف ارسال وجود ندارد.'),
        ),
      );
      return;
    }

    setState(() {
      isSyncing = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    final updatedRecords = allRecords.map((record) {
      if (isRecordInSelectedDate(record) &&
          record.sendStatus == TagSendStatus.queued) {
        return record.copyWith(sendStatus: TagSendStatus.sent);
      }

      return record;
    }).toList();

    final selectedIds = allRecords
        .where((r) => isRecordInSelectedDate(r) &&
            r.sendStatus == TagSendStatus.queued && r.dbId != null)
        .map((r) => r.dbId!)
        .toList();
    await LocalStorageService.markSentByIds(selectedIds);

    if (!mounted) return;

    setState(() {
      allRecords = updatedRecords;
      isSyncing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$queuedCount رکورد این روز با موفقیت ارسال شد.'),
      ),
    );
  }

  String buildDailySmsSummary() {
    final records = dailyRecords;

    final totalTags = records.length;

    final queuedCount = records
        .where((record) => record.sendStatus == TagSendStatus.queued)
        .length;

    final lowBatteryRecords = records
        .where((record) => record.isBatteryLow)
        .toList();

    final lowBatteryCount = lowBatteryRecords.length;

    final unlockedCount = records.where((record) => record.lock == 0).length;

    final lastLocation = records.isNotEmpty
        ? records.first.locationName
        : 'نامشخص';

    final problemTags = lowBatteryRecords
        .map((record) => record.tagId)
        .take(3)
        .join(',');

    return 'SARABAN REPORT\n'
        'Date:${dateText(selectedDate)}\n'
        'Tags:$totalTags\n'
        'Queued:$queuedCount\n'
        'LowBattery:$lowBatteryCount\n'
        'Unlocked:$unlockedCount\n'
        'LastLocation:$lastLocation\n'
        'ProblemTags:${problemTags.isEmpty ? "-" : problemTags}';
  }

  void showSmsSummary() {
    final smsText = buildDailySmsSummary();

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('خلاصه پیامکی گزارش روزانه'),
            content: SelectableText(
              smsText,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontFamily: 'monospace',
                height: 1.6,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('بستن'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await sendDailySmsSummary();
                },
                icon: const Icon(Icons.sms_rounded),
                label: const Text('ارسال پیامک'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008B62),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = dailyRecords;

    final totalTags = records.length;

    final sentCount = records
        .where((r) => r.sendStatus == TagSendStatus.sent)
        .length;

    final queuedCount = records
        .where((r) => r.sendStatus == TagSendStatus.queued)
        .length;

    final lowBatteryCount = records.where((r) => r.isBatteryLow).length;

    final unlockedCount = records.where((r) => r.lock == 0).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('گزارش روزانه'),
          centerTitle: true,
          backgroundColor: const Color(0xFF062C5E),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: loadSavedRecords,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'بارگذاری مجدد',
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: cardDecoration(),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      changeDay(-1);
                                    },
                                    icon: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        const Text(
                                          'تاریخ گزارش',
                                          style: TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          dateText(selectedDate),
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF062C5E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      changeDay(1);
                                    },
                                    icon: const Icon(
                                      Icons.chevron_left_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              if (!isToday) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: goToToday,
                                  icon: const Icon(Icons.today_rounded),
                                  label: const Text('بازگشت به امروز'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (records.isEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFFCC80),
                              ),
                            ),
                            child: Text(
                              'برای تاریخ ${dateText(selectedDate)} رکوردی ثبت نشده است.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF8A4B00),
                                fontWeight: FontWeight.bold,
                                height: 1.7,
                              ),
                            ),
                          ),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.35,
                          children: [
                            ReportSummaryCard(
                              title: 'رکوردهای این روز',
                              value: totalTags.toString(),
                              subtitle: 'دریافت‌شده',
                              icon: Icons.pets_rounded,
                              color: const Color(0xFF16965C),
                            ),
                            ReportSummaryCard(
                              title: 'ارسال‌شده',
                              value: sentCount.toString(),
                              subtitle: 'موفق',
                              icon: Icons.check_circle_rounded,
                              color: const Color(0xFF008B62),
                            ),
                            ReportSummaryCard(
                              title: 'در صف ارسال',
                              value: queuedCount.toString(),
                              subtitle: 'منتظر ارسال',
                              icon: Icons.cloud_upload_rounded,
                              color: const Color(0xFFE87500),
                            ),
                            ReportSummaryCard(
                              title: 'نیازمند بررسی',
                              value: (lowBatteryCount + unlockedCount)
                                  .toString(),
                              subtitle:
                                  '$lowBatteryCount باتری / $unlockedCount باز',
                              icon: Icons.warning_rounded,
                              color: const Color(0xFFD32F2F),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: cardDecoration(),
                          child: Column(
                            children: [
                              const SectionTitle(title: 'وضعیت همگام‌سازی'),
                              const SyncInfoRow(
                                icon: Icons.storage_rounded,
                                title: 'منبع داده گزارش',
                                value: 'SQLite',
                                color: Color(0xFF7B3FB3),
                              ),
                              SyncInfoRow(
                                icon: Icons.calendar_month_rounded,
                                title: 'تاریخ گزارش',
                                value: dateText(selectedDate),
                                color: const Color(0xFF086EBB),
                              ),
                              SyncInfoRow(
                                icon: Icons.cloud_queue_rounded,
                                title: 'موارد باقی‌مانده در صف',
                                value: '$queuedCount رکورد',
                                color: const Color(0xFFE87500),
                              ),
                              SyncInfoRow(
                                icon: Icons.sms_rounded,
                                title: 'خلاصه پیامکی',
                                value: records.isEmpty ? 'غیرفعال' : 'آماده',
                                color: const Color(0xFF008B62),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                               onPressed: records.isEmpty
                                   ? null
                                   : createSystemJson,
                                icon: const Icon(Icons.data_object_rounded),

                                label: const Text(
                                  'ساخت خروجی سامانه',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF003B7A),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  disabledForegroundColor: Colors.grey.shade600,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: records.isEmpty || isSyncing
                                    ? null
                                    : showSmsSummary,
                                icon: const Icon(Icons.sms_rounded),
                               label: const Text('نمایش / ارسال پیامک'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0EA5A3),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  disabledForegroundColor: Colors.grey.shade600,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: cardDecoration(),
                          child: Column(
                            children: [
                              const SectionTitle(
                                title: 'رکوردهای نیازمند ارسال',
                              ),
                              if (queuedCount == 0)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'موردی در صف ارسال برای این روز وجود ندارد.',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                )
                              else
                                ...records
                                    .where(
                                      (record) =>
                                          record.sendStatus ==
                                          TagSendStatus.queued,
                                    )
                                    .map(
                                      (record) => RecentTagRow(record: record),
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}



class ManagementReportPage extends StatefulWidget {
  const ManagementReportPage({super.key});

  @override
  State<ManagementReportPage> createState() => _ManagementReportPageState();
}

class _ManagementReportPageState extends State<ManagementReportPage> {
bool isLoading = true;
bool isExportingExcel = false;

DateTime selectedDate = IranTime.nowWallClock();

int slotMinutes = 60;
int maxGapMinutes = 30;

List<TagRecord> records = [];
List<AreaZone> zones = [];
List<PolygonZone> reportPolygons = [];
List<CamelProfile> profiles = [];
List<AppAlert> alerts = [];

AppSettings appSettings = const AppSettings();

ManagementReport? report;
int _reportLoadId = 0;
Timer? _reportRefreshDebounce;

void _onRecordChange() {
  if (!isToday || !mounted) return;
  _reportRefreshDebounce?.cancel();
  _reportRefreshDebounce = Timer(const Duration(seconds: 6), () {
    if (mounted && !isLoading) rebuildReport();
  });
}

  @override
  void initState() {
    super.initState();
    TagRecordsEvents.revision.addListener(_onRecordChange);
    loadReportData();
  }

  @override
  void dispose() {
    _reportRefreshDebounce?.cancel();
    TagRecordsEvents.revision.removeListener(_onRecordChange);
    super.dispose();
  }

 Future<void> loadReportData() async {
   final requestId = ++_reportLoadId;
   final day = selectedDate;
   final loadedRecords = await LocalStorageService.loadRecordsForDay(
     day, limit: 100000);
   final loadedZones = await AreaZoneService.loadZones();
   final loadedPolygons = await PolygonZoneService.loadActiveZones();
   final loadedProfiles = await CamelProfileService.loadProfiles();
   final loadedAlerts = await AlertService.loadAlerts();
   final loadedSettings = await AppSettingsService.loadSettings();

   final builtReport = ManagementReportService.buildDailyReport(
     records: loadedRecords,
     zones: loadedZones,
     polygons: loadedPolygons,
     profiles: loadedProfiles,
     date: day,
     slotMinutes: slotMinutes,
     maxGapMinutes: maxGapMinutes,
   );

   if (!mounted || requestId != _reportLoadId) return;

   setState(() {
     records = loadedRecords;
     zones = loadedZones;
     reportPolygons = loadedPolygons;
     profiles = loadedProfiles;
     alerts = loadedAlerts;
     appSettings = loadedSettings;
     report = builtReport;
     isLoading = false;
   });
 }

  Future<void> rebuildReport() async {
    setState(() {
      isLoading = true;
    });

    await loadReportData();
  }

  String twoDigit(int value) {
    return value.toString().padLeft(2, '0');
  }

  String dateText(DateTime date) {
    return JalaliDateUi.format(date);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool get isToday {
    return isSameDay(selectedDate, IranTime.nowWallClock());
  }

  void changeDay(int offset) {
    final next = selectedDate.add(Duration(days: offset));
    if (RecordDayService.key(next).compareTo(RecordDayService.oldestKey) < 0 ||
        RecordDayService.key(next).compareTo(RecordDayService.todayKey) > 0) return;
    setState(() => selectedDate = next);
    rebuildReport();
  }

  void goToToday() {
    setState(() {
      selectedDate = IranTime.nowWallClock();
    });

    rebuildReport();
  }

  Future<void> pickDate() async {
    final pickedDate = await JalaliDateUi.pick(
      context,
      initialDate: selectedDate,
      firstDate: RecordDayService.oldestDay,
      lastDate: RecordDayService.today,
    );

    if (pickedDate == null) return;

    setState(() {
      selectedDate = pickedDate;
    });

    rebuildReport();
  }

  Color statusColor(bool hasProblem) {
    return hasProblem ? const Color(0xFFD32F2F) : const Color(0xFF008B62);
  }



  void openManagerPreview() {
    final currentReport = report;

    if (currentReport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('گزارشی برای پیش‌نمایش وجود ندارد.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManagementReportPreviewPage(
          report: currentReport,
          appSettings: appSettings,
          date: selectedDate,
          profiles: profiles,
          zones: zones,
        ),
      ),
    );
  }




  Future<void> exportExcelReport() async {
    final currentReport = report;

    if (currentReport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('گزارشی برای خروجی گرفتن وجود ندارد.'),
        ),
      );
      return;
    }

    try {
      setState(() {
        isExportingExcel = true;
      });

      final file = await ManagementExcelExportService.createAndShareExcel(
        report: currentReport,
        records: records,
        zones: zones,
        profiles: profiles,
        alerts: alerts,
        appSettings: appSettings,
        date: selectedDate,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فایل Excel ساخته شد: ${file.path.split('/').last}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در ساخت Excel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isExportingExcel = false;
        });
      }
    }
  }


  void showAnalysisSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFAF6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            buildReportSettings(),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('بستن')),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentReport = report;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF9F4),
        appBar: AppBar(
          title: const Text('گزارش'),
          centerTitle: true,
          backgroundColor: const Color(0xFF9F512E),
          foregroundColor: Colors.white,
          actions: [IconButton(
            onPressed: rebuildReport,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'به‌روزرسانی گزارش',
          )],
        ),
        body: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: currentReport == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(children: [
              ManagementReportDashboard(
                report: currentReport,
                records: records,
                zones: zones,
                polygons: reportPolygons,
                date: selectedDate,
                dateLabel: dateText(selectedDate),
                maxGapMinutes: maxGapMinutes,
                previousDay: () => changeDay(-1),
                nextDay: () => changeDay(1),
                selectDate: pickDate,
                selectToday: goToToday,
                isToday: isToday,
                openSettings: showAnalysisSettings,
                openPreview: openManagerPreview,
                exportExcel: exportExcelReport,
                exporting: isExportingExcel,
              ),
              if (isLoading) const Positioned.fill(child: ColoredBox(
                color: Color(0x77FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              )),
            ]),
        )),
      ),
    );
  }

 Widget buildExcelExportButton() {
   return Container(
     padding: const EdgeInsets.all(14),
     decoration: cardDecoration(),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         const Text(
           'خروجی مدیریتی',
           style: TextStyle(
             fontWeight: FontWeight.bold,
             color: Color(0xFF062C5E),
             fontSize: 16,
           ),
         ),
         const SizedBox(height: 8),
         const Text(
           'قبل از ساخت Excel، گزارش مدیر را داخل اپ ببین. سپس فایل Excel چندبرگه‌ای را بساز و ارسال کن.',
           style: TextStyle(
             color: Colors.black54,
             fontSize: 12,
             height: 1.7,
           ),
         ),
         const SizedBox(height: 12),

         SizedBox(
           width: double.infinity,
           height: 50,
           child: OutlinedButton.icon(
             onPressed: openManagerPreview,
             icon: const Icon(Icons.preview_rounded),
             label: const Text('پیش‌نمایش گزارش'),
             style: OutlinedButton.styleFrom(
               foregroundColor: const Color(0xFF003B7A),
               side: const BorderSide(
                 color: Color(0xFF003B7A),
               ),
               shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(14),
               ),
             ),
           ),
         ),

         const SizedBox(height: 10),

         SizedBox(
           width: double.infinity,
           height: 50,
           child: ElevatedButton.icon(
             onPressed: isExportingExcel ? null : exportExcelReport,
             icon: isExportingExcel
                 ? const SizedBox(
                     width: 18,
                     height: 18,
                     child: CircularProgressIndicator(
                       strokeWidth: 2,
                       color: Colors.white,
                     ),
                   )
                 : const Icon(Icons.table_chart_rounded),
             label: Text(
               isExportingExcel
                   ? 'در حال ساخت Excel...'
                   : 'ساخت و اشتراک‌گذاری Excel',
             ),
             style: ElevatedButton.styleFrom(
               backgroundColor: const Color(0xFF008B62),
               foregroundColor: Colors.white,
               disabledBackgroundColor: Colors.grey.shade300,
               disabledForegroundColor: Colors.grey.shade600,
               shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(14),
               ),
             ),
           ),
         ),
       ],
     ),
   );
 }

  Widget buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  changeDay(-1);
                },
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'تاریخ گزارش',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateText(selectedDate),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF062C5E),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  changeDay(1);
                },
                icon: const Icon(Icons.chevron_left_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: pickDate,
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('انتخاب تاریخ'),
              ),
              if (!isToday)
                OutlinedButton.icon(
                  onPressed: goToToday,
                  icon: const Icon(Icons.today_rounded),
                  label: const Text('امروز'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildReportSettings() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'تنظیمات تحلیل گزارش'),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: slotMinutes,
                  decoration: const InputDecoration(
                    labelText: 'بازه زمانی',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('۳۰ دقیقه')),
                    DropdownMenuItem(value: 60, child: Text('۱ ساعت')),
                    DropdownMenuItem(value: 120, child: Text('۲ ساعت')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      slotMinutes = value;
                    });

                    rebuildReport();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: maxGapMinutes,
                  decoration: const InputDecoration(
                    labelText: 'حداکثر فاصله معتبر',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('۱۵ دقیقه')),
                    DropdownMenuItem(value: 30, child: Text('۳۰ دقیقه')),
                    DropdownMenuItem(value: 60, child: Text('۱ ساعت')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      maxGapMinutes = value;
                    });

                    rebuildReport();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'مدت حضور تقریبی فقط زمانی حساب می‌شود که فاصله بین دو دریافت کمتر از حد مجاز باشد. فاصله‌های طولانی به عنوان نامشخص حساب می‌شوند.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSummarySection(ManagementReportSummary summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ManagementSummaryCard(
                title: 'رکوردهای روز',
                value: summary.totalRecords.toString(),
                icon: Icons.storage_rounded,
                color: const Color(0xFF086EBB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ManagementSummaryCard(
                title: 'شتر دیده‌شده',
                value: summary.seenCamelCount.toString(),
                icon: Icons.pets_rounded,
                color: const Color(0xFF008B62),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ManagementSummaryCard(
                title: 'دیده‌نشده',
                value: summary.missingCamelCount.toString(),
                icon: Icons.visibility_off_rounded,
                color: const Color(0xFFE87500),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ManagementSummaryCard(
                title: 'مشکلات مهم',
                value: summary.importantProblemsCount.toString(),
                icon: Icons.warning_rounded,
                color: const Color(0xFFD32F2F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: cardDecoration(),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ManagementBadge(
                icon: Icons.battery_alert_rounded,
                text: 'باتری ضعیف: ${summary.lowBatteryCamelCount}',
                color: const Color(0xFFE87500),
              ),
              ManagementBadge(
                icon: Icons.lock_open_rounded,
                text: 'تگ باز: ${summary.unlockedEventCount}',
                color: const Color(0xFFD32F2F),
              ),
              ManagementBadge(
                icon: Icons.block_rounded,
                text: 'ممنوعه: ${summary.forbiddenEventCount}',
                color: const Color(0xFFD32F2F),
              ),
              ManagementBadge(
                icon: Icons.alt_route_rounded,
                text: 'خارج محدوده: ${summary.outsideAllowedEventCount}',
                color: const Color(0xFFE87500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildLastStatusSection(ManagementReport currentReport) {
    final rows = currentReport.lastStatusRows;

    return Container(
      decoration: cardDecoration(),
      child: Column(
        children: [
          const SectionTitle(title: 'آخرین وضعیت هر شتر'),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'داده‌ای برای نمایش وجود ندارد.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            ...rows.map(
              (row) => LastStatusReportRow(row: row),
            ),
        ],
      ),
    );
  }

 Widget buildTimeSlotSection(ManagementReport currentReport) {
   final slots = currentReport.timeSlots;
   final rows = currentReport.timeSlotRows;

   return Container(
     padding: const EdgeInsets.all(14),
     decoration: cardDecoration(),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         const ReportSectionHeader(
           icon: Icons.schedule_rounded,
           title: 'نمودار شتر × زمان',
           subtitle: 'نمایش دیداری حضور هر شتر در بازه‌های زمانی روز',
         ),
         const SizedBox(height: 10),
         const TimelineLegend(),
         const SizedBox(height: 14),
         if (rows.isEmpty)
           const EmptyManagementChart(
             icon: Icons.timeline_rounded,
             text: 'برای این تاریخ داده زمانی ثبت نشده است.',
           )
         else
           ...rows.map(
             (row) => CamelTimelineReportCard(
               row: row,
               slots: slots,
             ),
           ),
       ],
     ),
   );
 }

   Widget buildLocationDurationSection(ManagementReport currentReport) {
     final rows = currentReport.locationDurationRows;

     final sortedRows = [...rows];
     sortedRows.sort(
       (a, b) => b.totalEstimatedMinutes.compareTo(a.totalEstimatedMinutes),
     );

     return Container(
       padding: const EdgeInsets.all(14),
       decoration: cardDecoration(),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           const ReportSectionHeader(
             icon: Icons.place_rounded,
             title: 'نمودار شتر × مکان',
             subtitle: 'مدت حضور تقریبی هر شتر در محدوده‌ها و مکان‌های ثبت‌شده',
           ),
           const SizedBox(height: 14),
           if (sortedRows.isEmpty)
             const EmptyManagementChart(
               icon: Icons.bar_chart_rounded,
               text: 'برای تحلیل مکان، داده کافی وجود ندارد.',
             )
           else
             ...sortedRows.map(
               (row) => LocationDurationReportCard(row: row),
             ),
         ],
       ),
     );
   }
 }


class ManagementSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const ManagementSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 102,
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ManagementBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const ManagementBadge({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LastStatusReportRow extends StatelessWidget {
  final CamelLastStatusReport row;

  const LastStatusReportRow({
    super.key,
    required this.row,
  });

  Color get color {
    return row.hasProblem ? const Color(0xFFD32F2F) : const Color(0xFF008B62);
  }

  IconData get icon {
    if (row.statusText.contains('دیده نشده')) {
      return Icons.visibility_off_rounded;
    }

    if (row.statusText.contains('ممنوع')) {
      return Icons.block_rounded;
    }

    if (row.statusText.contains('خارج')) {
      return Icons.warning_rounded;
    }

    if (row.statusText.contains('باتری')) {
      return Icons.battery_alert_rounded;
    }

    if (row.statusText.contains('باز')) {
      return Icons.lock_open_rounded;
    }

    return Icons.check_circle_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE8EDF3))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.camelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        row.tagId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  row.statusText,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ReportSmallInfo(
                  icon: Icons.access_time_rounded,
                  text: row.lastSeenText,
                  color: const Color(0xFF086EBB),
                ),
              ),
              Expanded(
                child: ReportSmallInfo(
                  icon: Icons.place_rounded,
                  text: row.lastLocationText,
                  color: const Color(0xFF7B3FB3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ReportSmallInfo(
                  icon: Icons.battery_full_rounded,
                  text: row.batteryText,
                  color: row.batteryText.contains('-')
                      ? Colors.grey
                      : const Color(0xFF008B62),
                ),
              ),
              Expanded(
                child: ReportSmallInfo(
                  icon: Icons.lock_rounded,
                  text: row.lockText,
                  color: row.lockText.contains('باز')
                      ? const Color(0xFFD32F2F)
                      : const Color(0xFF008B62),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ReportSmallInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const ReportSmallInfo({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class ReportSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const ReportSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF062C5E),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF062C5E),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class EmptyManagementChart extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyManagementChart({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 22,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF0)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.black26,
            size: 34,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class TimelineLegend extends StatelessWidget {
  const TimelineLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: const [
        TimelineLegendItem(
          color: Color(0xFF008B62),
          text: 'محدوده عادی',
        ),
        TimelineLegendItem(
          color: Color(0xFF086EBB),
          text: 'آب',
        ),
        TimelineLegendItem(
          color: Color(0xFFE87500),
          text: 'خارج محدوده',
        ),
        TimelineLegendItem(
          color: Color(0xFFD32F2F),
          text: 'ممنوعه / خطر',
        ),
        TimelineLegendItem(
          color: Color(0xFFB8C0CC),
          text: 'بدون دریافت',
        ),
      ],
    );
  }
}

class TimelineLegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const TimelineLegendItem({
    super.key,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class CamelTimelineReportCard extends StatelessWidget {
  final CamelTimeSlotReport row;
  final List<ReportTimeSlot> slots;

  const CamelTimelineReportCard({
    super.key,
    required this.row,
    required this.slots,
  });

  int get activeSlotCount {
    var count = 0;

    for (final slot in slots) {
      final value = row.slotLocations[slot.label] ?? '-';

      if (value.trim().isNotEmpty && value != '-') {
        count++;
      }
    }

    return count;
  }

  Color colorForLocation(String value) {
    final text = value.trim();

    if (text == '-' || text.isEmpty) {
      return const Color(0xFFB8C0CC);
    }

    if (text.contains('ممنوع') || text.contains('خطر')) {
      return const Color(0xFFD32F2F);
    }

    if (text.contains('خارج')) {
      return const Color(0xFFE87500);
    }

    if (text.contains('آب')) {
      return const Color(0xFF086EBB);
    }

    if (text.contains('آغل') || text.contains('اصطبل')) {
      return const Color(0xFF7B3FB3);
    }

    return const Color(0xFF008B62);
  }

  @override
  Widget build(BuildContext context) {
    final seenPercent = slots.isEmpty ? 0.0 : activeSlotCount / slots.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFFF3E8D6),
                child: Text(
                  row.camelNo,
                  style: const TextStyle(
                    color: Color(0xFF062C5E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.camelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        row.tagId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8F2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$activeSlotCount/${slots.length} بازه',
                  style: const TextStyle(
                    color: Color(0xFF008B62),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: seenPercent.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0xFFE8EDF3),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF008B62),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: slots.map(
                (slot) {
                  final value = row.slotLocations[slot.label] ?? '-';
                  final color = colorForLocation(value);

                  return TimelineSlotChip(
                    timeLabel: slot.label,
                    locationText: value,
                    color: color,
                  );
                },
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class TimelineSlotChip extends StatelessWidget {
  final String timeLabel;
  final String locationText;
  final Color color;

  const TimelineSlotChip({
    super.key,
    required this.timeLabel,
    required this.locationText,
    required this.color,
  });

  bool get isEmpty {
    return locationText.trim().isEmpty || locationText.trim() == '-';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isEmpty ? const Color(0xFFF3F5F8) : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEmpty
              ? const Color(0xFFE3E7ED)
              : color.withValues(alpha: 0.26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isEmpty ? Colors.black38 : color,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 18,
            height: 5,
            decoration: BoxDecoration(
              color: isEmpty ? const Color(0xFFB8C0CC) : color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isEmpty ? 'بدون دریافت' : locationText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isEmpty ? Colors.black38 : const Color(0xFF1F2937),
              fontSize: 10.5,
              height: 1.3,
              fontWeight: isEmpty ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class LocationDurationReportCard extends StatelessWidget {
  final CamelLocationDurationReport row;

  const LocationDurationReportCard({
    super.key,
    required this.row,
  });

  List<MapEntry<String, int>> get sortedEntries {
    final entries = row.minutesByLocation.entries.toList();

    entries.sort((a, b) {
      return b.value.compareTo(a.value);
    });

    return entries;
  }

  Color colorForLocation(String title, bool isUnknown) {
    if (isUnknown) return Colors.grey;

    if (title.contains('ممنوع') || title.contains('خطر')) {
      return const Color(0xFFD32F2F);
    }

    if (title.contains('خارج')) {
      return const Color(0xFFE87500);
    }

    if (title.contains('آب')) {
      return const Color(0xFF086EBB);
    }

    if (title.contains('آغل') || title.contains('اصطبل')) {
      return const Color(0xFF7B3FB3);
    }

    return const Color(0xFF008B62);
  }

  @override
  Widget build(BuildContext context) {
    final total = row.totalEstimatedMinutes;
    final entries = sortedEntries;

    final allEntries = <MapEntry<String, int>>[
      ...entries,
      if (row.unknownGapMinutes > 0)
        MapEntry('زمان نامشخص', row.unknownGapMinutes),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFFF3E8D6),
                child: Text(
                  row.camelNo,
                  style: const TextStyle(
                    color: Color(0xFF062C5E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  row.camelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  ManagementReportService.minutesText(total),
                  style: const TextStyle(
                    color: Color(0xFF062C5E),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          if (allEntries.isEmpty || total <= 0)
            const EmptyManagementChart(
              icon: Icons.more_time_rounded,
              text: 'برای محاسبه مدت حضور، حداقل دو رکورد زمانی لازم است.',
            )
          else ...[
            LocationStackedBar(
              entries: allEntries,
              totalMinutes: total,
            ),
            const SizedBox(height: 12),
            ...allEntries.map(
              (entry) {
                final isUnknown = entry.key == 'زمان نامشخص';
                final color = colorForLocation(entry.key, isUnknown);

                return LocationDurationBar(
                  title: entry.key,
                  minutes: entry.value,
                  totalMinutes: total,
                  color: color,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class LocationStackedBar extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final int totalMinutes;

  const LocationStackedBar({
    super.key,
    required this.entries,
    required this.totalMinutes,
  });

  Color colorForLocation(String title) {
    if (title == 'زمان نامشخص') return Colors.grey;

    if (title.contains('ممنوع') || title.contains('خطر')) {
      return const Color(0xFFD32F2F);
    }

    if (title.contains('خارج')) {
      return const Color(0xFFE87500);
    }

    if (title.contains('آب')) {
      return const Color(0xFF086EBB);
    }

    if (title.contains('آغل') || title.contains('اصطبل')) {
      return const Color(0xFF7B3FB3);
    }

    return const Color(0xFF008B62);
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty || totalMinutes <= 0) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 18,
        child: Row(
          children: entries.map(
            (entry) {
              final flex = entry.value.clamp(1, 100000).toInt();

              return Expanded(
                flex: flex,
                child: Container(
                  color: colorForLocation(entry.key),
                ),
              );
            },
          ).toList(),
        ),
      ),
    );
  }
}

class LocationDurationBar extends StatelessWidget {
  final String title;
  final int minutes;
  final int totalMinutes;
  final Color color;

  const LocationDurationBar({
    super.key,
    required this.title,
    required this.minutes,
    required this.totalMinutes,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent = totalMinutes <= 0 ? 0.0 : minutes / totalMinutes;
    final percentText = '${(percent * 100).round()}٪';

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${ManagementReportService.minutesText(minutes)} · $percentText',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 9,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * percent.clamp(0.0, 1.0),
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}



class MorePage extends StatelessWidget {
  const MorePage({super.key});

  static const _brown = Color(0xFFA4542D);
  static const _green = Color(0xFF21463C);

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _tile(BuildContext context, String label, String subtitle,
      IconData icon, Color color, Widget page) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFF0E5DF)),
        boxShadow: [BoxShadow(color: const Color(0xFF7A3D1E).withValues(alpha: .05),
          blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(radius: 25, backgroundColor: color.withValues(alpha: .12),
          child: Icon(icon, color: color)),
        title: Text(label, style: const TextStyle(fontSize: 16,
          fontWeight: FontWeight.w700, color: Color(0xFF2F342F))),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF8C7E76))),
        trailing: const Icon(Icons.chevron_left_rounded, color: Color(0xFF987A6B)),
        onTap: () => _open(context, page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF9F5),
        body: Column(children: [
          const AppHeader(title: 'بیشتر'),
          Expanded(child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 22, 16, 110),
              children: [
                const Text('مدیریت و تنظیمات', style: TextStyle(fontSize: 21,
                  color: _green, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('همه ابزارهای ضروری در یک جا',
                  style: TextStyle(color: Color(0xFF897A72), fontSize: 12)),
                const SizedBox(height: 22),
                _tile(context, 'تنظیمات', 'ساربان، گله، Wi-Fi و پیامک',
                    Icons.tune_rounded, _brown, const UnifiedSettingsPage()),
                _tile(context, 'مدیریت شترها', 'افزودن، ویرایش و حذف شتر',
                    Icons.pets_rounded, const Color(0xFF17795C),
                    const CamelManagementPage()),
                _tile(context, 'سوابق دریافت', 'جستجوی رکوردهای ذخیره‌شده',
                    Icons.history_rounded, const Color(0xFF5380A8),
                    const RecordsHistoryPage()),
                _tile(context, 'گزارش', 'گزارش زمان و مکان شترها',
                    Icons.analytics_rounded, const Color(0xFF9E785A),
                    const ManagementReportPage()),
                _tile(context, 'لاگ آنتن', 'وضعیت اتصال و خطاهای دریافت',
                    Icons.wifi_rounded, const Color(0xFF68849C),
                    const AntennaLogsPage()),
                _tile(context, 'درباره سامانه', 'معرفی سامانه مدیریت گله',
                    Icons.info_outline_rounded, const Color(0xFF8B8577),
                    const AboutSarabanPage()),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(color: const Color(0xFFF0E5DF)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Color(0xFFAB4B3A)),
                    title: const Text('خروج از حساب'),
                    subtitle: Text(AppAuthController.instance.isDemo
                        ? 'حالت آزمایشی'
                        : (AppAuthController.instance.user?.name ?? 'حساب کاربری')),
                    onTap: () async {
                      final accepted = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('خروج از حساب'),
                          content: const Text('از حساب کاربری خارج می‌شوید؟'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                              child: const Text('انصراف')),
                            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
                              child: const Text('خروج')),
                          ],
                        ),
                      );
                      if (accepted == true) {
                        await SmsAutoSenderService.pause();
                        if (AntennaSessionController.instance.isInitialized) {
                          try {
                            await AntennaSessionController.instance.disconnect();
                          } catch (_) {
                            // A failed network disconnect must not block sign-out.
                          }
                        }
                        await AppAuthController.instance.signOut();
                      }
                    },
                  ),
                ),
              ],
            ),
          ))),
        ]),
      ),
    );
  }
}

class AboutSarabanPage extends StatelessWidget {
  const AboutSarabanPage({super.key});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xFFFFF9F5),
      appBar: AppBar(title: const Text('درباره سامانه'),
        centerTitle: true, backgroundColor: const Color(0xFF21463C),
        foregroundColor: Colors.white),
      body: Center(child: Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.pets_rounded, color: Color(0xFFA4542D), size: 56),
          const SizedBox(height: 12),
          const Text('سامانه مدیریت هوشمند گله',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('دریافت رکوردهای تگ از آنتن Wi-Fi، مدیریت شترها، نمایش موقعیت و تهیه گزارش‌های روزانه.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, height: 1.8)),
        ])),
      ),
    ),
  );
}

class CamelManagementPage extends StatefulWidget {
  const CamelManagementPage({super.key});

  @override
  State<CamelManagementPage> createState() => _CamelManagementPageState();
}

class _CamelManagementPageState extends State<CamelManagementPage> {
  bool isLoading = true;
  List<CamelProfile> profiles = [];
  String camelSearch = '';

  @override
  void initState() {
    super.initState();
    loadProfiles();
  }

  Future<void> loadProfiles() async {
    final loadedProfiles = await CamelProfileService.loadProfiles();

    if (!mounted) return;

    setState(() {
      profiles = loadedProfiles;
      isLoading = false;
    });
  }

  String normalizeTagId(String value) {
    var text = value.trim().replaceAll(' ', '');

    if (text.isEmpty) {
      return '';
    }

    if (!text.toUpperCase().startsWith('T-')) {
      text = 'T-$text';
    }

    return text.toUpperCase();
  }

  String nextCamelNo() {
    return (profiles.length + 1).toString();
  }

  Future<void> openCamelDialog({CamelProfile? profile}) async {
    final isEdit = profile != null;

    final tagController = TextEditingController(
      text: profile?.tagId ?? '',
    );

    final camelNoController = TextEditingController(
      text: profile?.camelNo ?? nextCamelNo(),
    );

    final camelNameController = TextEditingController(
      text: profile?.camelName ?? '',
    );

    final noteController = TextEditingController(
      text: profile?.note ?? '',
    );

    final result = await showDialog<CamelProfile>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(isEdit ? 'ویرایش شتر' : 'ثبت شتر جدید'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: TextField(
                      controller: tagController,
                      readOnly: isEdit,
                      textAlign: TextAlign.left,
                      decoration: const InputDecoration(
                        labelText: 'شناسه تگ',
                        hintText: 'مثلاً T-926877721',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: camelNoController,
                    decoration: const InputDecoration(
                      labelText: 'شماره شتر',
                      hintText: 'مثلاً ۱',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: camelNameController,
                    decoration: const InputDecoration(
                      labelText: 'نام شتر',
                      hintText: 'مثلاً شتر قهوه‌ای',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'توضیح',
                      hintText: 'اختیاری',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('انصراف'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final tagId = normalizeTagId(tagController.text);

                  if (tagId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('شناسه تگ را وارد کن.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final camelNo = camelNoController.text.trim().isEmpty
                      ? nextCamelNo()
                      : camelNoController.text.trim();

                  final camelName = camelNameController.text.trim().isEmpty
                      ? 'شتر شماره $camelNo'
                      : camelNameController.text.trim();

                  Navigator.of(dialogContext).pop(
                    CamelProfile(
                      tagId: tagId,
                      camelNo: camelNo,
                      camelName: camelName,
                      isActive: profile?.isActive ?? true,
                      note: noteController.text.trim(),
                    ),
                  );
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('ذخیره'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) {
      return;
    }

    await CamelProfileService.updateProfile(result);

    await LocalStorageService.updateCamelInfoForTag(
      tagId: result.tagId,
      camelNo: result.camelNo,
      camelName: result.camelName,
    );

    await loadProfiles();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('«${result.camelName}» ذخیره شد.'),
      ),
    );
  }

  Future<void> deleteCamel(CamelProfile profile) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف شتر'),
        content: Text('«${profile.camelName}» با تگ ${profile.tagId} از فهرست شترها حذف شود؟\n\nسوابق رکوردهای دریافتی برای گزارش‌گیری حفظ می‌شوند. این تگ دوباره خودکار ثبت نخواهد شد و برای افزودن دوباره باید دستی ثبت شود.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFBD4937)),
            child: const Text('حذف شتر')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await CamelProfileService.deleteProfile(profile.tagId);
      await loadProfiles();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${profile.camelName}» از فهرست حذف شد.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حذف شتر انجام نشد. دوباره تلاش کنید.')),
      );
    }
  }

  Future<void> toggleActive(CamelProfile profile, bool value) async {
    final updatedProfile = profile.copyWith(isActive: value);

    await CamelProfileService.updateProfile(updatedProfile);
    await loadProfiles();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF9F5),
        appBar: AppBar(
          title: const Text('مدیریت شترها'),
          centerTitle: true,
          backgroundColor: const Color(0xFF21463C),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: loadProfiles,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'بارگذاری مجدد',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            openCamelDialog();
          },
          backgroundColor: const Color(0xFFA4542D),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('ثبت شتر'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : profiles.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: cardDecoration(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.pets_rounded,
                                size: 54,
                                color: Color(0xFF008B62),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'هنوز شتری ثبت نشده است.',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'برای شروع، از دکمه «ثبت شتر» استفاده کن.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black54,
                                  height: 1.7,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                onPressed: () {
                                  openCamelDialog();
                                },
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('ثبت شتر جدید'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: loadProfiles,
                        child: Builder(builder: (context) {
                          final q = camelSearch.trim().toLowerCase();
                          final visible = q.isEmpty ? profiles : profiles.where((p) =>
                            p.camelName.toLowerCase().contains(q) ||
                            p.camelNo.toLowerCase().contains(q) ||
                            p.tagId.toLowerCase().contains(q)).toList();
                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                            itemCount: visible.length + 2,
                            itemBuilder: (context, index) {
                              if (index == 0) return Column(children: [
                                Container(width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(color: const Color(0xFFE8F4ED),
                                    borderRadius: BorderRadius.circular(16)),
                                  child: Text('شترهای ثبت‌شده: ${profiles.length}',
                                    style: const TextStyle(color: Color(0xFF21463C),
                                      fontWeight: FontWeight.bold))),
                                TextField(
                                  onChanged: (v) => setState(() => camelSearch = v),
                                  decoration: InputDecoration(
                                    hintText: 'جستجو با نام، شماره یا تگ',
                                    prefixIcon: const Icon(Icons.search_rounded),
                                    filled: true, fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none)),
                                ),
                                const SizedBox(height: 14),
                              ]);
                              if (index == visible.length + 1) {
                                return visible.isEmpty
                                  ? const Padding(padding: EdgeInsets.all(26),
                                      child: Center(child: Text('شتری با این مشخصات پیدا نشد.')))
                                  : const SizedBox(height: 12);
                              }
                              final profile = visible[index - 1];
                              return CamelProfileCard(
                                key: ValueKey(profile.tagId),
                                profile: profile,
                                onEdit: () => openCamelDialog(profile: profile),
                                onActiveChanged: (value) => toggleActive(profile, value),
                                onDelete: () => deleteCamel(profile),
                              );
                            },
                          );
                        }),
                      ),
          ),
        ),
      ),
    );
  }
}


class CamelProfileCard extends StatelessWidget {
  final CamelProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onActiveChanged;

  const CamelProfileCard({
    super.key,
    required this.profile,
    required this.onEdit,
    required this.onDelete,
    required this.onActiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFF3E8D6),
                child: Text(
                  profile.camelNo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF062C5E),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.camelName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        profile.tagId,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: profile.isActive,
                onChanged: onActiveChanged,
              ),
            ],
          ),
          if (profile.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                profile.note,
                style: const TextStyle(
                  color: Colors.black54,
                  height: 1.6,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('ویرایش'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('حذف'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB34739),
                  side: const BorderSide(color: Color(0xFFE9B9AF)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: profile.isActive
                      ? const Color(0xFFEAF8F2)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  profile.isActive ? 'فعال' : 'غیرفعال',
                  style: TextStyle(
                    color: profile.isActive
                        ? const Color(0xFF16795C)
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


enum RecordStatusFilter {
  all,
  lowBattery,
  queued,
  unlocked,
}

enum RecordDateFilter {
  all,
  today,
  yesterday,
  selected,
}

class RecordsHistoryPage extends StatefulWidget {
  const RecordsHistoryPage({super.key});

  @override
  State<RecordsHistoryPage> createState() => _RecordsHistoryPageState();
}

class _RecordsHistoryPageState extends State<RecordsHistoryPage> {
  bool isLoading = true;
  List<TagRecord> records = [];
  Timer? _recordsReloadTimer;

  void _onRecordsChanged() {
    if (_recordsReloadTimer?.isActive == true) return;
    _recordsReloadTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) unawaited(loadRecords());
    });
  }

  @override
  void dispose() {
    TagRecordsEvents.revision.removeListener(_onRecordsChanged);
    _recordsReloadTimer?.cancel();
    super.dispose();
  }

  String searchText = '';
  RecordStatusFilter selectedStatusFilter = RecordStatusFilter.all;
  RecordDateFilter selectedDateFilter = RecordDateFilter.all;
  DateTime selectedDate = IranTime.nowWallClock();

  @override
  void initState() {
    super.initState();
    TagRecordsEvents.revision.addListener(_onRecordsChanged);
    loadRecords();
  }

  Future<void> loadRecords() async {
    final loadedRecords = await LocalStorageService.loadTagRecords();

    if (!mounted) return;

    setState(() {
      records = loadedRecords;
      isLoading = false;
    });
  }

  DateTime? recordDate(TagRecord record) {
    if (record.receivedDateTime.trim().isEmpty) {
      return null;
    }

    return IranTime.parseForDisplay(record.receivedDateTime);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String twoDigit(int value) {
    return value.toString().padLeft(2, '0');
  }

  String dateText(DateTime date) {
    return JalaliDateUi.format(date);
  }

  bool matchesDateFilter(TagRecord record) {
    final date = recordDate(record);

    if (selectedDateFilter == RecordDateFilter.all) {
      return true;
    }

    if (date == null) {
      return selectedDateFilter == RecordDateFilter.all;
    }

    final now = IranTime.nowWallClock();
    final yesterday = now.subtract(const Duration(days: 1));

    switch (selectedDateFilter) {
      case RecordDateFilter.all:
        return true;
      case RecordDateFilter.today:
        return isSameDay(date, now);
      case RecordDateFilter.yesterday:
        return isSameDay(date, yesterday);
      case RecordDateFilter.selected:
        return isSameDay(date, selectedDate);
    }
  }

  bool matchesStatusFilter(TagRecord record) {
    switch (selectedStatusFilter) {
      case RecordStatusFilter.all:
        return true;
      case RecordStatusFilter.lowBattery:
        return record.isBatteryLow;
      case RecordStatusFilter.queued:
        return record.sendStatus == TagSendStatus.queued;
      case RecordStatusFilter.unlocked:
        return record.lock == 0;
    }
  }

  List<TagRecord> get filteredRecords {
    var result = records.where(matchesDateFilter).where(matchesStatusFilter);

    final query = searchText.trim().toLowerCase();

    if (query.isEmpty) {
      return result.toList();
    }

    return result.where((record) {
      return record.tagId.toLowerCase().contains(query) ||
          record.camelName.toLowerCase().contains(query) ||
          record.camelNo.toLowerCase().contains(query) ||
          record.locationName.toLowerCase().contains(query);
    }).toList();
  }

  String statusFilterTitle(RecordStatusFilter filter) {
    switch (filter) {
      case RecordStatusFilter.all:
        return 'همه';
      case RecordStatusFilter.lowBattery:
        return 'باتری ضعیف';
      case RecordStatusFilter.queued:
        return 'در صف ارسال';
      case RecordStatusFilter.unlocked:
        return 'تگ باز شده';
    }
  }

  String dateFilterTitle(RecordDateFilter filter) {
    switch (filter) {
      case RecordDateFilter.all:
        return 'همه تاریخ‌ها';
      case RecordDateFilter.today:
        return 'امروز';
      case RecordDateFilter.yesterday:
        return 'دیروز';
      case RecordDateFilter.selected:
        return dateText(selectedDate);
    }
  }

  Future<void> pickDate() async {
    final pickedDate = await JalaliDateUi.pick(
      context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null) return;

    setState(() {
      selectedDate = pickedDate;
      selectedDateFilter = RecordDateFilter.selected;
    });
  }

  Future<void> clearAllRecords() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('پاک‌سازی سوابق'),
            content: const Text(
              'آیا مطمئنی همه رکوردهای دریافت‌شده پاک شوند؟ اطلاعات شترها پاک نمی‌شود.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('انصراف'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.delete_rounded),
                label: const Text('پاک کن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirm != true) return;

    await LocalStorageService.clearTagRecords();

    if (!mounted) return;

    setState(() {
      records = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('همه سوابق دریافت پاک شدند.'),
      ),
    );
  }


  Future<void> deleteSingleRecord(TagRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف رکورد'),
            content: Text(
              'آیا مطمئنی رکورد ${record.camelName} با شناسه ${record.tagId} حذف شود؟',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('انصراف'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.delete_rounded),
                label: const Text('حذف'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirm != true) return;

    final updatedRecords = records.where((item) {
      return !identical(item, record);
    }).toList();

    final id = record.dbId;
    if (id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('شناسه دیتابیس رکورد پیدا نشد؛ حذف انجام نشد.'),
      ));
      return;
    }
    final deleted = await LocalStorageService.deleteTagRecordById(id);
    if (!deleted || !mounted) return;

    setState(() {
      records = updatedRecords;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('رکورد حذف شد.'),
      ),
    );
  }


  String csvCell(Object? value) {
    final text = (value ?? '').toString();
    final escaped = text.replaceAll('"', '""');

    return '"$escaped"';
  }

  String buildCsvText(List<TagRecord> sourceRecords) {
    final rows = <String>[];

    rows.add([
      'tagId',
      'camelNo',
      'camelName',
      'batteryPercent',
      'lock',
      'counterLock',
      'receivedTime',
      'receivedDateTime',
      'locationName',
      'latitude',
      'longitude',
      'accuracy',
      'sendStatus',
    ].map(csvCell).join(','));

    for (final record in sourceRecords) {
      rows.add([
        record.tagId,
        record.camelNo,
        record.camelName,
        record.batteryPercent,
        record.lock ?? '',
        record.counterLock ?? '',
        record.receivedTime,
        record.receivedDateTime,
        record.locationName,
        record.latitude ?? '',
        record.longitude ?? '',
        record.accuracy ?? '',
        record.sendStatus.name,
      ].map(csvCell).join(','));
    }

    return rows.join('\n');
  }

  Future<void> copyCsvToClipboard(String csvText) async {
    await Clipboard.setData(
      ClipboardData(text: csvText),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('خروجی CSV کپی شد.'),
      ),
    );
  }

  void showCsvDialog() {
    final sourceRecords = filteredRecords;

    if (sourceRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رکوردی برای خروجی گرفتن وجود ندارد.'),
        ),
      );
      return;
    }

    final csvText = buildCsvText(sourceRecords);

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('خروجی CSV سوابق'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${sourceRecords.length} رکورد آماده خروجی است.',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062C5E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(
                      maxHeight: 320,
                    ),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE0E6EF),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: SelectableText(
                          csvText,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('بستن'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await copyCsvToClipboard(csvText);

                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('کپی خروجی'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003B7A),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }


String safeDateForFileName(DateTime date) {
  final year = date.year.toString();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  final second = date.second.toString().padLeft(2, '0');

  return '${year}_${month}_${day}_${hour}_${minute}_$second';
}

Future<void> saveAndShareCsvFile() async {
  final sourceRecords = filteredRecords;

  if (sourceRecords.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('رکوردی برای ساخت فایل CSV وجود ندارد.'),
      ),
    );
    return;
  }

  try {
    final csvText = buildCsvText(sourceRecords);
    final directory = await getApplicationDocumentsDirectory();

    final fileName = 'saraban_records_${safeDateForFileName(DateTime.now())}.csv';
    final file = File('${directory.path}/$fileName');

    final bytes = <int>[
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(csvText),
    ];

    await file.writeAsBytes(bytes, flush: true);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('فایل CSV ساخته شد: $fileName'),
      ),
    );

   await Share.shareXFiles(
       [XFile(file.path)],
       text: 'خروجی CSV سوابق دریافت ساربان',
     );
   } catch (e) {
     if (!mounted) return;

     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('خطا در ساخت فایل CSV: $e'),
       ),
     );
   }
}


  @override
  Widget build(BuildContext context) {
    final lowBatteryCount = records.where((record) => record.isBatteryLow).length;

    final queuedCount = records
        .where((record) => record.sendStatus == TagSendStatus.queued)
        .length;

    final unlockedCount = records.where((record) => record.lock == 0).length;

    final visibleRecords = filteredRecords;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('سوابق دریافت'),
          centerTitle: true,
          backgroundColor: const Color(0xFF062C5E),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: loadRecords,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'بارگذاری مجدد',
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: loadRecords,
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: HistorySummaryCard(
                                title: 'کل رکوردها',
                                value: records.length.toString(),
                                icon: Icons.storage_rounded,
                                color: const Color(0xFF086EBB),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: HistorySummaryCard(
                                title: 'باتری ضعیف',
                                value: lowBatteryCount.toString(),
                                icon: Icons.battery_alert_rounded,
                                color: const Color(0xFFE87500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: HistorySummaryCard(
                                title: 'در صف ارسال',
                                value: queuedCount.toString(),
                                icon: Icons.cloud_upload_rounded,
                                color: const Color(0xFF008B62),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: HistorySummaryCard(
                                title: 'تگ باز شده',
                                value: unlockedCount.toString(),
                                icon: Icons.lock_open_rounded,
                                color: const Color(0xFFD32F2F),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          onChanged: (value) {
                            setState(() {
                              searchText = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'جستجو بر اساس نام شتر، شماره تگ یا محل',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'فیلتر تاریخ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF062C5E),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...RecordDateFilter.values.map((filter) {
                                    final isSelected =
                                        selectedDateFilter == filter;

                                    return ChoiceChip(
                                      selected: isSelected,
                                      label: Text(dateFilterTitle(filter)),
                                      onSelected: (_) {
                                        setState(() {
                                          selectedDateFilter = filter;
                                        });
                                      },
                                    );
                                  }),
                                  ActionChip(
                                    avatar: const Icon(
                                      Icons.calendar_month_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('انتخاب تاریخ'),
                                    onPressed: pickDate,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'فیلتر وضعیت',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF062C5E),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: RecordStatusFilter.values.map((filter) {
                                  final isSelected =
                                      selectedStatusFilter == filter;

                                  return ChoiceChip(
                                    selected: isSelected,
                                    label: Text(statusFilterTitle(filter)),
                                    onSelected: (_) {
                                      setState(() {
                                        selectedStatusFilter = filter;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                       Container(
                         padding: const EdgeInsets.all(12),
                         decoration: cardDecoration(),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               'نمایش ${visibleRecords.length} رکورد',
                               style: const TextStyle(
                                 fontWeight: FontWeight.bold,
                                 color: Color(0xFF062C5E),
                               ),
                             ),
                             const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: visibleRecords.isEmpty ? null : showCsvDialog,
                                  icon: const Icon(Icons.table_chart_rounded),
                                  label: const Text('نمایش CSV'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF008B62),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.grey.shade300,
                                    disabledForegroundColor: Colors.grey.shade600,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: visibleRecords.isEmpty ? null : saveAndShareCsvFile,
                                  icon: const Icon(Icons.ios_share_rounded),
                                  label: const Text('فایل CSV'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF003B7A),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.grey.shade300,
                                    disabledForegroundColor: Colors.grey.shade600,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: loadRecords,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('بارگذاری'),
                                ),
                                TextButton.icon(
                                  onPressed: records.isEmpty ? null : clearAllRecords,
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  label: const Text('پاک‌سازی'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                           ],
                         ),
                       ),
                        const SizedBox(height: 8),
                        if (records.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: cardDecoration(),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.inbox_rounded,
                                  size: 54,
                                  color: Color(0xFF086EBB),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'هنوز رکوردی ذخیره نشده است.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'از صفحه گله، اتصال آنتن WiFi را برقرار کن.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black54,
                                    height: 1.7,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (visibleRecords.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: cardDecoration(),
                            child: const Text(
                              'رکوردی با این جستجو یا فیلتر پیدا نشد.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black54,
                                height: 1.7,
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: (visibleRecords.length * 110.0)
                                .clamp(220.0, 480.0).toDouble(),
                            child: ListView.builder(
                              key: const PageStorageKey('history_cards'),
                              primary: false,
                              cacheExtent: 250,
                              itemCount: visibleRecords.length,
                              itemBuilder: (context, index) {
                                final record = visibleRecords[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: RecordHistoryCard(
                                    key: ValueKey(record.dbId ?? record.messageId ?? index),
                                    record: record,
                                    onDelete: () => deleteSingleRecord(record),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}


class HistorySummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const HistorySummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class RecordHistoryCard extends StatelessWidget {
  final TagRecord record;
  final VoidCallback? onDelete;

  const RecordHistoryCard({
    super.key,
    required this.record,
    this.onDelete,
  });

  DateTime? get parsedDate {
    if (record.receivedDateTime.trim().isEmpty) {
      return null;
    }

    return IranTime.parseForDisplay(record.receivedDateTime);
  }

  bool get hasGps {
    return record.latitude != null && record.longitude != null;
  }

  String twoDigit(int value) {
    return value.toString().padLeft(2, '0');
  }

  String get dateText {
    final date = parsedDate;

    if (date == null) {
      return 'تاریخ نامشخص';
    }

    return JalaliDateUi.format(date);
  }

  String get timeText {
    final date = parsedDate;

    if (date == null) {
      return record.receivedTime;
    }

    return '${twoDigit(date.hour)}:${twoDigit(date.minute)}';
  }

  String get gpsShortText {
    if (!hasGps) {
      return 'GPS ثبت نشده';
    }

    return '${record.latitude!.toStringAsFixed(5)}, ${record.longitude!.toStringAsFixed(5)}';
  }

  Future<void> copyGps(BuildContext context) async {
    if (!hasGps) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('برای این رکورد GPS ثبت نشده است.'),
        ),
      );
      return;
    }

    final text =
        '${record.latitude!.toStringAsFixed(6)},${record.longitude!.toStringAsFixed(6)}';

    await Clipboard.setData(
      ClipboardData(text: text),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('مختصات GPS کپی شد.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLowBattery = record.isBatteryLow;
    final isUnlocked = record.lock == 0;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TagDetailPage(record: record),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFF3E8D6),
                  child: Text(
                    record.camelNo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062C5E),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.camelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          record.tagId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
               Column(
                 crossAxisAlignment: CrossAxisAlignment.end,
                 children: [
                   Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Text(
                         timeText,
                         style: const TextStyle(
                           color: Color(0xFF062C5E),
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                       const SizedBox(width: 4),
                       IconButton(
                         onPressed: onDelete,
                         icon: const Icon(
                           Icons.delete_outline_rounded,
                           color: Colors.red,
                           size: 20,
                         ),
                         tooltip: 'حذف رکورد',
                         padding: EdgeInsets.zero,
                         constraints: const BoxConstraints(
                           minWidth: 30,
                           minHeight: 30,
                         ),
                       ),
                     ],
                   ),
                   Text(
                     dateText,
                     style: const TextStyle(
                       color: Colors.black54,
                       fontSize: 11,
                     ),
                   ),
                 ],
               ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _HistoryMiniBadge(
                    icon: Icons.battery_full_rounded,
                    text: record.batteryText,
                    color: isLowBattery ? Colors.red : Colors.green,
                  ),
                ),
                Expanded(
                  child: _HistoryMiniBadge(
                    icon: isUnlocked
                        ? Icons.lock_open_rounded
                        : Icons.lock_rounded,
                    text: record.lockText,
                    color: isUnlocked ? Colors.red : const Color(0xFF008B62),
                  ),
                ),
                Expanded(
                  child: _HistoryMiniBadge(
                    icon: Icons.place_rounded,
                    text: record.locationName,
                    color: const Color(0xFF086EBB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: hasGps
                    ? const Color(0xFFEAF8F2)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    hasGps
                        ? Icons.gps_fixed_rounded
                        : Icons.gps_not_fixed_rounded,
                    size: 18,
                    color: hasGps
                        ? const Color(0xFF008B62)
                        : const Color(0xFFE87500),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        gpsShortText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasGps
                              ? const Color(0xFF008B62)
                              : const Color(0xFFE87500),
                        ),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: hasGps
                        ? () {
                            copyGps(context);
                          }
                        : null,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text(
                      'کپی',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 30),
                    ),
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

class _HistoryMiniBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _HistoryMiniBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}



/// Legacy route retained for callers outside the More tab.
class SystemSettingsPage extends StatelessWidget {
  const SystemSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => const UnifiedSettingsPage();
}

class AntennaLogsPage extends StatefulWidget {
  const AntennaLogsPage({super.key});

  @override
  State<AntennaLogsPage> createState() => _AntennaLogsPageState();
}

class _AntennaLogsPageState extends State<AntennaLogsPage> {
  bool isLoading = true;
  List<AntennaLog> logs = [];

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  Future<void> loadLogs() async {
    final loadedLogs = await AntennaLogService.loadLogs();

    if (!mounted) return;

    setState(() {
      logs = loadedLogs;
      isLoading = false;
    });
  }

  Future<void> clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('پاک‌سازی لاگ‌ها'),
            content: const Text(
              'آیا مطمئنی همه لاگ‌های آنتن WiFi پاک شوند؟ رکوردهای دریافت‌شده پاک نمی‌شوند.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('انصراف'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.delete_rounded),
                label: const Text('پاک کن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirm != true) return;

    await AntennaLogService.clearLogs();

    if (!mounted) return;

    setState(() {
      logs = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لاگ‌های آنتن WiFi پاک شدند.'),
      ),
    );
  }

  int countByType(AntennaLogType type) {
    return logs.where((log) => log.type == type).length;
  }

  @override
  Widget build(BuildContext context) {
    final receivedCount = countByType(AntennaLogType.received);
    final duplicateCount = countByType(AntennaLogType.duplicate);
    final errorCount = logs.where((log) {
      return log.type == AntennaLogType.error || log.type == AntennaLogType.invalidJson;
    }).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('لاگ دریافت آنتن WiFi'),
          centerTitle: true,
          backgroundColor: const Color(0xFF062C5E),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: loadLogs,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'بارگذاری مجدد',
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: loadLogs,
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: HistorySummaryCard(
                                title: 'کل لاگ‌ها',
                                value: logs.length.toString(),
                                icon: Icons.list_alt_rounded,
                                color: const Color(0xFF086EBB),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: HistorySummaryCard(
                                title: 'دریافت موفق',
                                value: receivedCount.toString(),
                                icon: Icons.check_circle_rounded,
                                color: const Color(0xFF008B62),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: HistorySummaryCard(
                                title: 'تکراری',
                                value: duplicateCount.toString(),
                                icon: Icons.copy_rounded,
                                color: const Color(0xFFE87500),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: HistorySummaryCard(
                                title: 'خطاها',
                                value: errorCount.toString(),
                                icon: Icons.error_rounded,
                                color: const Color(0xFFD32F2F),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'آخرین رویدادها',
                                style: const TextStyle(
                                  color: Color(0xFF062C5E),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: logs.isEmpty ? null : clearLogs,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('پاک‌سازی'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (logs.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: cardDecoration(),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.terminal_rounded,
                                  size: 54,
                                  color: Color(0xFF008B62),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'هنوز لاگی ثبت نشده است.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'از صفحه دریافت، اتصال wifi را تست کن یا JSON دستی پردازش کن.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black54,
                                    height: 1.7,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...logs.map(
                            (log) => AntennaLogCard(log: log),
                          ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}



class AntennaLogCard extends StatelessWidget {
  final AntennaLog log;

  const AntennaLogCard({
    super.key,
    required this.log,
  });

 Color get color {
   switch (log.type) {
     case AntennaLogType.connected:
       return const Color(0xFF008B62);

     case AntennaLogType.disconnected:
       return const Color(0xFFE87500);

     case AntennaLogType.received:
       return const Color(0xFF086EBB);

     case AntennaLogType.duplicate:
       return const Color(0xFF6A1B9A);

     case AntennaLogType.invalidJson:
       return const Color(0xFFD32F2F);

     case AntennaLogType.error:
       return const Color(0xFFD32F2F);

     case AntennaLogType.info:
       return const Color(0xFF607D8B);
   }
 }

  IconData get icon {
    switch (log.type) {
      case AntennaLogType.connected:
        return Icons.wifi_rounded;

      case AntennaLogType.disconnected:
        return Icons.wifi_off_rounded;

      case AntennaLogType.received:
        return Icons.download_done_rounded;

      case AntennaLogType.duplicate:
        return Icons.copy_rounded;

      case AntennaLogType.invalidJson:
        return Icons.code_off_rounded;

      case AntennaLogType.error:
        return Icons.error_rounded;

      case AntennaLogType.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(
              icon,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    log.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${log.dateText}  ${log.timeText}',
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class AppHeader extends StatefulWidget {
  final String title;

  const AppHeader({super.key, required this.title});

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  @override
  void initState() {
    super.initState();
    AppSettingsService.loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: AppSettingsService.settingsNotifier,
      builder: (context, settings, _) {
        final shepherdName = settings.shepherdName.trim().isEmpty
            ? 'ساربان'
            : settings.shepherdName.trim();

        final shepherdId = settings.shepherdId.trim().isEmpty ||
                settings.shepherdId.trim() == '-'
            ? 'شناسه ثبت نشده'
            : 'شناسه: ${settings.shepherdId.trim()}';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF031A3A), Color(0xFF062C5E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(26),
              bottomRight: Radius.circular(26),
            ),
          ),
          child: Column(
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person_rounded,
                      color: Color(0xFF062C5E),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$shepherdName\n$shepherdId',
                      style: const TextStyle(
                        color: Colors.white,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class StatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const StatusCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: cardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: const Color(0xFF003B7A),
            size: 28,
          ),
          const SizedBox(height: 7),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE8EDF3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 25,
                    height: 1,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool filled;
  final String? badge;
  final VoidCallback? onTap;

  const ActionTile({
    super.key,
    required this.title,
    required this.icon,
    this.filled = false,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: filled
            ? BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0EA5A3), Color(0xFF008B62)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              )
            : cardDecoration(),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: filled ? Colors.white : const Color(0xFF003B7A),
                    size: 30,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: filled ? Colors.white : const Color(0xFF0A1F44),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: 8,
                left: 8,
                child: CircleAvatar(
                  radius: 11,
                  backgroundColor: Colors.red,
                  child: Text(
                    badge!,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class RecentTagRow extends StatelessWidget {
  final TagRecord record;

  const RecentTagRow({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final isLowBattery = record.isBatteryLow;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TagDetailPage(record: record)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE8EDF3))),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFF3E8D6),
              child: Text(record.camelNo, style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   record.camelName,
                   style: const TextStyle(fontWeight: FontWeight.bold),
                 ),
                 const SizedBox(height: 3),
                 Text(
                   record.tagId,
                   style: const TextStyle(
                     fontSize: 12,
                     color: Colors.black54,
                   ),
                 ),
               ],
             ),
           ),
            Text(
              record.batteryText,
              style: TextStyle(
                color: isLowBattery ? Colors.red : Colors.black87,
                fontWeight: isLowBattery ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isLowBattery
                  ? Icons.battery_alert_rounded
                  : Icons.battery_full_rounded,
              size: 20,
              color: isLowBattery ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 12),
            Text(record.receivedTime),
            const SizedBox(width: 12),
            Icon(
              record.isGood
                  ? Icons.check_circle_rounded
                  : Icons.cloud_upload_rounded,
              color: record.isGood ? Colors.green : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              record.sendStatusText,
              style: TextStyle(
                fontSize: 12,
                color: record.isGood ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OperationStatusBanner extends StatelessWidget {
  final int totalRecords;
  final int queuedRecords;
  final int lowBatteryRecords;

  const OperationStatusBanner({
    super.key,
    required this.totalRecords,
    required this.queuedRecords,
    required this.lowBatteryRecords,
  });

  @override
  Widget build(BuildContext context) {
    final hasProblem = lowBatteryRecords > 0 || queuedRecords > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasProblem
            ? const Color(0xFFFFF3E0)
            : const Color(0xFFEAF8F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasProblem
              ? const Color(0xFFFFCC80)
              : const Color(0xFFB7E5D2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasProblem
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            color: hasProblem
                ? const Color(0xFFE87500)
                : const Color(0xFF007A4D),
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              totalRecords == 0
                  ? 'هنوز داده‌ای ثبت نشده است.\nبرای شروع، از صفحه دریافت یک JSON را پردازش کن.'
                  : hasProblem
                      ? 'وضعیت عملیات نیازمند بررسی است.\n$lowBatteryRecords باتری ضعیف و $queuedRecords رکورد در صف ارسال وجود دارد.'
                      : 'وضعیت عملیات عادی است.\nهمه رکوردها بدون مشکل ثبت شده‌اند.',
              style: TextStyle(
                color: hasProblem
                    ? const Color(0xFF8A4B00)
                    : const Color(0xFF0A4F35),
                fontWeight: FontWeight.bold,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MiniInfo extends StatelessWidget {
  final String title;
  final String value;

  const MiniInfo({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF008B62),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class ReportSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const ReportSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 25,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SyncInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const SyncInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE8EDF3))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

