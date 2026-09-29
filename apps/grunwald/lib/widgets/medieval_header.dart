import 'package:flutter/material.dart';

import '../theme/medieval_theme.dart';

class MedievalHeader extends StatelessWidget {
  const MedievalHeader({
    required this.title,
    super.key,
    this.onShieldTap,
    this.adminActive = false,
  });

  final String title;
  final VoidCallback? onShieldTap;
  final bool adminActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Color(0xF5100E0A),
        border: Border(
          bottom: BorderSide(color: MedievalColors.inkSoft, width: 1.4),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const SizedBox(
            width: 42,
            child: Center(
              child: Text(
                '⚜',
                style: TextStyle(
                  color: MedievalColors.gold,
                  fontSize: 27,
                  height: 1,
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _HeaderLine(),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    title.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MedievalColors.goldBright,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const _HeaderLine(),
              ],
            ),
          ),
          SizedBox(
            width: 42,
            child: IconButton(
              tooltip: adminActive
                  ? 'Administrator aktywny'
                  : 'Administracja',
              onPressed: onShieldTap,
              padding: EdgeInsets.zero,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 29,
                    height: 34,
                    decoration: BoxDecoration(
                      color: adminActive
                          ? MedievalColors.red.withValues(alpha: 0.58)
                          : Colors.transparent,
                      border: Border.all(color: MedievalColors.gold),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                        bottom: Radius.circular(12),
                      ),
                    ),
                    child: const Icon(
                      Icons.shield,
                      size: 18,
                      color: MedievalColors.goldBright,
                    ),
                  ),
                  if (adminActive)
                    Positioned(
                      right: -3,
                      bottom: -2,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: MedievalColors.green,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderLine extends StatelessWidget {
  const _HeaderLine();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 28,
      child: Row(
        children: [
          Expanded(child: Divider(color: MedievalColors.gold, thickness: 1)),
          Icon(Icons.circle, size: 4, color: MedievalColors.gold),
        ],
      ),
    );
  }
}
