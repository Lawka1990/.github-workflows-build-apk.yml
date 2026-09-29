import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/place.dart';
import '../models/program_event.dart';

class AppRepository {
  const AppRepository();

  Future<List<Place>> loadPlaces() async {
    final raw = await rootBundle.loadString('assets/data/places.json');
    final decoded = jsonDecode(raw) as List<Object?>;
    return decoded
        .map((item) => Place.fromJson(item! as Map<String, Object?>))
        .toList(growable: false);
  }

  Future<List<ProgramEvent>> loadEvents() async {
    final raw = await rootBundle.loadString('assets/data/program_2026.json');
    final decoded = jsonDecode(raw) as List<Object?>;
    final events = decoded
        .map(
          (item) => ProgramEvent.fromJson(item! as Map<String, Object?>),
        )
        .toList();
    events.sort((a, b) => a.startsAt().compareTo(b.startsAt()));
    return events;
  }
}
