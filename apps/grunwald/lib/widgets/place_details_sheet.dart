import 'package:flutter/material.dart';

import '../models/place.dart';
import '../state/app_controller.dart';
import '../theme/medieval_theme.dart';
import '../utils/category_catalog.dart';
import '../utils/icon_catalog.dart';
import 'parchment_panel.dart';

Future<void> showPlaceDetailsSheet(
  BuildContext context,
  AppController controller,
  Place place,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _PlaceDetailsSheet(
      controller: controller,
      place: place,
    ),
  );
}

class _PlaceDetailsSheet extends StatelessWidget {
  const _PlaceDetailsSheet({required this.controller, required this.place});

  final AppController controller;
  final Place place;

  @override
  Widget build(BuildContext context) {
    final markerColor = IconCatalog.markerColor(place.color);
    return Container(
      decoration: const BoxDecoration(
        color: MedievalColors.charcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: MedievalColors.gold, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: SizedBox(
                width: 44,
                child: Divider(
                  color: MedievalColors.parchmentDark,
                  thickness: 3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ParchmentPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: markerColor,
                          border: Border.all(
                            color: MedievalColors.ink,
                            width: 2.5,
                          ),
                        ),
                        child: Icon(
                          IconCatalog.placeIcon(place.icon),
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: const TextStyle(
                                color: MedievalColors.ink,
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (place.subtitle.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                place.subtitle,
                                style: const TextStyle(
                                  color: MedievalColors.inkSoft,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: CategoryCatalog.placeCategoryIcon(place.category),
                        label: CategoryCatalog.placeLabel(place.category),
                      ),
                      if (place.verified)
                        const _InfoChip(
                          icon: Icons.verified,
                          label: 'Sprawdzone',
                          color: MedievalColors.green,
                        ),
                      if (place.custom)
                        const _InfoChip(
                          icon: Icons.edit_location_alt,
                          label: 'Punkt własny',
                        ),
                    ],
                  ),
                  if (place.description.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    const Divider(color: MedievalColors.parchmentDark),
                    const SizedBox(height: 5),
                    Text(
                      place.description,
                      style: const TextStyle(
                        color: MedievalColors.ink,
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                controller.showPlaceOnMap(place.id);
              },
              icon: const Icon(Icons.map_outlined),
              label: const Text('Pokaż na mapie'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = MedievalColors.inkSoft,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
