import 'package:flutter/material.dart';

import '../theme/medieval_theme.dart';

typedef CatalogEntry = ({String id, String label, IconData icon});

abstract final class CategoryCatalog {
  static const List<CatalogEntry> placeCategories = <CatalogEntry>[
    (id: 'oboz', label: 'Obozy', icon: Icons.flag_outlined),
    (id: 'atrakcja', label: 'Atrakcje', icon: Icons.explore_outlined),
    (id: 'uslugi', label: 'Usługi', icon: Icons.info_outline),
    (id: 'pole', label: 'Pole bitwy', icon: Icons.sports_martial_arts),
    (id: 'pomnik', label: 'Pomniki', icon: Icons.account_balance_outlined),
    (id: 'muzeum', label: 'Muzea', icon: Icons.museum_outlined),
    (id: 'kaplica', label: 'Kaplice', icon: Icons.church_outlined),
    (id: 'scena', label: 'Sceny', icon: Icons.music_note_outlined),
    (id: 'parking', label: 'Parkingi', icon: Icons.local_parking),
    (id: 'inne', label: 'Inne', icon: Icons.place_outlined),
    (id: 'własny', label: 'Własne', icon: Icons.edit_location_alt_outlined),
  ];

  static const List<CatalogEntry> eventCategories = <CatalogEntry>[
    (id: 'walki', label: 'Walki', icon: Icons.sports_martial_arts),
    (id: 'inscenizacja', label: 'Inscenizacje', icon: Icons.shield_outlined),
    (id: 'lucznictwo', label: 'Łucznictwo', icon: Icons.track_changes),
    (id: 'religia', label: 'Nabożeństwa', icon: Icons.church_outlined),
    (id: 'muzyka', label: 'Muzyka', icon: Icons.music_note_outlined),
    (id: 'historia', label: 'Historia', icon: Icons.museum_outlined),
    (id: 'sport', label: 'Sport', icon: Icons.emoji_events_outlined),
    (id: 'gry', label: 'Gry', icon: Icons.casino_outlined),
    (id: 'pokaz', label: 'Pokazy', icon: Icons.visibility_outlined),
    (id: 'proba', label: 'Próby', icon: Icons.build_outlined),
    (id: 'inne', label: 'Inne', icon: Icons.event_outlined),
  ];

  static const List<({String id, String label, Color color})> markerColors = [
    (id: 'red', label: 'Czerwony', color: MedievalColors.redBright),
    (id: 'blue', label: 'Niebieski', color: MedievalColors.blue),
    (id: 'green', label: 'Zielony', color: MedievalColors.green),
    (id: 'gold', label: 'Złoty', color: Color(0xFF8C642E)),
    (id: 'black', label: 'Czarny', color: MedievalColors.charcoal),
    (id: 'brown', label: 'Brązowy', color: Color(0xFF745129)),
    (id: 'purple', label: 'Fioletowy', color: Color(0xFF604474)),
    (id: 'gray', label: 'Szary', color: Color(0xFF756F63)),
    (id: 'yellow', label: 'Żółty', color: Color(0xFFD5B136)),
  ];

  static const List<({String id, String label})> markerIcons = [
    (id: 'place', label: 'Punkt'),
    (id: 'camp', label: 'Chorągiew'),
    (id: 'swords', label: 'Walki'),
    (id: 'bow', label: 'Łucznictwo'),
    (id: 'horse', label: 'Konie'),
    (id: 'hammer', label: 'Rzemiosło'),
    (id: 'cross', label: 'Kaplica'),
    (id: 'museum', label: 'Muzeum'),
    (id: 'monument', label: 'Pomnik'),
    (id: 'medical', label: 'Medycy'),
    (id: 'wc', label: 'WC'),
    (id: 'shower', label: 'Prysznice'),
    (id: 'parking', label: 'Parking'),
    (id: 'music', label: 'Scena'),
    (id: 'intersection', label: 'Droga'),
    (id: 'cannon', label: 'Artyleria'),
  ];

  static String placeLabel(String id) =>
      _labelFor(placeCategories, id, fallback: 'Inne');

  static IconData placeCategoryIcon(String id) =>
      _iconFor(placeCategories, id, fallback: Icons.place_outlined);

  static String eventLabel(String id) =>
      _labelFor(eventCategories, id, fallback: 'Inne');

  static IconData eventCategoryIcon(String id) =>
      _iconFor(eventCategories, id, fallback: Icons.event_outlined);

  static String _labelFor(
    List<CatalogEntry> entries,
    String id, {
    required String fallback,
  }) {
    for (final entry in entries) {
      if (entry.id == id) return entry.label;
    }
    return fallback;
  }

  static IconData _iconFor(
    List<CatalogEntry> entries,
    String id, {
    required IconData fallback,
  }) {
    for (final entry in entries) {
      if (entry.id == id) return entry.icon;
    }
    return fallback;
  }
}
