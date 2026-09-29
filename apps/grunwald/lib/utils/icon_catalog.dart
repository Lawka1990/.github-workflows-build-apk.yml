import 'package:flutter/material.dart';

import '../theme/medieval_theme.dart';

abstract final class IconCatalog {
  static IconData placeIcon(String name) {
    return switch (name) {
      'swords' => Icons.sports_martial_arts,
      'monument' => Icons.account_balance,
      'old_museum' || 'museum' => Icons.museum,
      'target' => Icons.gps_fixed,
      'hammer' => Icons.handyman,
      'horse' => Icons.pets,
      'intersection' => Icons.alt_route,
      'music' => Icons.music_note,
      'cross' => Icons.church,
      'bow' => Icons.track_changes,
      'parking' => Icons.local_parking,
      'wc' => Icons.wc,
      'shower' => Icons.shower,
      'camp' => Icons.flag,
      'cannon' => Icons.adjust,
      'medical' => Icons.local_hospital,
      _ => Icons.place,
    };
  }

  static IconData eventIcon(String category) {
    return switch (category) {
      'walki' || 'inscenizacja' || 'proba' => Icons.sports_martial_arts,
      'lucznictwo' => Icons.track_changes,
      'religia' => Icons.church,
      'muzyka' => Icons.music_note,
      'historia' => Icons.museum,
      'sport' || 'gry' => Icons.emoji_events,
      'pokaz' => Icons.visibility,
      _ => Icons.event,
    };
  }

  static String eventImage(String category) {
    return switch (category) {
      'walki' || 'inscenizacja' || 'proba' => 'assets/images/battle.jpg',
      'lucznictwo' => 'assets/images/archery.jpg',
      'religia' => 'assets/images/mass.jpg',
      _ => 'assets/images/craft.jpg',
    };
  }

  static Color markerColor(String name) {
    return switch (name) {
      'red' => MedievalColors.redBright,
      'blue' => MedievalColors.blue,
      'green' => MedievalColors.green,
      'purple' => const Color(0xFF604474),
      'black' => MedievalColors.charcoal,
      'gray' => const Color(0xFF756F63),
      'brown' => const Color(0xFF745129),
      'yellow' => const Color(0xFFD5B136),
      _ => const Color(0xFF8C642E),
    };
  }
}
