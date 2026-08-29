import 'dart:async';

import 'package:flutter/material.dart';

import '../models/live_herd_settings.dart';
import '../models/live_herd_status.dart';
import '../services/live_herd_settings_service.dart';
import '../services/live_herd_status_service.dart';
import '../services/live_herd_session_service.dart';


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

  Widget buildCamelCard(LiveCamelStatus camel) {
    final color = levelColor(camel.level);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(
              levelIcon(camel.level),
              color: color,
            ),
          ),
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
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

  Widget buildLiveTab(LiveHerdStatus status) {
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
          childAspectRatio: 1.05,
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
        const Text(
          'وضعیت شترها',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF062C5E),
          ),
        ),
        const SizedBox(height: 10),
        ...status.camels.map(buildCamelCard),
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