import 'package:flutter/material.dart';

import '../models/place.dart';
import '../theme/medieval_theme.dart';
import '../utils/icon_catalog.dart';

class PlaceMarker extends StatelessWidget {
  const PlaceMarker({
    required this.place,
    required this.selected,
    required this.editing,
    required this.onTap,
    required this.onDrag,
    super.key,
  });

  final Place place;
  final bool selected;
  final bool editing;
  final VoidCallback onTap;
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) {
    final color = IconCatalog.markerColor(place.color);
    final size = selected ? 48.0 : 40.0;
    return Semantics(
      button: true,
      selected: selected,
      label: editing ? '${place.name}, punkt do przesunięcia' : place.name,
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: editing ? (details) => onDrag(details.delta) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: selected ? MedievalColors.goldBright : Colors.white,
              width: selected ? 4 : 2.5,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Colors.black87, blurRadius: 7, spreadRadius: 1),
            ],
          ),
          child: Icon(
            IconCatalog.placeIcon(place.icon),
            size: selected ? 25 : 21,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class UserLocationMarker extends StatefulWidget {
  const UserLocationMarker({super.key});

  @override
  State<UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Twoja pozycja GPS',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = _controller.value;
          return SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 24 + value * 28,
                  height: 24 + value * 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MedievalColors.blue.withValues(
                      alpha: 0.32 * (1 - value),
                    ),
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2B75DB),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Colors.black87, blurRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
