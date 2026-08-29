import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import '../models/live_herd_settings.dart';
import '../models/live_herd_status.dart';
import '../services/live_herd_settings_service.dart';
import '../services/live_herd_status_service.dart';
import '../services/live_herd_session_service.dart';
import '../models/camel_detail.dart';
import '../services/camel_detail_service.dart';
import 'camel_detail_info_page.dart';


class LiveHerdPage extends StatefulWidget {
  const LiveHerdPage({super.key});

  @override
  State<LiveHerdPage> createState() => _LiveHerdPageState();
}

class _LiveHerdPageState extends State<LiveHerdPage> {
  DateTime sessionStartTime = DateTime.now();

  LiveHerdSettings settings = const LiveHerdSettings();
  LiveHerdStatus? status;

Timer? autoRefreshTimer;
  VoidCallback? sessionListener;

  bool isLoading = true;
  bool isRefreshing = false;
  final TextEditingController liveSearchController =
      TextEditingController();

  String selectedLiveFilter = 'all';

 @override
 void initState() {
   super.initState();

   sessionListener = () {
     final startedAt = LiveHerdSessionService.sessionStartTime;

     if (startedAt == null) return;
     if (!mounted) return;

     if (startedAt.isAtSameMomentAs(sessionStartTime)) {
       return;
     }

     setState(() {
       sessionStartTime = startedAt;
       status = null;
       isLoading = true;
     });

     refreshStatus();
   };

   LiveHerdSessionService.sessionStartNotifier.addListener(
     sessionListener!,
   );

   initializePage();
 }

@override
void dispose() {
  autoRefreshTimer?.cancel();

  if (sessionListener != null) {
    LiveHerdSessionService.sessionStartNotifier.removeListener(
      sessionListener!,
    );
  }
liveSearchController.dispose();
  super.dispose();
}



  Future<void> initializePage() async {
    final loadedSettings = await LiveHerdSettingsService.loadSettings();

    final startedAt = await LiveHerdSessionService.ensureSession();

    if (!mounted) return;

    setState(() {
      settings = loadedSettings;
      sessionStartTime = startedAt;
    });

    startTimers();
    await refreshStatus();
  }

 void startTimers() {
   autoRefreshTimer?.cancel();

   final refreshMinutes =
       settings.seenRefreshMinutes <= 0 ? 1 : settings.seenRefreshMinutes;

   autoRefreshTimer = Timer.periodic(
     Duration(minutes: refreshMinutes),
     (_) async {
       if (!mounted) return;
       if (isRefreshing) return;

       await refreshStatus();
     },
   );
 }



  Future<void> refreshStatus() async {
    if (isRefreshing) return;
    debugPrint('Live herd auto refresh: ${DateTime.now()}');

    setState(() {
      isRefreshing = true;
    });

    try {
      final nextStatus = await LiveHerdStatusService.buildStatus(
        sessionStartTime: sessionStartTime,
        settings: settings,
      );

      if (!mounted) return;

      setState(() {
        status = nextStatus;
        isLoading = false;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isRefreshing = false;
      });
    }
  }

 Future<void> startNewSession() async {
   final startedAt = await LiveHerdSessionService.startSession(
     reset: true,
   );

   if (!mounted) return;

   setState(() {
     sessionStartTime = startedAt;
     status = null;
     isLoading = true;
   });

   await refreshStatus();
 }

  String twoDigit(int value) {
    return value.toString().padLeft(2, '0');
  }

  String timeText(DateTime date) {
    return '${twoDigit(date.hour)}:${twoDigit(date.minute)}';
  }

  Color levelColor(LiveCamelLevel level) {
    switch (level) {
      case LiveCamelLevel.normal:
        return const Color(0xFF008B62);
      case LiveCamelLevel.warning:
        return const Color(0xFFE87500);
      case LiveCamelLevel.danger:
        return const Color(0xFFD32F2F);
      case LiveCamelLevel.unseen:
        return Colors.grey;
    }
  }

