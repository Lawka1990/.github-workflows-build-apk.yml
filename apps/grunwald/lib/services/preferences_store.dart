import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/calibration_anchor.dart';
import '../models/place.dart';

class PreferencesStore {
  PreferencesStore() : _preferences = SharedPreferencesAsync();

  static const String _customPlacesKey = 'v11_custom_places';
  static const String _positionsKey = 'v11_place_positions';
  static const String _calibrationAnchorsKey = 'v11_field_calibration_anchors';
  static const String _placeOverridesKey = 'v12_place_overrides';
  static const String _favoriteEventsKey = 'v12_favorite_event_ids';

  final SharedPreferencesAsync _preferences;

  Future<List<Place>> loadCustomPlaces() async {
    final value = await _preferences.getString(_customPlacesKey);
    if (value == null || value.isEmpty) return const <Place>[];
    try {
      final decoded = jsonDecode(value) as List<Object?>;
      return decoded
          .map((item) => Place.fromJson(item! as Map<String, Object?>))
          .toList();
    } on FormatException {
      return const <Place>[];
    } on TypeError {
      return const <Place>[];
    }
  }

  Future<Map<String, Place>> loadPlaceOverrides() async {
    final value = await _preferences.getString(_placeOverridesKey);
    if (value == null || value.isEmpty) return <String, Place>{};
    try {
      final decoded = jsonDecode(value) as List<Object?>;
      final result = <String, Place>{};
      for (final item in decoded) {
        final place = Place.fromJson(item! as Map<String, Object?>);
        result[place.id] = place;
      }
      return result;
    } on FormatException {
      return <String, Place>{};
    } on TypeError {
      return <String, Place>{};
    }
  }

  Future<Map<String, ({double x, double y})>> loadPositions() async {
    final value = await _preferences.getString(_positionsKey);
    if (value == null || value.isEmpty) {
      return <String, ({double x, double y})>{};
    }
    try {
      final decoded = jsonDecode(value) as Map<String, Object?>;
      final result = <String, ({double x, double y})>{};
      for (final entry in decoded.entries) {
        final position = entry.value! as Map<String, Object?>;
        result[entry.key] = (
          x: (position['x']! as num).toDouble(),
          y: (position['y']! as num).toDouble(),
        );
      }
      return result;
    } on FormatException {
      return <String, ({double x, double y})>{};
    } on TypeError {
      return <String, ({double x, double y})>{};
    }
  }

  Future<List<CalibrationAnchor>> loadCalibrationAnchors() async {
    final value = await _preferences.getString(_calibrationAnchorsKey);
    if (value == null || value.isEmpty) return const <CalibrationAnchor>[];
    try {
      final decoded = jsonDecode(value) as List<Object?>;
      return decoded
          .map(
            (item) => CalibrationAnchor.fromJson(
              item! as Map<String, Object?>,
            ),
          )
          .toList(growable: false);
    } on FormatException {
      return const <CalibrationAnchor>[];
    } on TypeError {
      return const <CalibrationAnchor>[];
    }
  }

  Future<void> saveCalibrationAnchors(
    List<CalibrationAnchor> anchors,
  ) async {
    await _preferences.setString(
      _calibrationAnchorsKey,
      jsonEncode(anchors.map((anchor) => anchor.toJson()).toList()),
    );
  }

  Future<void> saveCustomPlaces(List<Place> places) async {
    final value = jsonEncode(
      places.where((place) => place.custom).map((place) => place.toJson()).toList(),
    );
    await _preferences.setString(_customPlacesKey, value);
  }

  Future<void> savePlaceOverrides(List<Place> places) async {
    final value = jsonEncode(
      places
          .where((place) => !place.custom)
          .map((place) => place.toJson())
          .toList(),
    );
    await _preferences.setString(_placeOverridesKey, value);
  }

  Future<Set<String>> loadFavoriteEventIds() async {
    final value = await _preferences.getStringList(_favoriteEventsKey);
    return value?.toSet() ?? <String>{};
  }

  Future<void> saveFavoriteEventIds(Set<String> ids) async {
    final sorted = ids.toList()..sort();
    await _preferences.setStringList(_favoriteEventsKey, sorted);
  }

  Future<void> savePositions(List<Place> places) async {
    final data = <String, Object?>{
      for (final place in places)
        place.id: <String, Object?>{'x': place.x, 'y': place.y},
    };
    await _preferences.setString(_positionsKey, jsonEncode(data));
  }

  Future<void> clearMapChanges() async {
    await _preferences.remove(_customPlacesKey);
    await _preferences.remove(_positionsKey);
    await _preferences.remove(_placeOverridesKey);
  }

  Future<void> clearCalibrationAnchors() async {
    await _preferences.remove(_calibrationAnchorsKey);
  }
}
