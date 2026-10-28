import 'dart:io';

import 'package:flutter/material.dart';

import '../models/tag_record.dart';
import '../services/map_herd_status.dart';

const _terracotta = Color(0xFFAE5B32);
const _ink = Color(0xFF28312F);

enum MapCamelFilter { all, inside, outside, lowBattery }

class MapWarmHeader extends StatelessWidget {
  final VoidCallback? onBack;
  const MapWarmHeader({super.key, this.onBack});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFA65A35), Color(0xFF7D3C28)],
        begin: Alignment.topRight, end: Alignment.bottomLeft,
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
        child: Row(children: [
          if (onBack != null) ...[
            IconButton(
              tooltip: 'بازگشت',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ),
            const SizedBox(width: 4),
          ],
          const Icon(Icons.map_outlined, color: Colors.white, size: 25),
          const SizedBox(width: 9),
          const Text('نقشه', style: TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('ردیابی گله', style: TextStyle(color: Colors.white.withValues(alpha: .83))),
        ]),
      ),
    ),
  );
}

class MapHeroBanner extends StatelessWidget {
  const MapHeroBanner({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 142,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(23),
      boxShadow: [BoxShadow(color: _terracotta.withValues(alpha: .1), blurRadius: 15)]),
    child: Stack(fit: StackFit.expand, children: [
      Image.asset('assets/images/camel_hero.jpg', fit: BoxFit.cover),
      Container(decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.centerRight, end: Alignment.centerLeft,
        colors: [Color(0xF9FFE4C8), Color(0xC8F8D7B7), Color(0x00663D27)],
        stops: [0, .52, 1],
      ))),
      Positioned(right: 18, top: 21, left: 85, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('نقشه هوشمند گله', style: TextStyle(fontSize: 19,
            fontWeight: FontWeight.w900, color: Color(0xFF532D1E))),
          SizedBox(height: 9),
          Text('شترها و محدوده‌های تعریف‌شده،\nدر یک نگاه',
            style: TextStyle(fontSize: 12, height: 1.7, color: Color(0xFF734935))),
        ],
      )),
      const Positioned(left: 16, bottom: 14,
        child: Icon(Icons.location_on_rounded, color: Colors.white, size: 32)),
    ]),
  );
}

class MapStatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color tint;
  final Color foreground;
  const MapStatCard({super.key, required this.label, required this.count,
    required this.icon, required this.tint, required this.foreground});
  @override
  Widget build(BuildContext context) => Container(
    height: 104,
    decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(20)),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: foreground, size: 23),
      const SizedBox(height: 5),
      Text('$count', style: TextStyle(color: foreground,
        fontSize: 23, fontWeight: FontWeight.w900, height: 1)),
      const SizedBox(height: 5),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: _ink, fontWeight: FontWeight.bold)),
    ]),
  );
}

class MapSectionTitle extends StatelessWidget {
  final String title;
  const MapSectionTitle(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Text(title, style: const TextStyle(
    fontSize: 15, fontWeight: FontWeight.w800, color: _ink));
}

class MapZoneActionData {
  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() action;
  const MapZoneActionData(this.label, this.icon, this.color, this.action);
}

class MapZoneActionCard extends StatelessWidget {
  final MapZoneActionData data;
  final Future<void> Function() onCompleted;
  const MapZoneActionCard({super.key, required this.data, required this.onCompleted});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 119,
    child: Material(
      color: Colors.white, borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () async {
          await data.action();
          await onCompleted();
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: data.color.withValues(alpha: .16)),
            borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.all(9),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircleAvatar(backgroundColor: data.color.withValues(alpha: .09), radius: 22,
              child: Icon(data.icon, color: data.color, size: 23)),
            const SizedBox(height: 8),
            Text(data.label, maxLines: 2, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    ),
  );
}

class MapSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const MapSearchField({super.key, required this.controller, required this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      filled: true, fillColor: Colors.white,
      hintText: 'نام، شماره شتر یا شناسه تگ...',
      hintStyle: const TextStyle(color: Colors.black45, fontSize: 12),
      prefixIcon: const Icon(Icons.search_rounded, color: _terracotta),
      suffixIcon: controller.text.isNotEmpty
        ? IconButton(icon: const Icon(Icons.close_rounded),
            onPressed: () { controller.clear(); onChanged(''); }) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    ),
  );
}

class MapFilterChips extends StatelessWidget {
  final MapCamelFilter selected;
  final ValueChanged<MapCamelFilter> onSelected;
  const MapFilterChips({super.key, required this.selected, required this.onSelected});
  @override
  Widget build(BuildContext context) {
    const filters = [
      (MapCamelFilter.all, 'همه', Icons.grid_view_rounded),
      (MapCamelFilter.inside, 'داخل محدوده', Icons.check_circle_outline_rounded),
      (MapCamelFilter.outside, 'خارج محدوده', Icons.error_outline_rounded),
      (MapCamelFilter.lowBattery, 'باتری ضعیف', Icons.battery_alert_rounded),
    ];
    return SizedBox(height: 40, child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: filters.length,
      separatorBuilder: (_, __) => const SizedBox(width: 7),
      itemBuilder: (context, i) {
        final filter = filters[i];
        final isSelected = selected == filter.$1;
        return ChoiceChip(
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          label: Text(filter.$2, style: const TextStyle(fontSize: 11)),
          avatar: Icon(filter.$3, size: 16,
            color: isSelected ? _terracotta : Colors.black45),
          showCheckmark: false,
          selected: isSelected,
          selectedColor: const Color(0xFFFDE1D0),
          backgroundColor: Colors.white,
          side: BorderSide(color: isSelected ? _terracotta : const Color(0xFFEAE4DF)),
          onSelected: (_) => onSelected(filter.$1),
        );
      },
    ));
  }
}