  IconData levelIcon(LiveCamelLevel level) {
    switch (level) {
      case LiveCamelLevel.normal:
        return Icons.check_circle_rounded;
      case LiveCamelLevel.warning:
        return Icons.error_rounded;
      case LiveCamelLevel.danger:
        return Icons.warning_rounded;
      case LiveCamelLevel.unseen:
        return Icons.visibility_off_rounded;
    }
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

 Widget buildStatCard({
   required String title,
   required String value,
   required IconData icon,
   required Color color,
 }) {
   return Container(
     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
     decoration: cardDecoration(),
     child: Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
         CircleAvatar(
           radius: 22,
           backgroundColor: color.withOpacity(0.12),
           child: Icon(icon, color: color),
         ),
         const SizedBox(height: 10),
         Text(
           value,
           maxLines: 1,
           overflow: TextOverflow.ellipsis,
           style: TextStyle(
             fontSize: 24,
             fontWeight: FontWeight.bold,
             color: color,
           ),
         ),
         const SizedBox(height: 6),
         Text(
           title,
           maxLines: 2,
           textAlign: TextAlign.center,
           overflow: TextOverflow.ellipsis,
           style: const TextStyle(
             fontSize: 13,
             color: Colors.black54,
             fontWeight: FontWeight.bold,
             height: 1.4,
           ),
         ),
       ],
     ),
   );
 }

  Widget buildTopStatus(LiveHerdStatus status) {
    final hasProblem = status.hasProblem;
    final color = hasProblem ? const Color(0xFFE87500) : const Color(0xFF008B62);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(
                  hasProblem
                      ? Icons.warning_rounded
                      : Icons.check_circle_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasProblem ? 'گله نیازمند بررسی است' : 'وضعیت گله عادی است',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
              if (isRefreshing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'شروع جلسه: ${timeText(sessionStartTime)}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            'آخرین دریافت: ${status.lastRecordText}',
            style: const TextStyle(color: Colors.black54),
          ),
          if (status.antennaSilent) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'دریافت آنتن مدتی است داده جدیدی ثبت نکرده است.',
                style: TextStyle(
                  color: Color(0xFFD32F2F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }



  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void showCamelPhoto(LiveCamelStatus camel) {
    if (!camel.hasPhoto) {
      showMessage('برای این شتر هنوز عکسی ثبت نشده است.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            insetPadding: const EdgeInsets.all(18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    color: const Color(0xFF062C5E),
                    child: Text(
                      camel.camelName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  InteractiveViewer(
                    child: Image.file(
                      File(camel.photoPath),
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'فایل عکس پیدا نشد یا قابل نمایش نیست.',
                            style: TextStyle(
                              color: Color(0xFFD32F2F),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('بستن'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Future<void> openCamelInfo(
    LiveCamelStatus camel,
  ) async {
    final detail =
        await CamelDetailService.getDetailByTagId(camel.tagId) ??
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

  Widget buildCamelAvatar(
    LiveCamelStatus camel,
    Color color,
  ) {
    return GestureDetector(
      onTap: () {
        showCamelPhoto(camel);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: color,
                width: 2.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.20),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: camel.hasPhoto
                  ? Image.file(
                      File(camel.photoPath),
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return buildDefaultAvatar(color);
                      },
                    )
                  : buildDefaultAvatar(color),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDefaultAvatar(Color color) {
    return Container(
      color: color.withOpacity(0.10),
      child: Icon(
        Icons.pets_rounded,
        color: color,
        size: 28,
      ),
    );
  }

  Widget buildCamelCard(LiveCamelStatus camel) {
    final color = levelColor(camel.level);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildCamelAvatar(camel, color),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  camel.camelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${camel.tagId} / شماره ${camel.camelNo}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'آخرین مشاهده: ${camel.lastSeenText}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'آخرین محل دریافت: ${camel.lastLocationText}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      openCamelInfo(camel);
                    },
                    icon: const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'اطلاعات',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              camel.statusText,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool camelMatchesSearch(
    LiveCamelStatus camel,
  ) {
    final query = liveSearchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return true;
    }

    return camel.camelName.toLowerCase().contains(query) ||
        camel.camelNo.toLowerCase().contains(query) ||
        camel.tagId.toLowerCase().contains(query) ||
        camel.statusText.toLowerCase().contains(query) ||
        camel.lastLocationText.toLowerCase().contains(query);
  }

  bool camelMatchesFilter(
    LiveCamelStatus camel,
  ) {
    switch (selectedLiveFilter) {
      case 'normal':
        return camel.level == LiveCamelLevel.normal;

      case 'warning':
        return camel.level == LiveCamelLevel.warning;

      case 'danger':
        return camel.level == LiveCamelLevel.danger;

      case 'missing':
        return camel.missing ||
            camel.criticalMissing ||
            camel.level == LiveCamelLevel.unseen;

      case 'battery':
        return camel.lowBattery;

      case 'all':
      default:
        return true;
    }
  }

  List<LiveCamelStatus> visibleLiveCamels(
    LiveHerdStatus status,
  ) {
    return status.camels.where((camel) {
      return camelMatchesSearch(camel) &&
          camelMatchesFilter(camel);
    }).toList();
  }

  Widget buildFilterChip({
    required String title,
    required String value,
    required int count,
  }) {
    final selected = selectedLiveFilter == value;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text('$title $count'),
        selectedColor: const Color(0xFF086EBB),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        side: BorderSide(
          color: selected
              ? const Color(0xFF086EBB)
              : const Color(0xFFE5E7EB),
        ),
        onSelected: (_) {
          setState(() {
            selectedLiveFilter = value;
          });
        },
      ),
    );
  }

  Widget buildSearchAndFilters(
    LiveHerdStatus status,
  ) {
    final normalCount = status.camels.where((camel) {
      return camel.level == LiveCamelLevel.normal;
    }).length;

    final warningCount = status.camels.where((camel) {
      return camel.level == LiveCamelLevel.warning;
    }).length;

    final dangerCount = status.camels.where((camel) {
      return camel.level == LiveCamelLevel.danger;
    }).length;

    final missingCount = status.camels.where((camel) {
      return camel.missing ||
          camel.criticalMissing ||
          camel.level == LiveCamelLevel.unseen;
    }).length;

    final batteryCount = status.camels.where((camel) {
      return camel.lowBattery;
    }).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: liveSearchController,
            onChanged: (_) {
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'جستجو با نام، شماره، تگ یا محل دریافت',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: liveSearchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        setState(() {
                          liveSearchController.clear();
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              children: [
                buildFilterChip(
                  title: 'همه',
                  value: 'all',
                  count: status.camels.length,
                ),
                buildFilterChip(
                  title: 'عادی',
                  value: 'normal',
                  count: normalCount,
                ),
                buildFilterChip(
                  title: 'نیاز بررسی',
                  value: 'warning',
                  count: warningCount,
                ),
                buildFilterChip(
                  title: 'خطر',
                  value: 'danger',
                  count: dangerCount,
                ),
                buildFilterChip(
                  title: 'ندیده',
                  value: 'missing',
                  count: missingCount,
                ),
                buildFilterChip(
                  title: 'باتری',
                  value: 'battery',
                  count: batteryCount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

 Widget buildLiveTab(LiveHerdStatus status) {
   final visibleCamels = visibleLiveCamels(status);

   return ListView(
     padding: const EdgeInsets.all(14),
     children: [
       buildTopStatus(status),

       const SizedBox(height: 14),

       GridView.count(
         crossAxisCount: 2,
         shrinkWrap: true,
         physics: const NeverScrollableScrollPhysics(),
         mainAxisSpacing: 10,
         crossAxisSpacing: 10,
         childAspectRatio: 1.15,
         children: [
           buildStatCard(
             title: 'دیده‌شده',
             value: '${status.seenInSessionCount}/${status.totalCamelCount}',
             icon: Icons.visibility_rounded,
             color: const Color(0xFF008B62),
           ),
           buildStatCard(
             title: 'فعال الآن',
             value: status.seenRecentlyCount.toString(),
             icon: Icons.update_rounded,
             color: const Color(0xFF086EBB),
           ),
           buildStatCard(
             title: 'ندیده',
             value: status.missingCount.toString(),
             icon: Icons.visibility_off_rounded,
             color: const Color(0xFFE87500),
           ),
           buildStatCard(
             title: 'خطر',
             value: status.dangerCount.toString(),
             icon: Icons.warning_rounded,
             color: const Color(0xFFD32F2F),
           ),
         ],
       ),

       const SizedBox(height: 14),

       buildSearchAndFilters(status),

       const SizedBox(height: 14),

       Row(
         children: [
           const Expanded(
             child: Text(
               'وضعیت شترها',
               style: TextStyle(
                 fontWeight: FontWeight.bold,
                 fontSize: 16,
                 color: Color(0xFF062C5E),
               ),
             ),
           ),
           Text(
             '${visibleCamels.length} مورد',
             style: const TextStyle(
               color: Colors.black54,
               fontWeight: FontWeight.bold,
             ),
           ),
         ],
       ),

       const SizedBox(height: 10),

       if (visibleCamels.isEmpty)
         Container(
           width: double.infinity,
           padding: const EdgeInsets.all(18),
           decoration: cardDecoration(),
           child: const Text(
             'موردی با این جستجو یا فیلتر پیدا نشد.',
             textAlign: TextAlign.center,
             style: TextStyle(
               color: Colors.black54,
               fontWeight: FontWeight.bold,
             ),
           ),
         )
       else
         ...visibleCamels.map(buildCamelCard),

       const SizedBox(height: 30),
     ],
   );
 }
  Widget buildProblemsTab(LiveHerdStatus status) {
    final problems = status.liveProblems;

    if (problems.isEmpty && !status.antennaSilent) {
      return const Center(
        child: Text(
          'در این لحظه خطایی وجود ندارد.',
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (status.antennaSilent)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'دریافت آنتن متوقف یا کند شده است.',
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ...problems.map(buildCamelCard),
      ],
    );
  }

  Widget buildMissingTab(LiveHerdStatus status) {
    final missing = status.missingCamels;

    if (missing.isEmpty) {
      return const Center(
        child: Text(
          'فعلاً شتر دیده‌نشده‌ای وجود ندارد.',
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'بعد از ${settings.missingAfterMinutes} دقیقه از شروع جلسه، شترهای ثبت‌شده‌ای که هنوز خوانده نشده‌اند اینجا نمایش داده می‌شوند.',
            style: const TextStyle(
              color: Color(0xFF8A4B00),
              height: 1.6,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...missing.map(buildCamelCard),
      ],
    );
  }

  Future<void> showSettingsDialog() async {
    final seenController = TextEditingController(
      text: settings.seenRefreshMinutes.toString(),
    );

    final missingCheckController = TextEditingController(
      text: settings.missingCheckMinutes.toString(),
    );

    final missingAfterController = TextEditingController(
      text: settings.missingAfterMinutes.toString(),
    );

    final criticalController = TextEditingController(
      text: settings.criticalMissingAfterMinutes.toString(),
    );

    final recentController = TextEditingController(
      text: settings.recentSeenMinutes.toString(),
    );

    final antennaController = TextEditingController(
      text: settings.antennaSilentMinutes.toString(),
    );

    int parse(TextEditingController controller, int fallback) {
      return int.tryParse(controller.text.trim()) ?? fallback;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تنظیمات گزارش زنده'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                buildDialogNumberField(
                  title: 'آپدیت دیده‌شده‌ها هر چند دقیقه؟',
                  controller: seenController,
                ),
                buildDialogNumberField(
                  title: 'بررسی دیده‌نشده‌ها هر چند دقیقه؟',
                  controller: missingCheckController,
                ),
                buildDialogNumberField(
                  title: 'بعد از چند دقیقه دیده‌نشده حساب شود؟',
                  controller: missingAfterController,
                ),
                buildDialogNumberField(
                  title: 'بعد از چند دقیقه خطر فوری شود؟',
                  controller: criticalController,
                ),
                buildDialogNumberField(
                  title: 'دیده‌شده اخیر یعنی چند دقیقه اخیر؟',
                  controller: recentController,
                ),
                buildDialogNumberField(
                  title: 'قطع دریافت آنتن بعد از چند دقیقه؟',
                  controller: antennaController,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nextSettings = settings.copyWith(
                  seenRefreshMinutes: parse(seenController, 1).clamp(1, 999),
                  missingCheckMinutes:
                      parse(missingCheckController, 5).clamp(1, 999),
                  missingAfterMinutes:
                      parse(missingAfterController, 5).clamp(1, 999),
                  criticalMissingAfterMinutes:
                      parse(criticalController, 15).clamp(1, 999),
                  recentSeenMinutes: parse(recentController, 3).clamp(1, 999),
                  antennaSilentMinutes:
                      parse(antennaController, 10).clamp(1, 999),
                );

                await LiveHerdSettingsService.saveSettings(nextSettings);

                if (!mounted) return;

                setState(() {
                  settings = nextSettings;
                });

                startTimers();
                await refreshStatus();

                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('ذخیره'),
            ),
          ],
        );
      },
    );

    seenController.dispose();
    missingCheckController.dispose();
    missingAfterController.dispose();
    criticalController.dispose();
    recentController.dispose();
    antennaController.dispose();
  }

  Widget buildDialogNumberField({
    required String title,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: title,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = status;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text('وضعیت زنده گله'),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: refreshStatus,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                onPressed: showSettingsDialog,
                icon: const Icon(Icons.tune_rounded),
              ),
              IconButton(
                onPressed: startNewSession,
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'نمای کلی'),
                Tab(text: 'موارد مهم'),
                Tab(text: 'ندیده‌ها'),
              ],
            ),
          ),
          body: isLoading || currentStatus == null
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    buildLiveTab(currentStatus),
                    buildProblemsTab(currentStatus),
                    buildMissingTab(currentStatus),
                  ],
                ),
        ),
      ),
    );
  }
}