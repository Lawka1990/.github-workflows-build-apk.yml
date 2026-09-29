import 'package:flutter/material.dart';

import '../models/program_event.dart';
import '../theme/medieval_theme.dart';
import '../utils/icon_catalog.dart';
import 'parchment_panel.dart';

class EventCard extends StatelessWidget {
  const EventCard({
    required this.event,
    required this.placeName,
    required this.status,
    required this.onTap,
    super.key,
  });

  final ProgramEvent event;
  final String placeName;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ParchmentPanel(
      onTap: onTap,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 152,
        child: Row(
          children: [
            SizedBox(
              width: 132,
              height: double.infinity,
              child: Image.asset(
                IconCatalog.eventImage(event.category),
                fit: BoxFit.cover,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MedievalColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: const TextStyle(
                        color: MedievalColors.red,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${event.start} – ${event.end}',
                      style: const TextStyle(
                        color: MedievalColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: MedievalColors.inkSoft),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            placeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: MedievalColors.inkSoft),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 38,
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                color: MedievalColors.red,
                border: Border(left: BorderSide(color: MedievalColors.gold)),
              ),
              child: Icon(
                IconCatalog.eventIcon(event.category),
                color: MedievalColors.parchmentLight,
                size: 23,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
