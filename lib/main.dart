import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'services/sms_service.dart';

import 'models/area_zone.dart';
import 'services/area_zone_service.dart';

import 'services/sms_auto_sender_service.dart';
import 'models/sms_report_settings.dart';
import 'services/sms_report_settings_service.dart';
import 'services/sms_report_builder_service.dart';
import 'services/direct_sms_service.dart';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'models/camel_profile.dart';
import 'services/camel_profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/mock_data.dart';
import 'data/mock_zones.dart';
import 'data/mock_alerts.dart';
import 'models/tag_record.dart';
import 'models/zone_area.dart';
import 'models/app_alert.dart';
import 'models/antenna_payload.dart';
import 'services/local_storage_service.dart';
import 'services/usb_antenna_service.dart';
import 'services/alert_service.dart';
import 'models/app_settings.dart';
import 'services/app_setting_service.dart';
import 'models/usb_log.dart';
import 'services/usb_log_service.dart';
import 'services/location_service.dart';

import 'services/zone_check_service.dart';


import 'models/management_report.dart';
import 'services/management_report_service.dart';

import 'services/management_excel_export_service.dart';

import 'screens/live_herd_page.dart';
import 'screens/map_page.dart';
import 'services/live_herd_session_service.dart';

import 'screens/camel_info_dashboard_page.dart';
import 'services/saraban_export_service.dart';
import 'services/herd_settings_service.dart';
import 'screens/geo_area_selection_page.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        color: Colors.black.withOpacity(0.06),
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
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5A3)),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: SarabanShell(),
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

  final List<Widget> pages = const [
    HomePage(),
    ReceivePage(),
    MapPage(),
    AlertsPage(),
    MorePage(),
  ];

  @override
  void initState() {
    super.initState();

    AlertService.refreshUnreviewedCount();
    SmsAutoSenderService.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF7FAFD),
              Color(0xFFF5F7FA),
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
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: BottomNavigationBar(
              currentIndex: selectedIndex,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: Colors.grey,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11,
              ),
              onTap: (index) {
                setState(() {
                  selectedIndex = index;
                });
              },
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'خانه',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.settings_input_antenna_rounded),
                  label: 'دریافت',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.map_rounded),
                  label: 'نقشه',
                ),
                BottomNavigationBarItem(
                  icon: ValueListenableBuilder<int>(
                    valueListenable: AlertService.unreviewedCountNotifier,
                    builder: (context, count, child) {
                      if (count <= 0) {
                        return const Icon(Icons.notifications_rounded);
                      }

                      return Badge(
                        label: Text(
                          count > 99 ? '99+' : count.toString(),
                        ),
                        child: const Icon(Icons.notifications_rounded),
                      );
                    },
                  ),
                  label: 'هشدارها',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.more_horiz_rounded),
                  label: 'بیشتر',
                ),
              ],
            ),
          ),
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

  Timer? homeRefreshTimer;

  @override
  void initState() {
    super.initState();

    loadRecords();

    homeRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (!mounted) return;

        setState(() {});
      },
    );
  }

  @override
  void dispose() {
    homeRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadRecords() async {
    final loadedRecords = await LocalStorageService.loadTagRecords();

    if (!mounted) return;

    setState(() {
      records = loadedRecords;
      isLoading = false;
    });
  }

  DateTime? recordDateTime(TagRecord record) {
    final text = record.receivedDateTime.trim();

    if (text.isEmpty) return null;

    return DateTime.tryParse(text);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<TagRecord> getTodayRecords(List<TagRecord> source) {
    final now = DateTime.now();

    return source.where((record) {
      final parsed = recordDateTime(record);

      if (parsed == null) return false;

      return isSameDay(parsed, now);
    }).toList();
  }

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
    final queuedCount = getTodayQueuedCount(records);
    final lastReceiveText = getTodayLastReceiveText(records);

    return RefreshIndicator(
      onRefresh: loadRecords,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const AppHeader(title: 'نرم‌افزار ساربان'),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: const [
                      Expanded(
                        child: StatusCard(
                          title: 'دستگاه USB',
                          subtitle: 'آماده دریافت',
                          icon: Icons.usb_rounded,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: StatusCard(
                          title: 'ذخیره محلی',
                          subtitle: 'SQLite فعال',
                          icon: Icons.storage_rounded,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: StatusCard(
                          title: 'موقعیت GPS',
                          subtitle: 'قابل ثبت',
                          icon: Icons.location_on_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDecoration(),
                    child: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          )
                        : GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.55,
                            children: [
                              MetricCard(
                                title: 'تگ‌های دیده‌شده',
                                value: totalTags.toString(),
                                subtitle: 'امروز',
                                icon: Icons.pets_rounded,
                                color: const Color(0xFF16965C),
                              ),
                              MetricCard(
                                title: 'باتری ضعیف',
                                value: lowBatteryCount.toString(),
                                subtitle: 'امروز',
                                icon: Icons.battery_alert_rounded,
                                color: const Color(0xFFE87500),
                              ),
                              MetricCard(
                                title: 'ارسال‌نشده',
                                value: queuedCount.toString(),
                                subtitle: 'امروز',
                                icon: Icons.cloud_upload_rounded,
                                color: const Color(0xFF086EBB),
                              ),
                              MetricCard(
                                title: 'آخرین دریافت',
                                value: lastReceiveText,
                                subtitle: todayRecords.isEmpty
                                    ? 'امروز داده‌ای نیست'
                                    : 'امروز',
                                icon: Icons.sync_rounded,
                                color: const Color(0xFF7B3FB3),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 14),

                  const SizedBox(height: 14),

                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CamelInfoDashboardPage(),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: cardDecoration(),
                      child: Row(
                        children: const [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Color(0xFFEAF2FF),
                            child: Icon(
                              Icons.badge_rounded,
                              color: Color(0xFF086EBB),
                              size: 28,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'داشبورد اطلاعات شترها',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'ثبت، ویرایش، جدول و توضیحات شترها',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_left_rounded),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const GeoAreaSelectionPage(),
                        ),
                      );

                    },

                    child: Container(

                      width: double.infinity,

                      padding: const EdgeInsets.all(16),

                      decoration: cardDecoration(),

                      child: const Row(

                        children: [

                          CircleAvatar(

                            backgroundColor:
                                Color(0xFFEAF8F2),

                            child: Icon(
                              Icons.location_city_rounded,
                              color: Color(0xFF008B62),
                            ),

                          ),

                          SizedBox(width: 12),

                          Expanded(

                            child: Column(

                              crossAxisAlignment:
                                  CrossAxisAlignment.start,

                              children: [

                                Text(
                                  'انتخاب محدوده فعالیت',
                                  style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                SizedBox(height: 5),

                                Text(
                                  'انتخاب استان، شهر و منطقه نقشه',
                                  style: TextStyle(
                                    color:
                                        Colors.black54,
                                  ),
                                ),

                              ],

                            ),

                          ),

                          Icon(
                            Icons.chevron_left_rounded,
                          ),

                        ],

                      ),

                    ),

                  ),

                  const SizedBox(height: 14),

                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.88,
                    children: [
                     ActionTile(
                       title: 'گله زنده',
                       icon: Icons.pets_rounded,
                       filled: true,
                       onTap: () {
                         Navigator.of(context).push(
                           MaterialPageRoute(
                             builder: (_) => const LiveHerdPage(),
                           ),
                         );
                       },
                     ),
                      ActionTile(
                        title: 'نقشه گله',
                        icon: Icons.map_rounded,
                        onTap: () {
                          goToTab(2);
                        },
                      ),
                      ActionTile(
                        title: 'هشدارها',
                        icon: Icons.notifications_rounded,
                        badge: lowBatteryCount > 0
                            ? lowBatteryCount.toString()
                            : null,
                        onTap: () {
                          goToTab(3);
                        },
                      ),
                      ActionTile(
                        title: 'گزارش روزانه',
                        icon: Icons.assignment_rounded,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ReportPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Container(
                    decoration: cardDecoration(),
                    child: Column(
                      children: [
                        const SectionTitle(title: 'تگ‌های دریافت‌شده امروز'),
                        if (todayRecords.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'امروز هنوز رکوردی ثبت نشده است. از صفحه دریافت، JSON را پردازش کن.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black54,
                                height: 1.7,
                              ),
                            ),
                          )
                        else
                          ...todayRecords
                              .take(4)
                              .map((record) => RecentTagRow(record: record)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  OperationStatusBanner(
                    totalRecords: totalTags,
                    queuedRecords: queuedCount,
                    lowBatteryRecords: lowBatteryCount,
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}




class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage>
    with AutomaticKeepAliveClientMixin<ReceivePage> {
  @override
  bool get wantKeepAlive => true;

  final UsbAntennaService usbService = UsbAntennaService();

  static const int duplicateIgnoreSeconds = 10;

  final Map<String, DateTime> recentRecordSignatures = {};

  int duplicateSkipCount = 0;

  Timer? receiveRefreshTimer;

  AppSettings appSettings = const AppSettings();

  final TextEditingController jsonController = TextEditingController(
    text:
        '{"Password":926877721,"State":3,"Lock":1,"Conter_Lock":10,"Battery_Percent":30,"Count":76}',
  );

  StreamSubscription<String>? usbSubscription;

  late List<TagRecord> receivedRecords;

  bool isUsbConnected = false;
  bool isUsbConnecting = false;
  String usbStatus = 'قطع';
  String lastUsbJson = '-';
  bool isGettingLocation = false;
  String gpsStatus = 'آماده دریافت موقعیت';
  AppLocationResult? lastLocationResult;

  @override
  void initState() {
    super.initState();

    receivedRecords = [];
    loadReceivedRecords();
    loadAppSettings();

    receiveRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (!mounted) return;
        setState(() {});
      },
    );
  }

  @override
  void dispose() {
    receiveRefreshTimer?.cancel();

    usbSubscription?.cancel();
    unawaited(usbService.dispose());
    jsonController.dispose();

    super.dispose();
  }

  Future<void> loadReceivedRecords() async {
    final loadedRecords = await LocalStorageService.loadTagRecords();

    if (!mounted) return;

    setState(() {
      receivedRecords = loadedRecords;
    });
  }

  Future<void> loadAppSettings() async {
    final settings = await AppSettingsService.loadSettings();

    if (!mounted) return;

    setState(() {
      appSettings = settings;
    });
  }

  DateTime? recordDateTime(TagRecord record) {
    final text = record.receivedDateTime.trim();

    if (text.isEmpty) return null;

    return DateTime.tryParse(text);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<TagRecord> getTodayRecords(List<TagRecord> source) {
    final now = DateTime.now();

    return source.where((record) {
      final parsed = recordDateTime(record);

      if (parsed == null) return false;

      return isSameDay(parsed, now);
    }).toList();
  }

  Future<void> connectUsbDevice() async {
   await LiveHerdSessionService.startSession(
      reset: true,
    );

    try {
      setState(() {
        isUsbConnecting = true;
        usbStatus = 'در حال جستجوی دستگاه USB...';
      });

      await usbService.connectFirstDevice(
        baudRate: appSettings.usbBaudRate,
      );

      await usbSubscription?.cancel();

      usbSubscription = usbService.jsonStream.listen(
        (jsonText) async {
          await processJsonText(
            jsonText,
            locationName: appSettings.defaultLocationName,
            showSnackBar: false,
          );
        },
        onError: (error) {
          if (!mounted) return;

          setState(() {
            usbStatus = 'خطای دریافت USB';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطای USB: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );

      if (!mounted) return;

      setState(() {
        isUsbConnected = true;
        isUsbConnecting = false;
        usbStatus = 'متصل: ${usbService.connectedDeviceName}';
      });

      await UsbLogService.addLog(
        type: UsbLogType.connected,
        title: 'اتصال USB برقرار شد',
        message: usbService.connectedDeviceName,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('دستگاه USB متصل شد: ${usbService.connectedDeviceName}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isUsbConnected = false;
        isUsbConnecting = false;
        usbStatus = 'اتصال ناموفق';
      });

      await UsbLogService.addLog(
        type: UsbLogType.error,
        title: 'خطا در اتصال USB',
        message: e.toString(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در اتصال USB: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> disconnectUsbDevice() async {
    await usbSubscription?.cancel();
    usbSubscription = null;

    await usbService.disconnect();

    await UsbLogService.addLog(
      type: UsbLogType.disconnected,
      title: 'اتصال USB قطع شد',
      message: 'کاربر اتصال USB را قطع کرد.',
    );

    if (!mounted) return;

    setState(() {
      isUsbConnected = false;
      usbStatus = 'قطع';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('اتصال USB قطع شد.'),
      ),
    );
  }

  String buildRecordSignature(AntennaPayload payload) {
    return '${payload.password}-'
        '${payload.lock}-'
        '${payload.counterLock}-'
        '${payload.batteryPercent}';
  }

  bool shouldSkipDuplicate(String signature) {
    final now = DateTime.now();

    recentRecordSignatures.removeWhere((key, time) {
      return now.difference(time).inSeconds > 60;
    });

    final previousTime = recentRecordSignatures[signature];

    if (previousTime != null &&
        now.difference(previousTime).inSeconds < duplicateIgnoreSeconds) {
      recentRecordSignatures[signature] = now;
      return true;
    }

    recentRecordSignatures[signature] = now;
    return false;
  }

  Future<AppLocationResult> getLocationForRecord() async {
    if (mounted) {
      setState(() {
        isGettingLocation = true;
        gpsStatus = 'در حال دریافت GPS...';
      });
    }

    final result = await LocationService.getCurrentLocation();

    if (mounted) {
      setState(() {
        isGettingLocation = false;
        lastLocationResult = result;
        gpsStatus = result.message;
      });
    }

    return result;
  }

  Future<void> processJsonText(
    String jsonText, {
    required String locationName,
    bool showSnackBar = true,
  }) async {
    try {
      final payload = AntennaPayload.fromJsonString(jsonText.trim());

      final tagId = 'T-${payload.password}';
      final signature = buildRecordSignature(payload);

      if (shouldSkipDuplicate(signature)) {
        setState(() {
          duplicateSkipCount++;
          lastUsbJson = jsonText.trim();
          jsonController.text = jsonText.trim();
          usbStatus = 'داده تکراری نادیده گرفته شد: $tagId';
        });

        if (showSnackBar) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('رکورد تکراری ذخیره نشد: $tagId'),
            ),
          );
        }

        await UsbLogService.addLog(
          type: UsbLogType.duplicate,
          title: 'رکورد تکراری نادیده گرفته شد',
          message: '$tagId / $jsonText',
        );

        return;
      }

      final camelProfile = await CamelProfileService.getOrCreateProfile(tagId);

      final locationResult = await getLocationForRecord();

      String finalLocationName = locationName;

      if (locationResult.success) {
        finalLocationName = '$locationName + GPS گوشی';
      } else {
        finalLocationName = '$locationName بدون GPS';

        await UsbLogService.addLog(
          type: UsbLogType.info,
          title: 'GPS ثبت نشد',
          message: locationResult.message,
        );
      }

      final record = payload.toTagRecord(
        locationName: finalLocationName,
        camelNo: camelProfile.camelNo,
        camelName: camelProfile.camelName,
        latitude: locationResult.latitude,
        longitude: locationResult.longitude,
        accuracy: locationResult.accuracy,
      );

      setState(() {
        lastUsbJson = jsonText.trim();
        jsonController.text = jsonText.trim();
        receivedRecords.insert(0, record);
        usbStatus = isUsbConnected ? 'دریافت شد: ${record.tagId}' : usbStatus;
      });

      await LocalStorageService.addTagRecord(record);

      await UsbLogService.addLog(
        type: UsbLogType.received,
        title: 'رکورد جدید ذخیره شد',
        message: '${record.camelName} / ${record.tagId} / ${record.batteryText}',
      );

      await createAlertsForRecord(record);

      if (!mounted) return;

      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('داده پردازش و ذخیره شد: ${record.tagId}'),
          ),
        );
      }
    } catch (e) {
      final now = DateTime.now();
      final hour = now.hour.toString().padLeft(2, '0');
      final minute = now.minute.toString().padLeft(2, '0');

      await AlertService.addAlert(
        AppAlert(
          id: 'json-error-${now.millisecondsSinceEpoch}',
          title: 'خطای خواندن داده USB',
          subtitle: 'JSON دریافتی از دستگاه معتبر نبود.',
          time: '$hour:$minute',
          locationName: 'دریافت USB',
          type: AlertType.antennaError,
          level: AlertLevel.warning,
          messageSent: false,
          reviewed: false,
        ),
      );

      await UsbLogService.addLog(
        type: UsbLogType.invalidJson,
        title: 'خطا در خواندن JSON',
        message: '${e.toString()} / $jsonText',
      );

      if (!mounted) return;

      setState(() {
        usbStatus = 'JSON نامعتبر';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در خواندن JSON: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> processManualJson() async {
    await processJsonText(
      jsonController.text,
      locationName: 'ورود دستی JSON',
      showSnackBar: true,
    );
  }

  Future<void> createAlertsForRecord(TagRecord record) async {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute';

    final alerts = <AppAlert>[];

    if (record.isBatteryLow) {
      alerts.add(
        AppAlert(
          id: 'low-battery-${record.tagId}-${now.millisecondsSinceEpoch}',
          title: 'باتری ضعیف',
          subtitle:
              '${record.camelName} با تگ ${record.tagId} باتری ${record.batteryText} دارد.',
          time: time,
          relatedTagId: record.tagId,
          locationName: record.locationName,
          type: AlertType.lowBattery,
          level: AlertLevel.warning,
          messageSent: false,
          reviewed: false,
        ),
      );
    }

    if (record.lock == 0) {
      alerts.add(
        AppAlert(
          id: 'tag-unlocked-${record.tagId}-${now.millisecondsSinceEpoch}',
          title: 'تگ از شتر باز شده',
          subtitle:
              '${record.camelName} با تگ ${record.tagId} وضعیت Lock = 0 دارد.',
          time: time,
          relatedTagId: record.tagId,
          locationName: record.locationName,
          type: AlertType.tagUnlocked,
          level: AlertLevel.urgent,
          messageSent: false,
          reviewed: false,
        ),
      );
    }

    final zones = await AreaZoneService.loadZones();

    if (record.latitude != null && record.longitude != null && zones.isNotEmpty) {
      final zoneResult = ZoneCheckService.checkRecord(
        record: record,
        zones: zones,
      );

      if (zoneResult.isInsideForbiddenZone) {
        final zoneNames = zoneResult.forbiddenZones
            .map((zone) => zone.name)
            .join('، ');

        alerts.add(
          AppAlert(
            id: 'forbidden-zone-${record.tagId}-${now.millisecondsSinceEpoch}',
            title: 'ورود به منطقه ممنوع',
            subtitle:
                '${record.camelName} با تگ ${record.tagId} وارد محدوده ممنوع «$zoneNames» شده است.',
            time: time,
            relatedTagId: record.tagId,
            locationName: zoneNames,
            type: AlertType.forbiddenZone,
            level: AlertLevel.urgent,
            messageSent: false,
            reviewed: false,
          ),
        );
      }

      if (zoneResult.isOutsideAllowedZones) {
        alerts.add(
          AppAlert(
            id: 'outside-zone-${record.tagId}-${now.millisecondsSinceEpoch}',
            title: 'خروج از محدوده مجاز',
            subtitle:
                '${record.camelName} با تگ ${record.tagId} خارج از آغل، چراگاه، آبشخور یا مسیر تعریف‌شده قرار دارد.',
            time: time,
            relatedTagId: record.tagId,
            locationName: record.locationName,
            type: AlertType.routeExit,
            level: AlertLevel.warning,
            messageSent: false,
            reviewed: false,
          ),
        );
      }
    }

    await AlertService.addAlerts(alerts);
  }

  Future<void> saveAllReceivedRecords() async {
    final todayRecords = getTodayRecords(receivedRecords);

    await LocalStorageService.saveTagRecords(receivedRecords);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${todayRecords.length} رکورد امروز در حافظه محلی ثبت شد.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final todayRecords = getTodayRecords(receivedRecords);

    return SingleChildScrollView(
      child: Column(
        children: [
          const AppHeader(title: 'دریافت زنده تگ‌ها'),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: MiniInfo(
                              title: 'USB',
                              value: isUsbConnected ? 'متصل' : 'قطع',
                            ),
                          ),
                          Expanded(
                            child: MiniInfo(
                              title: 'رکورد امروز',
                              value: todayRecords.length.toString(),
                            ),
                          ),
                          Expanded(
                            child: MiniInfo(
                              title: 'تکراری‌ها',
                              value: duplicateSkipCount.toString(),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUsbConnected
                              ? const Color(0xFFEAF8F2)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isUsbConnected
                                ? const Color(0xFFB7E5D2)
                                : const Color(0xFFFFCC80),
                          ),
                        ),
                        child: Text(
                          'وضعیت USB: $usbStatus',
                          style: TextStyle(
                            color: isUsbConnected
                                ? const Color(0xFF0A4F35)
                                : const Color(0xFF8A4B00),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isGettingLocation
                              ? const Color(0xFFFFF3E0)
                              : const Color(0xFFEAF8F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            if (isGettingLocation)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Icon(
                                lastLocationResult?.success == true
                                    ? Icons.gps_fixed_rounded
                                    : Icons.gps_not_fixed_rounded,
                                color: lastLocationResult?.success == true
                                    ? const Color(0xFF008B62)
                                    : const Color(0xFFE87500),
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'GPS: $gpsStatus',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF062C5E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (lastUsbJson != '-') ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              lastUsbJson,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isUsbConnecting || isUsbConnected
                                  ? null
                                  : connectUsbDevice,
                              icon: isUsbConnecting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.usb_rounded),
                              label: Text(
                                isUsbConnecting
                                    ? 'در حال اتصال...'
                                    : 'اتصال USB',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF003B7A),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                disabledForegroundColor: Colors.grey.shade600,
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
                              onPressed:
                                  isUsbConnected ? disconnectUsbDevice : null,
                              icon: const Icon(Icons.usb_off_rounded),
                              label: const Text('قطع USB'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD32F2F),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                disabledForegroundColor: Colors.grey.shade600,
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

                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: cardDecoration(),
                  child: Column(
                    children: [
                      const SectionTitle(title: 'JSON دریافتی / تست دستی'),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: TextField(
                          controller: jsonController,
                          maxLines: 4,
                          textAlign: TextAlign.left,
                          decoration: InputDecoration(
                            hintText: 'JSON دریافتی از دستگاه USB',
                            filled: true,
                            fillColor: const Color(0xFFF5F7FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: processManualJson,
                          icon: const Icon(
                            Icons.settings_input_antenna_rounded,
                          ),
                          label: const Text('پردازش دستی JSON'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF008B62),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
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
                      const SectionTitle(title: 'تگ‌های دریافت‌شده امروز'),
                      if (todayRecords.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'امروز هنوز رکوردی دریافت نشده است.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black54,
                              height: 1.7,
                            ),
                          ),
                        )
                      else
                        ...todayRecords
                            .take(8)
                            .map((record) => RecentTagRow(record: record)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008B62),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: saveAllReceivedRecords,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      'ثبت و ذخیره ${todayRecords.length} رکورد امروز',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                                ? Colors.red.withOpacity(0.10)
                                : Colors.green.withOpacity(0.10),
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
  DateTime selectedDate = DateTime.now();

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
    final records = await LocalStorageService.loadTagRecords();

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

    return DateTime.tryParse(record.receivedDateTime);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool isRecordInSelectedDate(TagRecord record) {
    final date = recordDate(record);

    if (date == null) {
      return isSameDay(selectedDate, DateTime.now());
    }

    return isSameDay(date, selectedDate);
  }

  List<TagRecord> get dailyRecords {
    return allRecords.where(isRecordInSelectedDate).toList();
  }

  String twoDigit(int value) {
    return value.toString().padLeft(2, '0');
  }

  String dateText(DateTime date) {
    return '${date.year}/${twoDigit(date.month)}/${twoDigit(date.day)}';
  }

  bool get isToday {
    return isSameDay(selectedDate, DateTime.now());
  }

  void changeDay(int offset) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: offset));
    });
  }

  void goToToday() {
    setState(() {
      selectedDate = DateTime.now();
    });
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

    await LocalStorageService.saveTagRecords(updatedRecords);

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

DateTime selectedDate = DateTime.now();

int slotMinutes = 60;
int maxGapMinutes = 30;

List<TagRecord> records = [];
List<AreaZone> zones = [];
List<CamelProfile> profiles = [];
List<AppAlert> alerts = [];

AppSettings appSettings = const AppSettings();

ManagementReport? report;

  @override
  void initState() {
    super.initState();
    loadReportData();
  }

 Future<void> loadReportData() async {
   final loadedRecords = await LocalStorageService.loadTagRecords();
   final loadedZones = await AreaZoneService.loadZones();
   final loadedProfiles = await CamelProfileService.loadProfiles();
   final loadedAlerts = await AlertService.loadAlerts();
   final loadedSettings = await AppSettingsService.loadSettings();

   final builtReport = ManagementReportService.buildDailyReport(
     records: loadedRecords,
     zones: loadedZones,
     profiles: loadedProfiles,
     date: selectedDate,
     slotMinutes: slotMinutes,
     maxGapMinutes: maxGapMinutes,
   );

   if (!mounted) return;

   setState(() {
     records = loadedRecords;
     zones = loadedZones;
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
    return '${date.year}/${twoDigit(date.month)}/${twoDigit(date.day)}';
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool get isToday {
    return isSameDay(selectedDate, DateTime.now());
  }

  void changeDay(int offset) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: offset));
    });

    rebuildReport();
  }

  void goToToday() {
    setState(() {
      selectedDate = DateTime.now();
    });

    rebuildReport();
  }

  Future<void> pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
        builder: (_) => PrintableManagementReportPreviewPage(
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
      if (!mounted) return;

      setState(() {
        isExportingExcel = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final currentReport = report;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('گزارش مدیریتی'),
          centerTitle: true,
          backgroundColor: const Color(0xFF062C5E),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: rebuildReport,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'بارگذاری مجدد',
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: isLoading || currentReport == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: rebuildReport,
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        buildDateSelector(),
                        const SizedBox(height: 14),
                        buildReportSettings(),
                        const SizedBox(height: 14),
                       buildSummarySection(currentReport.summary),
                       const SizedBox(height: 14),
                       buildExcelExportButton(),
                       const SizedBox(height: 14),
                       buildLastStatusSection(currentReport),
                        const SizedBox(height: 14),
                        buildTimeSlotSection(currentReport),
                        const SizedBox(height: 14),
                        buildLocationDurationSection(currentReport),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
          ),
        ),
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
             label: const Text('پیش‌نمایش گزارش مدیر'),
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


class PrintableManagementReportPreviewPage extends StatelessWidget {
  final ManagementReport report;
  final AppSettings appSettings;
  final DateTime date;
  final List<CamelProfile> profiles;
  final List<AreaZone> zones;

  const PrintableManagementReportPreviewPage({
    super.key,
    required this.report,
    required this.appSettings,
    required this.date,
    required this.profiles,
    required this.zones,
  });

  String twoDigit(int value) {
    return value.toString().padLeft(2, '0');
  }

  String dateText(DateTime date) {
    return '${date.year}/${twoDigit(date.month)}/${twoDigit(date.day)}';
  }

  List<CamelLastStatusReport> get problemRows {
    return report.lastStatusRows.where((row) => row.hasProblem).toList();
  }

  List<CamelLastStatusReport> get normalRows {
    return report.lastStatusRows.where((row) => !row.hasProblem).toList();
  }

  int get activeZonesCount {
    return zones.where((zone) => zone.isActive).length;
  }

  Color statusColorByText(String text) {
    if (text.contains('ممنوع') || text.contains('باز')) {
      return const Color(0xFFD32F2F);
    }

    if (text.contains('خارج') ||
        text.contains('ضعیف') ||
        text.contains('دیده نشده')) {
      return const Color(0xFFE87500);
    }

    return const Color(0xFF008B62);
  }

  String buildPlainTextReport() {
    final summary = report.summary;

    final buffer = StringBuffer();

    buffer.writeln('گزارش مدیریتی ساربان');
    buffer.writeln('تاریخ: ${dateText(date)}');
    buffer.writeln('نام ساربان: ${appSettings.shepherdName}');
    buffer.writeln('شناسه ساربان: ${appSettings.shepherdId}');
    buffer.writeln('');
    buffer.writeln('خلاصه مدیریتی:');
    buffer.writeln('کل رکوردهای روز: ${summary.totalRecords}');
    buffer.writeln('شترهای ثبت‌شده: ${summary.registeredCamelCount}');
    buffer.writeln('شترهای دیده‌شده: ${summary.seenCamelCount}');
    buffer.writeln('شترهای دیده‌نشده: ${summary.missingCamelCount}');
    buffer.writeln('کل مشکلات مهم: ${summary.importantProblemsCount}');
    buffer.writeln('');
    buffer.writeln('جزئیات مشکلات:');
    buffer.writeln('باتری ضعیف: ${summary.lowBatteryCamelCount}');
    buffer.writeln('تگ باز شده: ${summary.unlockedEventCount}');
    buffer.writeln('ورود به منطقه ممنوع: ${summary.forbiddenEventCount}');
    buffer.writeln('خروج از محدوده مجاز: ${summary.outsideAllowedEventCount}');
    buffer.writeln('');

    if (problemRows.isEmpty) {
      buffer.writeln('شتر نیازمند بررسی: موردی ثبت نشده');
    } else {
      buffer.writeln('شترهای نیازمند بررسی:');

      for (final row in problemRows) {
        buffer.writeln(
          '- ${row.camelName} / ${row.tagId} / ${row.statusText} / ${row.lastLocationText}',
        );
      }
    }

    buffer.writeln('');
    buffer.writeln('جمع‌بندی: ${managerConclusionText()}');

    return buffer.toString();
  }

  String managerConclusionText() {
    final summary = report.summary;

    if (summary.totalRecords == 0) {
      return 'برای این تاریخ رکوردی ثبت نشده است. وضعیت دریافت دستگاه، GPS و اتصال USB بررسی شود.';
    }

    if (summary.importantProblemsCount == 0 && summary.missingCamelCount == 0) {
      return 'وضعیت کلی گله عادی است. مورد فوری برای پیگیری در این گزارش ثبت نشده است.';
    }

    return 'گزارش دارای موارد نیازمند بررسی است. ابتدا شترهای دارای تگ باز، ورود به منطقه ممنوع و شترهای دیده‌نشده بررسی شوند.';
  }

  Future<void> copyReportText(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: buildPlainTextReport()),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('متن گزارش مدیر کپی شد.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = report.summary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('پیش‌نمایش گزارش مدیر'),
          centerTitle: true,
          backgroundColor: const Color(0xFF062C5E),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: () {
                copyReportText(context);
              },
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'کپی متن گزارش',
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                buildPrintableHeader(),
                const SizedBox(height: 14),
                buildManagerSummary(summary),
                const SizedBox(height: 14),
                buildProblemDetails(summary),
                const SizedBox(height: 14),
                buildProblemCamelsSection(),
                const SizedBox(height: 14),
                buildNormalCamelsSection(),
                const SizedBox(height: 14),
                buildConclusionSection(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      copyReportText(context);
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('کپی متن خلاصه گزارش'),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPrintableHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF062C5E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.assignment_rounded,
            color: Colors.white,
            size: 42,
          ),
          const SizedBox(height: 10),
          const Text(
            'گزارش قابل ارائه به مدیر مجموعه',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'تاریخ گزارش: ${dateText(date)}',
            style: const TextStyle(
              color: Colors.white,
              height: 1.7,
            ),
          ),
          Text(
            'ساربان: ${appSettings.shepherdName}',
            style: const TextStyle(
              color: Colors.white,
              height: 1.7,
            ),
          ),
          Text(
            'شناسه: ${appSettings.shepherdId}',
            style: const TextStyle(
              color: Colors.white,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildManagerSummary(ManagementReportSummary summary) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'خلاصه مدیریتی',
            style: TextStyle(
              color: Color(0xFF062C5E),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ManagerPreviewInfoRow(
            title: 'کل رکوردهای ثبت‌شده در روز',
            value: summary.totalRecords.toString(),
            status: summary.totalRecords == 0 ? 'بدون داده' : 'ثبت شده',
            color: summary.totalRecords == 0
                ? const Color(0xFFE87500)
                : const Color(0xFF008B62),
          ),
          ManagerPreviewInfoRow(
            title: 'شترهای ثبت‌شده',
            value: summary.registeredCamelCount.toString(),
            status: profiles.isEmpty ? 'بر اساس رکوردها' : 'بر اساس پروفایل‌ها',
            color: const Color(0xFF086EBB),
          ),
          ManagerPreviewInfoRow(
            title: 'شترهای دیده‌شده',
            value: summary.seenCamelCount.toString(),
            status: summary.seenCamelCount == 0 ? 'نیازمند بررسی' : 'عادی',
            color: summary.seenCamelCount == 0
                ? const Color(0xFFE87500)
                : const Color(0xFF008B62),
          ),
          ManagerPreviewInfoRow(
            title: 'شترهای دیده‌نشده',
            value: summary.missingCamelCount.toString(),
            status: summary.missingCamelCount > 0 ? 'نیازمند پیگیری' : 'عادی',
            color: summary.missingCamelCount > 0
                ? const Color(0xFFE87500)
                : const Color(0xFF008B62),
          ),
          ManagerPreviewInfoRow(
            title: 'کل مشکلات مهم',
            value: summary.importantProblemsCount.toString(),
            status: summary.importantProblemsCount > 0
                ? 'نیازمند اقدام'
                : 'عادی',
            color: summary.importantProblemsCount > 0
                ? const Color(0xFFD32F2F)
                : const Color(0xFF008B62),
          ),
          ManagerPreviewInfoRow(
            title: 'محدوده‌های فعال',
            value: activeZonesCount.toString(),
            status: activeZonesCount == 0 ? 'محدوده تعریف نشده' : 'فعال',
            color: activeZonesCount == 0
                ? const Color(0xFFE87500)
                : const Color(0xFF008B62),
          ),
        ],
      ),
    );
  }

  Widget buildProblemDetails(ManagementReportSummary summary) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'جزئیات مشکلات',
            style: TextStyle(
              color: Color(0xFF062C5E),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ManagementBadge(
                icon: Icons.battery_alert_rounded,
                text: 'باتری ضعیف: ${summary.lowBatteryCamelCount}',
                color: summary.lowBatteryCamelCount > 0
                    ? const Color(0xFFE87500)
                    : const Color(0xFF008B62),
              ),
              ManagementBadge(
                icon: Icons.lock_open_rounded,
                text: 'تگ باز: ${summary.unlockedEventCount}',
                color: summary.unlockedEventCount > 0
                    ? const Color(0xFFD32F2F)
                    : const Color(0xFF008B62),
              ),
              ManagementBadge(
                icon: Icons.block_rounded,
                text: 'ممنوعه: ${summary.forbiddenEventCount}',
                color: summary.forbiddenEventCount > 0
                    ? const Color(0xFFD32F2F)
                    : const Color(0xFF008B62),
              ),
              ManagementBadge(
                icon: Icons.alt_route_rounded,
                text: 'خارج محدوده: ${summary.outsideAllowedEventCount}',
                color: summary.outsideAllowedEventCount > 0
                    ? const Color(0xFFE87500)
                    : const Color(0xFF008B62),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildProblemCamelsSection() {
    return Container(
      decoration: cardDecoration(),
      child: Column(
        children: [
          const SectionTitle(title: 'شترهای نیازمند بررسی'),
          if (problemRows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'موردی برای بررسی ثبت نشده است.',
                style: TextStyle(
                  color: Color(0xFF008B62),
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            ...problemRows.map(
              (row) => ManagerCamelPreviewRow(
                row: row,
                color: statusColorByText(row.statusText),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildNormalCamelsSection() {
    final rows = normalRows.take(20).toList();

    return Container(
      decoration: cardDecoration(),
      child: Column(
        children: [
          const SectionTitle(title: 'آخرین وضعیت شترهای عادی'),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'شتر عادی برای نمایش وجود ندارد.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            ...rows.map(
              (row) => ManagerCamelPreviewRow(
                row: row,
                color: const Color(0xFF008B62),
              ),
            ),
          if (normalRows.length > 20)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${normalRows.length - 20} شتر دیگر در گزارش کامل Excel نمایش داده می‌شود.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  height: 1.7,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildConclusionSection() {
    final summary = report.summary;

    final color = summary.totalRecords == 0
        ? const Color(0xFFE87500)
        : summary.importantProblemsCount > 0 || summary.missingCamelCount > 0
            ? const Color(0xFFD32F2F)
            : const Color(0xFF008B62);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            color == const Color(0xFF008B62)
                ? Icons.check_circle_rounded
                : Icons.warning_rounded,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              managerConclusionText(),
              style: TextStyle(
                color: color,
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



class ManagerPreviewInfoRow extends StatelessWidget {
  final String title;
  final String value;
  final String status;
  final Color color;

  const ManagerPreviewInfoRow({
    super.key,
    required this.title,
    required this.value,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 9,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE8EDF3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 110),
            padding: const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ManagerCamelPreviewRow extends StatelessWidget {
  final CamelLastStatusReport row;
  final Color color;

  const ManagerCamelPreviewRow({
    super.key,
    required this.row,
    required this.color,
  });

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
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE8EDF3)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(
                  icon,
                  color: color,
                  size: 21,
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
                constraints: const BoxConstraints(maxWidth: 125),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  row.statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
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
            backgroundColor: color.withOpacity(0.12),
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
        color: color.withOpacity(0.09),
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
                backgroundColor: color.withOpacity(0.12),
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
                  color: color.withOpacity(0.10),
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
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
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
            color: Colors.black.withOpacity(0.035),
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
        color: isEmpty ? const Color(0xFFF3F5F8) : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEmpty
              ? const Color(0xFFE3E7ED)
              : color.withOpacity(0.26),
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
            color: Colors.black.withOpacity(0.035),
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
                      color: color.withOpacity(0.10),
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



class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  bool isLoading = true;
  List<AppAlert> alerts = [];

  @override
  void initState() {
    super.initState();
    loadAlerts();
  }

  Future<void> loadAlerts() async {
    final loadedAlerts = await AlertService.loadAlerts();

    await AlertService.refreshUnreviewedCount();

    if (!mounted) return;

    setState(() {
      alerts = loadedAlerts;
      isLoading = false;
    });
  }

  Future<void> markAlertReviewed(AppAlert alert) async {
    if (alert.reviewed) return;

    await AlertService.markReviewed(alert.id);

    if (!mounted) return;

    setState(() {
      alerts = alerts.map((item) {
        if (item.id == alert.id) {
          return item.copyWith(reviewed: true);
        }

        return item;
      }).toList();
    });
  }

  Future<void> markAllReviewed() async {
    await AlertService.markAllReviewed();

    if (!mounted) return;

    setState(() {
      alerts = alerts.map((alert) {
        return alert.copyWith(reviewed: true);
      }).toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('همه هشدارها دیده شدند.'),
      ),
    );
  }

  Future<void> clearAlerts() async {
    await AlertService.clearAlerts();

    if (!mounted) return;

    setState(() {
      alerts = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('هشدارها پاک شدند.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeAlerts = alerts.where((alert) {
      return alert.reviewed == false;
    }).toList();

    final urgentCount = activeAlerts.where((a) {
      return a.level == AlertLevel.urgent;
    }).length;

    final lowBatteryCount = activeAlerts.where((a) {
      return a.type == AlertType.lowBattery;
    }).length;

    final unsentCount = activeAlerts.where((a) {
      return !a.messageSent;
    }).length;

    final unreviewedCount = activeAlerts.length;

    return SingleChildScrollView(
      child: Column(
        children: [
          const AppHeader(title: 'هشدارها و رویدادها'),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AlertSummaryCard(
                        title: 'هشدار فوری',
                        value: urgentCount.toString(),
                        icon: Icons.warning_rounded,
                        color: const Color(0xFFD32F2F),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AlertSummaryCard(
                        title: 'باتری ضعیف',
                        value: lowBatteryCount.toString(),
                        icon: Icons.battery_alert_rounded,
                        color: const Color(0xFFE87500),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AlertSummaryCard(
                        title: 'دیده‌نشده',
                        value: unreviewedCount.toString(),
                        icon: Icons.visibility_off_rounded,
                        color: const Color(0xFF086EBB),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: loadAlerts,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('بارگذاری'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            alerts.isEmpty ? null : markAllReviewed,
                        icon: const Icon(Icons.done_all_rounded),
                        label: const Text('سین همه'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: alerts.isEmpty ? null : clearAlerts,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('پاک‌سازی هشدارها'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD32F2F),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  )
                else if (alerts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: cardDecoration(),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 54,
                          color: Color(0xFF008B62),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'فعلاً هشدار فعالی وجود ندارد.',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'اگر باتری ضعیف باشد، تگ باز شود یا شتر از محدوده خارج شود، هشدار اینجا نمایش داده می‌شود.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...alerts.map(
                    (alert) => GestureDetector(
                      onTap: () {
                        markAlertReviewed(alert);
                      },
                      child: Opacity(
                        opacity: alert.reviewed ? 0.55 : 1,
                        child: AlertCard(alert: alert),
                      ),
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

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  void showAboutProject(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('درباره پروژه ساربان'),
            content: const Text(
              'سامانه پایش شترها با دریافت داده از آنتن USB، ثبت اطلاعات تگ‌ها، مدیریت شترها، ذخیره سوابق و آماده‌سازی گزارش‌های روزانه.',
              style: TextStyle(height: 1.7),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('بستن'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Column(
          children: [
            const AppHeader(title: 'بیشتر'),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                    children: [
                     Container(
                       decoration: cardDecoration(),
                       child: Material(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(20),
                         clipBehavior: Clip.antiAlias,
                         child: Column(
                           children: [
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFEAF8F2),
                                child: Icon(
                                  Icons.pets_rounded,
                                  color: Color(0xFF008B62),
                                ),
                              ),
                              title: const Text(
                                'مدیریت شترها',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text(
                                'ویرایش نام شترها و اتصال آن‌ها به شناسه تگ',
                              ),
                              trailing: const Icon(Icons.chevron_left_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const CamelManagementPage(),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFEAF2FF),
                                child: Icon(
                                  Icons.history_rounded,
                                  color: Color(0xFF086EBB),
                                ),
                              ),
                              title: const Text(
                                'سوابق دریافت',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text(
                                'مشاهده رکوردهای ذخیره‌شده، فیلتر تاریخ و جستجو',
                              ),
                              trailing: const Icon(Icons.chevron_left_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RecordsHistoryPage(),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFEAF8F2),
                                child: Icon(
                                  Icons.analytics_rounded,
                                  color: Color(0xFF008B62),
                                ),
                              ),
                              title: const Text(
                                'گزارش مدیریتی',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text(
                                'خلاصه حضور، مکان، هشدار و آخرین وضعیت شترها',
                              ),
                              trailing: const Icon(Icons.chevron_left_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ManagementReportPage(),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFEAF8F2),
                                child: Icon(
                                  Icons.terminal_rounded,
                                  color: Color(0xFF008B62),
                                ),
                              ),
                              title: const Text(
                                'لاگ دریافت USB',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text(
                                'مشاهده اتصال، خطاها و داده‌های دریافتی دستگاه',
                              ),
                              trailing: const Icon(Icons.chevron_left_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const UsbLogsPage(),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFFF3E0),
                                child: Icon(
                                  Icons.settings_rounded,
                                  color: Color(0xFFE87500),
                                ),
                              ),
                              title: const Text(
                                'تنظیمات سامانه',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text(
                                'شماره مرکز، سرعت USB و تنظیمات پیامک',
                              ),
                              trailing: const Icon(Icons.chevron_left_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SystemSettingsPage(),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFF0F0F0),
                                child: Icon(
                                  Icons.info_rounded,
                                  color: Colors.black54,
                                ),
                              ),
                              title: const Text(
                                'درباره پروژه',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text(
                                'اطلاعات کلی سامانه پایش شترها',
                              ),
                              trailing: const Icon(Icons.chevron_left_rounded),
                              onTap: () {
                                showAboutProject(context);
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFFF3E0),
                                child: Icon(Icons.sms_rounded, color: Color(0xFFE87500)),
                              ),
                              title: const Text(
                                'تنظیمات پیامک',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text('شماره مقصد، تایمر ارسال و متن گزارش پیامکی'),
                              trailing: const Icon(Icons.chevron_left_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SmsReportSettingsPage(),
                                  ),
                                );
                              },
                            ),

                            const Divider(height: 1),
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFEAF8F2),
                                child: Icon(
                                  Icons.pets_rounded,
                                  color: Color(0xFF008B62),
                                ),
                              ),
                              title: const Text(
                                'وضعیت زنده گله',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text(
                                'گزارش لحظه‌ای از جلسه دریافت آنتن',
                              ),
                              trailing: const Icon(Icons.chevron_left_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LiveHerdPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class CamelManagementPage extends StatefulWidget {
  const CamelManagementPage({super.key});

  @override
  State<CamelManagementPage> createState() => _CamelManagementPageState();
}

class _CamelManagementPageState extends State<CamelManagementPage> {
  bool isLoading = true;
  List<CamelProfile> profiles = [];

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
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('مدیریت شترها'),
          centerTitle: true,
          backgroundColor: const Color(0xFF062C5E),
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
          backgroundColor: const Color(0xFF008B62),
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
                                'از صفحه دریافت، یک تگ را پردازش کن یا از دکمه «ثبت شتر» استفاده کن.',
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
                        child: ListView(
                          padding: const EdgeInsets.all(14),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF8F2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFB7E5D2),
                                ),
                              ),
                              child: Text(
                                'تعداد شترهای ثبت‌شده: ${profiles.length}',
                                style: const TextStyle(
                                  color: Color(0xFF0A4F35),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...profiles.map(
                              (profile) => CamelProfileCard(
                                profile: profile,
                                onEdit: () {
                                  openCamelDialog(profile: profile);
                                },
                                onActiveChanged: (value) {
                                  toggleActive(profile, value);
                                },
                              ),
                            ),
                            const SizedBox(height: 80),
                          ],
                        ),
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
  final ValueChanged<bool> onActiveChanged;

  const CamelProfileCard({
    super.key,
    required this.profile,
    required this.onEdit,
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
              const SizedBox(width: 10),
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
                        ? const Color(0xFF008B62)
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

  String searchText = '';
  RecordStatusFilter selectedStatusFilter = RecordStatusFilter.all;
  RecordDateFilter selectedDateFilter = RecordDateFilter.all;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
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

    return DateTime.tryParse(record.receivedDateTime);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String twoDigit(int value) {
    return value.toString().padLeft(2, '0');
  }

  String dateText(DateTime date) {
    return '${date.year}/${twoDigit(date.month)}/${twoDigit(date.day)}';
  }

  bool matchesDateFilter(TagRecord record) {
    final date = recordDate(record);

    if (selectedDateFilter == RecordDateFilter.all) {
      return true;
    }

    if (date == null) {
      return selectedDateFilter == RecordDateFilter.today;
    }

    final now = DateTime.now();
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
    final pickedDate = await showDatePicker(
      context: context,
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

    await LocalStorageService.saveTagRecords(updatedRecords);

    if (!mounted) return;

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
                                  'از صفحه دریافت، JSON را پردازش کن یا دستگاه USB را وصل کن.',
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
                        ...visibleRecords.map(
                          (record) => RecordHistoryCard(
                            record: record,
                            onDelete: () {
                              deleteSingleRecord(record);
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
            backgroundColor: color.withOpacity(0.12),
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

    return DateTime.tryParse(record.receivedDateTime);
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

    return '${date.year}/${twoDigit(date.month)}/${twoDigit(date.day)}';
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



class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  final shepherdNameController = TextEditingController();
  final shepherdIdController = TextEditingController();
  final centerPhoneController = TextEditingController();
  final locationNameController = TextEditingController();
  final baudRateController = TextEditingController();
  final herdIdController = TextEditingController();
  final herdNameController = TextEditingController();
  final camelCountController = TextEditingController();
  final deviceIdController = TextEditingController();

  bool smsEnabled = true;
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

 @override
 void dispose() {

   shepherdNameController.dispose();
   shepherdIdController.dispose();
   centerPhoneController.dispose();

   herdIdController.dispose();
   herdNameController.dispose();
   camelCountController.dispose();

   deviceIdController.dispose();

   locationNameController.dispose();
   baudRateController.dispose();

   super.dispose();
 }

  Future<void> loadSettings() async {
    final settings = await AppSettingsService.loadSettings();

    shepherdNameController.text = settings.shepherdName;
    shepherdIdController.text = settings.shepherdId;
    centerPhoneController.text = settings.centerPhone;
    locationNameController.text = settings.defaultLocationName;
    baudRateController.text = settings.usbBaudRate.toString();
    herdIdController.text =
        settings.herdId;

    herdNameController.text =
        settings.herdName;

    camelCountController.text =
        settings.camelCount.toString();

    deviceIdController.text =
        settings.deviceId;

    if (!mounted) return;

    setState(() {
      smsEnabled = settings.smsEnabled;
      isLoading = false;
    });
  }

  Future<void> saveSettings() async {
    final baudRateText = baudRateController.text.trim();
    final baudRate = int.tryParse(baudRateText);

    if (baudRate == null || baudRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سرعت USB معتبر نیست. مثلاً 9600 یا 115200 وارد کن.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

   final settings = AppSettings(

     shepherdName:
         shepherdNameController.text.trim().isEmpty
             ? 'ساربان'
             : shepherdNameController.text.trim(),

     shepherdId:
         shepherdIdController.text.trim().isEmpty
             ? '-'
             : shepherdIdController.text.trim(),

     centerPhone:
         centerPhoneController.text.trim(),


     herdId:
         herdIdController.text.trim(),

     herdName:
         herdNameController.text.trim(),


     camelCount:
         int.tryParse(
           camelCountController.text.trim(),
         ) ?? 0,


     deviceId:
         deviceIdController.text.trim().isEmpty
             ? 'SARABAN-001'
             : deviceIdController.text.trim(),


     defaultLocationName:
         locationNameController.text.trim().isEmpty
             ? 'دریافت از USB'
             : locationNameController.text.trim(),

     usbBaudRate:
         baudRate,

     smsEnabled:
         smsEnabled,

   );

    await AppSettingsService.saveSettings(settings);

    if (!mounted) return;

    setState(() {
      isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تنظیمات سامانه ذخیره شد.'),
      ),
    );
  }

  Future<void> resetSettings() async {
    await AppSettingsService.resetSettings();
    await loadSettings();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تنظیمات به حالت پیش‌فرض برگشت.'),
      ),
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextDirection textDirection = TextDirection.rtl,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: textDirection,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('تنظیمات سامانه'),
          centerTitle: true,
          backgroundColor: const Color(0xFF062C5E),
          foregroundColor: Colors.white,
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionTitle(title: 'اطلاعات ساربان'),
                              buildTextField(
                                controller: shepherdNameController,
                                label: 'نام ساربان',
                                icon: Icons.person_rounded,
                              ),
                              const SizedBox(height: 12),
                              buildTextField(
                                controller: shepherdIdController,
                                label: 'شناسه ساربان',
                                icon: Icons.badge_rounded,
                                textDirection: TextDirection.ltr,
                              ),
                              const SizedBox(height: 12),
                              buildTextField(
                                controller: centerPhoneController,
                                label: 'شماره مرکز / مدیر',
                                icon: Icons.phone_rounded,
                                keyboardType: TextInputType.phone,
                                textDirection: TextDirection.ltr,
                              ),
                            ],
                          ),
                        ),
                          const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: cardDecoration(),

                          child: Column(

                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [

                              const SectionTitle(
                                title: 'اطلاعات گله',
                              ),


                              buildTextField(
                                controller: herdNameController,
                                label: 'نام گله',
                                icon: Icons.pets_rounded,
                              ),


                              const SizedBox(height:12),


                              buildTextField(
                                controller: herdIdController,
                                label: 'شناسه گله',
                                icon: Icons.badge_rounded,
                                textDirection: TextDirection.ltr,
                              ),


                              const SizedBox(height:12),


                              buildTextField(
                                controller: camelCountController,
                                label: 'تعداد کل شترها',
                                icon: Icons.format_list_numbered_rounded,
                                keyboardType: TextInputType.number,
                              ),

                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionTitle(title: 'تنظیمات دریافت USB'),
                              buildTextField(
                                controller: baudRateController,
                                label: 'سرعت USB / Baud Rate',
                                icon: Icons.usb_rounded,
                                keyboardType: TextInputType.number,
                                textDirection: TextDirection.ltr,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'مقدارهای رایج: 9600، 57600، 115200',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              buildTextField(
                                controller: locationNameController,
                                label: 'نام محل پیش‌فرض دریافت',
                                icon: Icons.place_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: cardDecoration(),

                          child: Column(

                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [

                              const SectionTitle(
                                title: 'شناسه دستگاه',
                              ),


                              buildTextField(
                                controller: deviceIdController,
                                label: 'Device ID',
                                icon: Icons.phone_android_rounded,
                                textDirection: TextDirection.ltr,
                              ),

                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: cardDecoration(),
                          child: SwitchListTile(
                            value: smsEnabled,
                            onChanged: (value) {
                              setState(() {
                                smsEnabled = value;
                              });
                            },
                            title: const Text(
                              'پیامک فعال باشد',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'بعداً برای ارسال خلاصه و هشدار استفاده می‌شود.',
                            ),
                            secondary: const Icon(Icons.sms_rounded),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: isSaving ? null : saveSettings,
                            icon: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(
                              isSaving ? 'در حال ذخیره...' : 'ذخیره تنظیمات',
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
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: resetSettings,
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('بازگشت به تنظیمات پیش‌فرض'),
                          ),
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

class UsbLogsPage extends StatefulWidget {
  const UsbLogsPage({super.key});

  @override
  State<UsbLogsPage> createState() => _UsbLogsPageState();
}

class _UsbLogsPageState extends State<UsbLogsPage> {
  bool isLoading = true;
  List<UsbLog> logs = [];

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  Future<void> loadLogs() async {
    final loadedLogs = await UsbLogService.loadLogs();

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
              'آیا مطمئنی همه لاگ‌های USB پاک شوند؟ رکوردهای دریافت‌شده پاک نمی‌شوند.',
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

    await UsbLogService.clearLogs();

    if (!mounted) return;

    setState(() {
      logs = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لاگ‌های USB پاک شدند.'),
      ),
    );
  }

  int countByType(UsbLogType type) {
    return logs.where((log) => log.type == type).length;
  }

  @override
  Widget build(BuildContext context) {
    final receivedCount = countByType(UsbLogType.received);
    final duplicateCount = countByType(UsbLogType.duplicate);
    final errorCount = logs.where((log) {
      return log.type == UsbLogType.error || log.type == UsbLogType.invalidJson;
    }).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('لاگ دریافت USB'),
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
                                  'از صفحه دریافت، اتصال USB را تست کن یا JSON دستی پردازش کن.',
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
                            (log) => UsbLogCard(log: log),
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



class UsbLogCard extends StatelessWidget {
  final UsbLog log;

  const UsbLogCard({
    super.key,
    required this.log,
  });

  Color get color {
    switch (log.type) {
      case UsbLogType.connected:
        return const Color(0xFF008B62);
      case UsbLogType.disconnected:
        return const Color(0xFF7B3FB3);
      case UsbLogType.received:
        return const Color(0xFF086EBB);
      case UsbLogType.duplicate:
        return const Color(0xFFE87500);
      case UsbLogType.invalidJson:
        return const Color(0xFFD32F2F);
      case UsbLogType.error:
        return const Color(0xFFD32F2F);
      case UsbLogType.info:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (log.type) {
      case UsbLogType.connected:
        return Icons.usb_rounded;
      case UsbLogType.disconnected:
        return Icons.usb_off_rounded;
      case UsbLogType.received:
        return Icons.check_circle_rounded;
      case UsbLogType.duplicate:
        return Icons.copy_rounded;
      case UsbLogType.invalidJson:
        return Icons.data_object_rounded;
      case UsbLogType.error:
        return Icons.error_rounded;
      case UsbLogType.info:
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
            backgroundColor: color.withOpacity(0.12),
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
            backgroundColor: color.withOpacity(0.12),
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
                    color: Colors.black.withOpacity(0.08),
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

class AlertSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const AlertSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: cardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 26,
              height: 1,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  final AppAlert alert;

  const AlertCard({super.key, required this.alert});

  Color get color {
    switch (alert.level) {
      case AlertLevel.urgent:
        return const Color(0xFFD32F2F);
      case AlertLevel.warning:
        return const Color(0xFFE87500);
      case AlertLevel.info:
        return const Color(0xFF086EBB);
    }
  }

  IconData get icon {
    switch (alert.type) {
      case AlertType.forbiddenZone:
        return Icons.warning_rounded;
      case AlertType.routeExit:
        return Icons.alt_route_rounded;
      case AlertType.missingTag:
        return Icons.sell_rounded;
      case AlertType.lowBattery:
        return Icons.battery_alert_rounded;
      case AlertType.syncFailed:
        return Icons.sync_problem_rounded;
      case AlertType.antennaError:
        return Icons.settings_input_antenna_rounded;
      case AlertType.tagUnlocked:
        return Icons.lock_open_rounded;
    }
  }

  String get levelText {
    switch (alert.level) {
      case AlertLevel.urgent:
        return 'فوری';
      case AlertLevel.warning:
        return 'هشدار';
      case AlertLevel.info:
        return 'اطلاع';
    }
  }

  String get typeText {
    switch (alert.type) {
      case AlertType.forbiddenZone:
        return 'محدوده ممنوع';
      case AlertType.routeExit:
        return 'خروج از مسیر';
      case AlertType.missingTag:
        return 'تگ مفقود';
      case AlertType.lowBattery:
        return 'باتری';
      case AlertType.syncFailed:
        return 'ارسال';
      case AlertType.antennaError:
        return 'دستگاه / GPS';
      case AlertType.tagUnlocked:
        return 'قفل تگ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(
                  icon,
                  color: color,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alert.subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                alert.time,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AlertBadge(
                icon: Icons.flag_rounded,
                text: levelText,
                color: color,
              ),
              AlertBadge(
                icon: Icons.category_rounded,
                text: typeText,
                color: const Color(0xFF7B3FB3),
              ),
              AlertBadge(
                icon: Icons.place_rounded,
                text: alert.locationName,
                color: const Color(0xFF086EBB),
              ),
              AlertBadge(
                icon: alert.reviewed
                    ? Icons.verified_rounded
                    : Icons.pending_actions_rounded,
                text: alert.reviewed ? 'اطلاع‌رسانی' : 'نیاز به بررسی',
                color: alert.reviewed ? Colors.green : Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class AlertBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const AlertBadge({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
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
            backgroundColor: color.withOpacity(0.12),
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
            backgroundColor: color.withOpacity(0.12),
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

class SmsReportSettingsPage extends StatefulWidget {
  const SmsReportSettingsPage({super.key});

  @override
  State<SmsReportSettingsPage> createState() => _SmsReportSettingsPageState();
}

class _SmsReportSettingsPageState extends State<SmsReportSettingsPage> {
  bool isLoading = true;
  bool isSendingTest = false;

  SmsReportSettings settings = const SmsReportSettings();

  final TextEditingController phoneController = TextEditingController();

  final List<int> intervalOptions = const [
    10,
    15,
    30,
    60,
  ];

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  Future<void> loadSettings() async {
    final loadedSettings = await SmsReportSettingsService.loadSettings();

    if (!mounted) return;

    setState(() {
      settings = loadedSettings;
      phoneController.text = loadedSettings.phoneNumber;
      isLoading = false;
    });
  }

  Future<void> saveSettings(SmsReportSettings newSettings) async {
    settings = newSettings.copyWith(
      phoneNumber: phoneController.text.trim(),
    );

    await SmsReportSettingsService.saveSettings(settings);
    await SmsAutoSenderService.restart();

    if (!mounted) return;

    setState(() {});
  }

  Future<void> saveAndShowMessage() async {
    await saveSettings(settings);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تنظیمات پیامک ذخیره شد.'),
      ),
    );
  }

  Future<void> sendTestSms() async {
    await saveSettings(settings);

    if (settings.phoneNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اول شماره مقصد را وارد کن.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSendingTest = true;
    });

    try {
      final message = await SmsReportBuilderService.buildCurrentMessage(
        settings,
      );

      await DirectSmsService.sendDirectSms(
        phoneNumber: settings.phoneNumber,
        message: message,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پیامک تستی ارسال شد.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در ارسال پیامک: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        isSendingTest = false;
      });
    }
  }

  Future<void> showPreviewMessage() async {
    await saveSettings(settings);

    final message = await SmsReportBuilderService.buildCurrentMessage(
      settings,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('پیش‌نمایش پیامک'),
          content: SingleChildScrollView(
            child: Text(
              message,
              textDirection: TextDirection.rtl,
              style: const TextStyle(height: 1.7),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: message),
                );

                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('متن پیامک کپی شد.'),
                  ),
                );
              },
              child: const Text('کپی متن'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('بستن'),
            ),
          ],
        );
      },
    );
  }

  Widget buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      activeColor: const Color(0xFF008B62),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(height: 1.5),
      ),
      onChanged: (value) async {
        onChanged(value);
        await saveSettings(settings);
      },
    );
  }

  Widget buildIntervalSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'فاصله ارسال خودکار'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: intervalOptions.map((minute) {
              final selected = settings.intervalMinutes == minute;

              return ChoiceChip(
                selected: selected,
                label: Text('هر $minute دقیقه'),
                selectedColor: const Color(0xFFEAF8F2),
                onSelected: (_) async {
                  setState(() {
                    settings = settings.copyWith(
                      intervalMinutes: minute,
                    );
                  });

                  await saveSettings(settings);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          const Text(
            'ارسال خودکار فعلاً وقتی برنامه باز است فعال می‌ماند.',
            style: TextStyle(
              color: Colors.black54,
              height: 1.6,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatusBox() {
    return ValueListenableBuilder<String>(
      valueListenable: SmsAutoSenderService.statusNotifier,
      builder: (context, status, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: settings.enabled
                ? const Color(0xFFEAF8F2)
                : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: settings.enabled
                  ? const Color(0xFFC8EBDD)
                  : const Color(0xFFFFCC80),
            ),
          ),
          child: Row(
            children: [
              Icon(
                settings.enabled
                    ? Icons.sms_rounded
                    : Icons.sms_failed_rounded,
                color: settings.enabled
                    ? const Color(0xFF008B62)
                    : const Color(0xFFE87500),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildContentOptions() {
    return Container(
      width: double.infinity,
      decoration: cardDecoration(),
      child: Column(
        children: [
          const SectionTitle(title: 'محتوای پیامک'),
          buildSwitchTile(
            title: 'تاریخ گزارش',
            subtitle: 'نمایش روز و تاریخ در متن پیامک',
            value: settings.includeDate,
            onChanged: (value) {
              setState(() {
                settings = settings.copyWith(includeDate: value);
              });
            },
          ),
          buildSwitchTile(
            title: 'تعداد شترهای دیده‌شده',
            subtitle: 'تعداد تگ‌هایی که امروز دریافت شده‌اند',
            value: settings.includeSeenCount,
            onChanged: (value) {
              setState(() {
                settings = settings.copyWith(includeSeenCount: value);
              });
            },
          ),
          buildSwitchTile(
            title: 'تعداد شترهای دیده‌نشده',
            subtitle: 'شترهای فعال که امروز رکوردی نداشته‌اند',
            value: settings.includeMissingCount,
            onChanged: (value) {
              setState(() {
                settings = settings.copyWith(includeMissingCount: value);
              });
            },
          ),
          buildSwitchTile(
            title: 'داخل محدوده مجاز',
            subtitle: 'شترهای دیده‌شده داخل آغل، چراگاه، مسیر یا آبشخور',
            value: settings.includeInsideAllowedCount,
            onChanged: (value) {
              setState(() {
                settings = settings.copyWith(includeInsideAllowedCount: value);
              });
            },
          ),
          buildSwitchTile(
            title: 'خارج یا غیرمجاز',
            subtitle: 'شترهای خارج از محدوده مجاز یا داخل محدوده ممنوع',
            value: settings.includeOutsideAllowedCount,
            onChanged: (value) {
              setState(() {
                settings = settings.copyWith(includeOutsideAllowedCount: value);
              });
            },
          ),
          buildSwitchTile(
            title: 'باتری ضعیف',
            subtitle: 'تعداد شترهایی که باتری تگ آن‌ها ضعیف است',
            value: settings.includeLowBatteryCount,
            onChanged: (value) {
              setState(() {
                settings = settings.copyWith(includeLowBatteryCount: value);
              });
            },
          ),
          buildSwitchTile(
            title: 'آخرین زمان دریافت',
            subtitle: 'آخرین ساعت دریافت رکورد امروز',
            value: settings.includeLastReceiveTime,
            onChanged: (value) {
              setState(() {
                settings = settings.copyWith(includeLastReceiveTime: value);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget buildMainSettings() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        children: [
          SwitchListTile(
            value: settings.enabled,
            activeColor: const Color(0xFF008B62),
            title: const Text(
              'ارسال خودکار پیامک',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'با فعال‌سازی، برنامه طبق تایمر تنظیم‌شده پیامک گزارش ارسال می‌کند.',
              style: TextStyle(height: 1.5),
            ),
            onChanged: (value) async {
              setState(() {
                settings = settings.copyWith(enabled: value);
              });

              await saveSettings(settings);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'شماره مقصد پیامک',
              hintText: 'مثلاً 09123456789',
              prefixIcon: const Icon(Icons.phone_rounded),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              settings = settings.copyWith(
                phoneNumber: value.trim(),
              );
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: settings.sendOnlyIfHasProblem,
            activeColor: const Color(0xFF008B62),
            title: const Text(
              'ارسال فقط در صورت وجود مشکل',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'مثلاً شتر دیده‌نشده، خارج محدوده یا باتری ضعیف',
              style: TextStyle(height: 1.5),
            ),
            onChanged: (value) async {
              setState(() {
                settings = settings.copyWith(
                  sendOnlyIfHasProblem: value,
                );
              });

              await saveSettings(settings);
            },
          ),
        ],
      ),
    );
  }

  Widget buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: saveAndShowMessage,
            icon: const Icon(Icons.save_rounded),
            label: const Text('ذخیره تنظیمات'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003B7A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: showPreviewMessage,
                icon: const Icon(Icons.remove_red_eye_rounded),
                label: const Text('پیش‌نمایش'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isSendingTest ? null : sendTestSms,
                icon: isSendingTest
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('ارسال تستی'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008B62),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Column(
          children: [
            const AppHeader(title: 'تنظیمات پیامک'),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          buildStatusBox(),
                          const SizedBox(height: 12),
                          buildMainSettings(),
                          const SizedBox(height: 12),
                          buildIntervalSelector(),
                          const SizedBox(height: 12),
                          buildContentOptions(),
                          const SizedBox(height: 14),
                          buildActionButtons(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
