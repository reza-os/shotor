import 'package:flutter/material.dart';

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _active = Color(0xFFB85C2D);
  static const _muted = Color(0xFF7E817E);

  @override
  Widget build(BuildContext context) {
    final items = <_NavItemData>[
      const _NavItemData(Icons.home_rounded, 'خانه'),
      const _NavItemData(Icons.pets_rounded, 'گله'),
      const _NavItemData(Icons.map_rounded, 'نقشه'),
      const _NavItemData(Icons.grid_view_rounded, 'بیشتر'),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFF0E8E1)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D3218).withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == currentIndex;

              Widget icon = Icon(
                item.icon,
                size: selected ? 25 : 23,
                color: selected ? Colors.white : _muted,
              );

              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? _active : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        icon,
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                            color: selected ? Colors.white : _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData(this.icon, this.label);
}