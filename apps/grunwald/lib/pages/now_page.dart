import 'dart:async';

import 'package:flutter/material.dart';

import '../models/program_event.dart';
import '../state/app_controller.dart';
import '../theme/medieval_theme.dart';
import '../utils/polish_date.dart';
import '../widgets/event_card.dart';
import '../widgets/event_details_sheet.dart';

class NowPage extends StatefulWidget {
  const NowPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<NowPage> createState() => _NowPageState();
}

class _NowPageState extends State<NowPage> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.controller.activeEvents(_now);
    final upcoming = widget.controller.nextEvents(
      _now,
      limit: active.isEmpty ? 4 : 2,
    );
    final displayed = <({ProgramEvent event, String status})>[
      for (final event in active) (event: event, status: 'Trwa!'),
      for (final event in upcoming)
        (event: event, status: _statusFor(event, _now)),
    ];

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: MedievalColors.charcoal.withValues(alpha: 0.94),
            border: Border.all(color: MedievalColors.inkSoft),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: MedievalColors.goldBright),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                'Co się dzieje teraz',
                style: TextStyle(
                  color: MedievalColors.goldBright,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
                ),
              ),
              Text(
                '${_now.hour.toString().padLeft(2, '0')}:'
                '${_now.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: MedievalColors.parchmentDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: displayed.isEmpty
              ? _NoEvents(controller: widget.controller, now: _now)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                  children: [
                    for (final item in displayed)
                      EventCard(
                        event: item.event,
                        placeName: widget.controller.placeName(item.event.placeId),
                        status: item.status,
                        onTap: () => showEventDetailsSheet(
                          context,
                          widget.controller,
                          item.event,
                        ),
                      ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MedievalColors.goldBright,
                        side: const BorderSide(color: MedievalColors.inkSoft),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      onPressed: () => widget.controller.selectTab(3),
                      child: const Text('Zobacz pełny program  →'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  String _statusFor(ProgramEvent event, DateTime now) {
    final difference = event.startsAt().difference(now);
    if (difference.inMinutes <= 60 && difference.inMinutes >= 0) return 'Zaraz';
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
    );
    final calendarDays = eventDay.difference(today).inDays;
    if (calendarDays == 0) return 'Dzisiaj';
    if (calendarDays == 1) return 'Jutro';
    if (calendarDays > 1 && calendarDays < 7) {
      return 'Za $calendarDays dni';
    }
    return 'Następne wydarzenie';
  }
}

class _NoEvents extends StatelessWidget {
  const _NoEvents({required this.controller, required this.now});

  final AppController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final dates = controller.programDates;
    final lastDate = dates.isEmpty ? null : dates.last;
    final afterEdition = lastDate != null && now.isAfter(
      DateTime(lastDate.year, lastDate.month, lastDate.day, 23, 59),
    );
    final message = afterEdition
        ? 'Dni Grunwaldu 2026 już się zakończyły. Pełny program tej edycji pozostaje dostępny w aplikacji.'
        : 'W tej chwili nie trwa żadne wydarzenie. Sprawdź pełny program Dni Grunwaldu.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history_toggle_off,
              color: MedievalColors.goldBright,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MedievalColors.goldBright,
                fontSize: 18,
              ),
            ),
            if (lastDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Ostatni dzień: ${PolishDate.full(lastDate)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MedievalColors.parchmentDark,
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => controller.selectTab(3),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Otwórz program'),
            ),
          ],
        ),
      ),
    );
  }
}
