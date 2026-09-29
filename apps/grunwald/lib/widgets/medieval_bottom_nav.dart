import 'package:flutter/material.dart';

import '../theme/medieval_theme.dart';

class MedievalBottomNav extends StatelessWidget {
  const MedievalBottomNav({
    required this.currentIndex,
    required this.onChanged,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  static const List<({String label, IconData icon})> _items = [
    (label: 'Mapa', icon: Icons.map_outlined),
    (label: 'Miejsca', icon: Icons.location_on_outlined),
    (label: 'Teraz', icon: Icons.schedule),
    (label: 'Program', icon: Icons.calendar_month_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Color(0xFA0F0E0A),
        border: Border(top: BorderSide(color: MedievalColors.inkSoft, width: 1.4)),
      ),
      child: Row(
        children: List<Widget>.generate(_items.length, (index) {
          final selected = index == currentIndex;
          final item = _items[index];
          return Expanded(
            child: Semantics(
              selected: selected,
              button: true,
              label: item.label,
              child: InkWell(
                onTap: () => onChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: selected ? MedievalColors.goldBright : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 23,
                        color: selected
                            ? MedievalColors.goldBright
                            : MedievalColors.gold.withValues(alpha: 0.68),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: selected
                              ? MedievalColors.goldBright
                              : MedievalColors.gold.withValues(alpha: 0.68),
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
