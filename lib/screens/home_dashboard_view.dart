import 'package:flutter/material.dart';

import '../models/tag_record.dart';

class HomeDashboardView extends StatelessWidget {
  final bool isLoading;
  final int totalTags;
  final int lowBatteryCount;
  final int queuedCount;
  final String lastReceiveText;
  final List<TagRecord> recentRecords;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenHerd;
  final VoidCallback onOpenManagementReport;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenCamelDashboard;
  final VoidCallback onOpenRecords;
  final VoidCallback onOpenSettings;

  const HomeDashboardView({
    super.key,
    required this.isLoading,
    required this.totalTags,
    required this.lowBatteryCount,
    required this.queuedCount,
    required this.lastReceiveText,
    required this.recentRecords,
    required this.onRefresh,
    required this.onOpenHerd,
    required this.onOpenManagementReport,
    required this.onOpenMap,
    required this.onOpenCamelDashboard,
    required this.onOpenRecords,
    required this.onOpenSettings,
  });

  static const _ink = Color(0xFF26221F);
  static const _muted = Color(0xFF827A73);
  static const _accent = Color(0xFFB85C2D);
  static const _green = Color(0xFF2F8B65);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _accent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        children: [
          _buildHeader(context),
          const SizedBox(height: 14),
          _HeroBanner(onTap: onOpenHerd),
          const SizedBox(height: 18),
          const _SectionHeader(title: 'دسترسی سریع'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: .78,
            children: [
              _QuickAction(
                title: 'گله',
                icon: Icons.pets_rounded,
                foreground: const Color(0xFF9B4D22),
                background: const Color(0xFFFFF0E5),
                onTap: onOpenHerd,
              ),
              _QuickAction(
                title: 'گزارش',
                icon: Icons.bar_chart_rounded,
                foreground: const Color(0xFF297D5D),
                background: const Color(0xFFE9F7F0),
                onTap: onOpenManagementReport,
              ),
              _QuickAction(
                title: 'نقشه',
                icon: Icons.map_rounded,
                foreground: const Color(0xFF2C6DB3),
                background: const Color(0xFFEAF3FF),
                onTap: onOpenMap,
              ),
              _QuickAction(
                title: 'داشبورد شتر',
                icon: Icons.badge_rounded,
                foreground: const Color(0xFF6B55A8),
                background: const Color(0xFFF1EDFF),
                onTap: onOpenCamelDashboard,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SmallAction(
                  title: 'رکوردها',
                  icon: Icons.receipt_long_rounded,
                  onTap: onOpenRecords,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallAction(
                  title: 'تنظیمات',
                  icon: Icons.tune_rounded,
                  onTap: onOpenSettings,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionHeader(title: 'خلاصه امروز'),
          const SizedBox(height: 10),
          isLoading
              ? const _LoadingSummary()
              : Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        value: '$totalTags',
                        label: 'شتر دیده‌شده',
                        icon: Icons.pets_rounded,
                        tint: const Color(0xFFEAF6F0),
                        foreground: _green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Metric(
                        value: '$lowBatteryCount',
                        label: 'باتری ضعیف',
                        icon: Icons.battery_alert_rounded,
                        tint: const Color(0xFFFFF2E4),
                        foreground: const Color(0xFFD67A18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Metric(
                        value: '$queuedCount',
                        label: 'ارسال‌نشده',
                        icon: Icons.cloud_upload_rounded,
                        tint: const Color(0xFFFFEDEE),
                        foreground: const Color(0xFFC85454),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Metric(
                        value: lastReceiveText,
                        label: 'آخرین دریافت',
                        icon: Icons.schedule_rounded,
                        tint: const Color(0xFFF1EDFF),
                        foreground: const Color(0xFF735CB6),
                      ),
                    ),
                  ],
                ),
          if (recentRecords.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionHeader(title: 'آخرین دریافت‌ها'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFF0E8E1)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7A3D1E).withValues(alpha: .07),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (int i = 0; i < recentRecords.length; i++) ...[
                    _RecentRecordRow(record: recentRecords[i]),
                    if (i != recentRecords.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE6D4),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: .12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.pets_rounded, color: _accent),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مدیریت هوشمند گله',
                style: TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'وضعیت امروز در یک نگاه',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _HeaderIcon(icon: Icons.tune_rounded, onTap: onOpenSettings),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 175,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7D3A19).withValues(alpha: .14),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/camel_hero.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.centerLeft,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Color(0xF2F8D6B7),
                  Color(0xC8EEBA85),
                  Color(0x25000000),
                ],
                stops: [0, .52, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 205,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'گله، همیشه زیر نظر',
                      style: TextStyle(
                        color: Color(0xFF48200F),
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'مشاهده وضعیت زنده شترها',
                      style: TextStyle(
                        color: Color(0xFF70432C),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 13),
                    FilledButton.icon(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF9F4D24),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 17),
                      label: const Text(
                        'ورود به گله',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  const _QuickAction({
    required this.title,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .72),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: foreground, size: 25),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF302B27),
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _SmallAction({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFF7F2EE),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 21, color: const Color(0xFF7B5C4C)),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6C625C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color tint;
  final Color foreground;

  const _Metric({
    required this.value,
    required this.label,
    required this.icon,
    required this.tint,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                color: foreground,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF716A65),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRecordRow extends StatelessWidget {
  final TagRecord record;
  const _RecentRecordRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final attached = record.isAttachedToCamel;
    final name = record.camelName.trim().isNotEmpty && record.camelName != 'شتر ثبت‌نشده'
        ? record.camelName
        : 'شتر ${record.camelNo}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF0E5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pets_rounded, color: Color(0xFFA65028)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF332D29),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  record.tagId,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: Color(0xFF938B85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: attached ? const Color(0xFFE8F7EF) : const Color(0xFFFFEEEE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  attached ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 13,
                  color: attached ? const Color(0xFF27845E) : const Color(0xFFC44E4E),
                ),
                const SizedBox(width: 4),
                Text(
                  attached ? 'قفل' : 'باز',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: attached ? const Color(0xFF27845E) : const Color(0xFFC44E4E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Text(
            record.receivedTime,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: Color(0xFF817A75),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF2D2825),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: Color(0xFFF0E7E0))),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFF0E8E1)),
          ),
          child: Icon(icon, color: const Color(0xFF625B56), size: 21),
        ),
      ),
    );
  }
}

class _LoadingSummary extends StatelessWidget {
  const _LoadingSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2EE),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.6, color: Color(0xFFB85C2D)),
      ),
    );
  }
}
