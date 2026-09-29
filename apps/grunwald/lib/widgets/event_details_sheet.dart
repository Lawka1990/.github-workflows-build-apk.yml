import 'package:flutter/material.dart';

import '../models/program_event.dart';
import '../state/app_controller.dart';
import '../theme/medieval_theme.dart';
import '../utils/category_catalog.dart';
import '../utils/icon_catalog.dart';
import '../utils/polish_date.dart';
import 'parchment_panel.dart';

Future<void> showEventDetailsSheet(
  BuildContext context,
  AppController controller,
  ProgramEvent event,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _EventDetailsSheet(
      controller: controller,
      event: event,
    ),
  );
}

class _EventDetailsSheet extends StatelessWidget {
  const _EventDetailsSheet({required this.controller, required this.event});

  final AppController controller;
  final ProgramEvent event;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final favorite = controller.isFavoriteEvent(event.id);
        return Container(
          decoration: const BoxDecoration(
            color: MedievalColors.charcoal,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(
              top: BorderSide(color: MedievalColors.gold, width: 2),
            ),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AspectRatio(
                    aspectRatio: 2.25,
                    child: Image.asset(
                      IconCatalog.eventImage(event.category),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ParchmentPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          color: MedievalColors.ink,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _EventInfoRow(
                        icon: Icons.calendar_month_outlined,
                        text: PolishDate.full(event.date),
                      ),
                      _EventInfoRow(
                        icon: Icons.schedule,
                        text: '${event.start} – ${event.end}',
                      ),
                      _EventInfoRow(
                        icon: Icons.location_on_outlined,
                        text: controller.placeName(event.placeId),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            avatar: Icon(
                              CategoryCatalog.eventCategoryIcon(
                                event.category,
                              ),
                              size: 17,
                              color: MedievalColors.ink,
                            ),
                            label: Text(
                              CategoryCatalog.eventLabel(event.category),
                            ),
                            backgroundColor: MedievalColors.parchmentDark,
                            side: const BorderSide(
                              color: MedievalColors.inkSoft,
                            ),
                          ),
                          if (event.isRehearsal)
                            const Chip(
                              avatar: Icon(
                                Icons.build_outlined,
                                size: 17,
                                color: MedievalColors.ink,
                              ),
                              label: Text('Próba'),
                              backgroundColor: MedievalColors.parchmentDark,
                              side: BorderSide(color: MedievalColors.inkSoft),
                            ),
                        ],
                      ),
                      if (event.description.isNotEmpty) ...[
                        const Divider(color: MedievalColors.parchmentDark),
                        const SizedBox(height: 5),
                        Text(
                          event.description,
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
                    controller.showPlaceOnMap(event.placeId);
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Pokaż miejsce na mapie'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MedievalColors.parchmentLight,
                    side: const BorderSide(color: MedievalColors.gold),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () => controller.toggleFavoriteEvent(event.id),
                  icon: Icon(favorite ? Icons.star : Icons.star_border),
                  label: Text(
                    favorite ? 'Usuń z ulubionych' : 'Dodaj do ulubionych',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EventInfoRow extends StatelessWidget {
  const _EventInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: MedievalColors.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: MedievalColors.ink,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
