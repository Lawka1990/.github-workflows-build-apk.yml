import 'package:flutter/material.dart';

import '../theme/medieval_theme.dart';

class ParchmentPanel extends StatelessWidget {
  const ParchmentPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(12),
    this.margin,
    this.onTap,
    this.borderRadius = 3,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: MedievalColors.ink, width: 2.2),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius - 1),
          border: Border.all(color: MedievalColors.parchmentDark, width: 2),
          image: DecorationImage(
            image: const AssetImage('assets/images/parchment.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              MedievalColors.parchmentLight.withValues(alpha: 0.72),
              BlendMode.srcOver,
            ),
          ),
        ),
        padding: padding,
        child: child,
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