class MapCamelPhoto extends StatelessWidget {
  final String? photoPath;
  final double size;
  const MapCamelPhoto({super.key, this.photoPath, this.size = 53});
  @override
  Widget build(BuildContext context) {
    final path = photoPath?.trim();
    final canShow = path != null && path.isNotEmpty && File(path).existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .3),
      child: Container(
        width: size, height: size, color: const Color(0xFFFFEAD9),
        child: canShow
          ? Image.file(File(path), fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.pets_rounded, color: _terracotta))
          : const Icon(Icons.pets_rounded, color: _terracotta),
      ),
    );
  }
}

class MapCamelAvatar extends StatelessWidget {
  final String name;
  final String? photoPath;
  final bool selected;
  final VoidCallback onTap;
  const MapCamelAvatar({super.key, required this.name, required this.photoPath,
    required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(width: 85, child: Column(children: [
      Container(padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: selected ? _terracotta : const Color(0xFFF2D7C6), width: 2)),
        child: ClipOval(child: MapCamelPhoto(photoPath: photoPath, size: 55))),
      const SizedBox(height: 4),
      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
    ])));
}

class MapModeSwitch extends StatelessWidget {
  final bool online;
  final ValueChanged<bool> onChanged;
  const MapModeSwitch({super.key, required this.online, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: const Color(0xFFF5E9E0),
      borderRadius: BorderRadius.circular(22)),
    padding: const EdgeInsets.all(3),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _option('آفلاین', !online, () => onChanged(false)),
      _option('آنلاین', online, () => onChanged(true)),
    ]),
  );
  Widget _option(String label, bool chosen, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(17), onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: chosen ? _terracotta : Colors.transparent,
        borderRadius: BorderRadius.circular(17)),
      child: Text(label, style: TextStyle(fontSize: 10,
        color: chosen ? Colors.white : _ink, fontWeight: FontWeight.w800)),
    ),
  );
}

class MapCompactCamelCard extends StatefulWidget {
  final TagRecord record;
  final String title;
  final String? photoPath;
  final MapBoundaryState boundary;
  final String zoneDescription;
  final String dateText;
  final VoidCallback onShowOnMap;
  final VoidCallback onRoute;
  final bool routeActive;
  const MapCompactCamelCard({super.key, required this.record, required this.title,
    required this.photoPath, required this.boundary,
    required this.zoneDescription, required this.dateText,
    required this.onShowOnMap, required this.onRoute, this.routeActive = false});
  @override
  State<MapCompactCamelCard> createState() => _MapCompactCamelCardState();
}

class _MapCompactCamelCardState extends State<MapCompactCamelCard> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final status = widget.boundary;
    final tint = status == MapBoundaryState.outside
      ? const Color(0xFFCB4255)
      : status == MapBoundaryState.inside
        ? const Color(0xFF26875F) : Colors.blueGrey;
    final caption = widget.zoneDescription;
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(18),
      child: InkWell(onTap: () => setState(() => expanded = !expanded),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDE5DF))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              MapCamelPhoto(photoPath: widget.photoPath, size: 47),
              const SizedBox(width: 6),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('شماره ${r.camelNo}', maxLines: 1,
                  style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ])),
            ]),
            const SizedBox(height: 9),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(color: tint.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12)),
              child: Row(children: [Icon(Icons.circle, size: 8, color: tint),
                const SizedBox(width: 5),
                Expanded(child: Text(caption, maxLines: 2,
                  style: TextStyle(fontSize: 10, color: tint, fontWeight: FontWeight.bold))),
              ])),
            const SizedBox(height: 7),
            Row(children: [
              Icon(Icons.battery_std_rounded, color: r.isBatteryLow ? Colors.orange : Colors.green,
                size: 16),
              Text('${r.batteryPercent}%', style: const TextStyle(fontSize: 11)),
              const Spacer(),
              Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: Colors.black54, size: 20),
            ]),
            if (expanded) ...[
              const Divider(height: 14),
              SelectableText('تگ: ${r.tagId}', style: const TextStyle(fontSize: 10)),
              const SizedBox(height: 5),
              Text('آخرین GPS: ${widget.dateText}', style: const TextStyle(fontSize: 10)),
              const SizedBox(height: 5),
              Text('GPS: ${r.latitude?.toStringAsFixed(5) ?? '-'} , ${r.longitude?.toStringAsFixed(5) ?? '-'}',
                style: const TextStyle(fontSize: 10)),
              TextButton.icon(onPressed: widget.onShowOnMap,
                icon: const Icon(Icons.center_focus_strong, size: 16),
                label: const Text('نمایش روی نقشه', style: TextStyle(fontSize: 10))),
              TextButton.icon(onPressed: widget.onRoute,
                icon: Icon(widget.routeActive ? Icons.close_rounded : Icons.route_rounded,
                  size: 16),
                label: Text(widget.routeActive ? 'بستن مسیر' : 'مسیر شتر',
                  style: const TextStyle(fontSize: 10))),
            ],
          ]),
        ),
      ),
    );
  }
}
