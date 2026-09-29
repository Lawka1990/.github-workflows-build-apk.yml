import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../data/app_repository.dart';
import '../models/calibration_anchor.dart';
import '../models/place.dart';
import '../models/program_event.dart';
import '../services/location_service.dart';
import '../services/map_calibration.dart';
import '../services/preferences_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    AppRepository repository = const AppRepository(),
    LocationService locationService = const LocationService(),
    PreferencesStore? preferencesStore,
  })  : _repository = repository,
        _locationService = locationService,
        _preferencesStore = preferencesStore ?? PreferencesStore();

  final AppRepository _repository;
  final LocationService _locationService;
  final PreferencesStore _preferencesStore;

  List<Place> _places = const <Place>[];
  List<Place> _sourcePlaces = const <Place>[];
  Map<String, Place> _placeOverrides = <String, Place>{};
  List<ProgramEvent> _events = const <ProgramEvent>[];
  Set<String> _favoriteEventIds = <String>{};
  List<CalibrationAnchor> _fieldCalibrationAnchors =
      const <CalibrationAnchor>[];
  int _selectedTab = 0;
  String? _focusedPlaceId;
  int _focusSerial = 0;
  bool _adminUnlocked = false;
  bool _editMode = false;
  Offset? _userMapPosition;
  Position? _lastGpsPosition;
  String? _locationError;
  bool _locating = false;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _positionsSaveTimer;

  List<Place> get places => List<Place>.unmodifiable(_places);
  List<ProgramEvent> get events => List<ProgramEvent>.unmodifiable(_events);
  List<CalibrationAnchor> get fieldCalibrationAnchors =>
      List<CalibrationAnchor>.unmodifiable(_fieldCalibrationAnchors);
  int get selectedTab => _selectedTab;
  String? get focusedPlaceId => _focusedPlaceId;
  int get focusSerial => _focusSerial;
  bool get adminUnlocked => _adminUnlocked;
  bool get editMode => _editMode;
  Offset? get userMapPosition => _userMapPosition;
  Position? get lastGpsPosition => _lastGpsPosition;
  String? get locationError => _locationError;
  bool get locating => _locating;
  Set<String> get favoriteEventIds => Set<String>.unmodifiable(_favoriteEventIds);

  Future<void> initialize({bool force = false}) async {
    if (_places.isNotEmpty && !force) return;
    _sourcePlaces = await _repository.loadPlaces();
    _events = await _repository.loadEvents();
    final customPlaces = await _preferencesStore.loadCustomPlaces();
    _placeOverrides = await _preferencesStore.loadPlaceOverrides();
    final sourceIds = _sourcePlaces.map((place) => place.id).toSet();
    _placeOverrides.removeWhere((id, _) => !sourceIds.contains(id));
    final positions = await _preferencesStore.loadPositions();
    _fieldCalibrationAnchors =
        await _preferencesStore.loadCalibrationAnchors();
    _favoriteEventIds = await _preferencesStore.loadFavoriteEventIds();
    final eventIds = _events.map((event) => event.id).toSet();
    _favoriteEventIds.removeWhere((id) => !eventIds.contains(id));

    _places = <Place>[
      ..._sourcePlaces.map((place) {
        final overridden = _placeOverrides[place.id] ?? place;
        final saved = positions[place.id];
        return saved == null
            ? overridden
            : overridden.copyWith(x: saved.x, y: saved.y);
      }),
      ...customPlaces
          .where(
            (place) => !_sourcePlaces.any(
              (source) => source.id == place.id,
            ),
          )
          .map((place) {
            final saved = positions[place.id];
            return saved == null ? place : place.copyWith(x: saved.x, y: saved.y);
          }),
    ];
    notifyListeners();
  }

  void selectTab(int index) {
    if (_selectedTab == index) return;
    _selectedTab = index.clamp(0, 3).toInt();
    notifyListeners();
  }

  Place? placeById(String id) {
    for (final place in _places) {
      if (place.id == id) return place;
    }
    return null;
  }

  String placeName(String id) => placeById(id)?.name ?? 'Miejsce wydarzenia';

  void showPlaceOnMap(String placeId) {
    _focusedPlaceId = placeId;
    _focusSerial += 1;
    _selectedTab = 0;
    notifyListeners();
  }

  void clearMapFocus() {
    if (_focusedPlaceId == null) return;
    _focusedPlaceId = null;
    notifyListeners();
  }

  List<ProgramEvent> eventsForDate(DateTime date) {
    return _events
        .where(
          (event) => event.date.year == date.year &&
              event.date.month == date.month &&
              event.date.day == date.day,
        )
        .toList(growable: false);
  }

  List<DateTime> get programDates {
    final unique = <String, DateTime>{};
    for (final event in _events) {
      unique['${event.date.year}-${event.date.month}-${event.date.day}'] = event.date;
    }
    final result = unique.values.toList()..sort();
    return result;
  }

  List<ProgramEvent> activeEvents(DateTime now) {
    return _events.where((event) => event.isActiveAt(now)).toList(growable: false);
  }

  List<ProgramEvent> nextEvents(DateTime now, {int limit = 4}) {
    return _events
        .where((event) => event.isUpcomingAt(now))
        .take(limit)
        .toList(growable: false);
  }

  bool isFavoriteEvent(String eventId) => _favoriteEventIds.contains(eventId);

  Future<void> toggleFavoriteEvent(String eventId) async {
    if (_favoriteEventIds.contains(eventId)) {
      _favoriteEventIds = <String>{..._favoriteEventIds}..remove(eventId);
    } else {
      _favoriteEventIds = <String>{..._favoriteEventIds, eventId};
    }
    notifyListeners();
    await _preferencesStore.saveFavoriteEventIds(_favoriteEventIds);
  }

  bool unlockAdmin(String pin) {
    if (pin != '1410') return false;
    _adminUnlocked = true;
    notifyListeners();
    return true;
  }

  void lockAdmin() {
    _adminUnlocked = false;
    _editMode = false;
    notifyListeners();
  }

  void setEditMode(bool value) {
    if (!_adminUnlocked && value) return;
    _editMode = value;
    if (value) _selectedTab = 0;
    notifyListeners();
  }

  Future<void> addPlace(Place place) async {
    _places = <Place>[..._places, place.copyWith(custom: true)];
    await _persistPlaces();
    _focusedPlaceId = place.id;
    _focusSerial += 1;
    notifyListeners();
  }

  Future<void> updatePlace(Place updated) async {
    if (!updated.custom) {
      _placeOverrides = <String, Place>{
        ..._placeOverrides,
        updated.id: updated,
      };
    }
    _places = _places
        .map((place) => place.id == updated.id ? updated : place)
        .toList(growable: false);
    await _persistPlaces();
    notifyListeners();
  }

  void movePlace(String id, double x, double y) {
    final safeX = x.clamp(0.01, 0.99).toDouble();
    final safeY = y.clamp(0.01, 0.99).toDouble();
    _places = _places
        .map(
          (place) => place.id == id ? place.copyWith(x: safeX, y: safeY) : place,
        )
        .toList(growable: false);
    notifyListeners();
    _positionsSaveTimer?.cancel();
    _positionsSaveTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_preferencesStore.savePositions(_places));
    });
  }

  Future<void> deletePlace(String id) async {
    final place = placeById(id);
    if (place == null || !place.custom) return;
    _places = _places.where((item) => item.id != id).toList(growable: false);
    await _persistPlaces();
    notifyListeners();
  }

  Future<void> resetMapChanges() async {
    _positionsSaveTimer?.cancel();
    await _preferencesStore.clearMapChanges();
    _placeOverrides = <String, Place>{};
    _places = List<Place>.of(_sourcePlaces);
    _focusedPlaceId = null;
    _editMode = false;
    notifyListeners();
  }

  Future<Offset?> locateUser() async {
    if (_locating) return _userMapPosition;
    _locating = true;
    _locationError = null;
    notifyListeners();
    try {
      final position = await _locationService.currentPosition();
      _acceptPosition(position, smooth: false);
      await _positionSubscription?.cancel();
      _positionSubscription = _locationService.positionStream().listen(
        _acceptPosition,
        onError: (Object error) {
          _locationError = _friendlyLocationError(error);
          notifyListeners();
        },
      );
      return _userMapPosition;
    } catch (error) {
      _locationError = _friendlyLocationError(error);
      return null;
    } finally {
      _locating = false;
      notifyListeners();
    }
  }

  Future<String> calibrateCurrentPositionToPlace(Place place) async {
    var position = _lastGpsPosition;
    if (position == null) {
      try {
        position = await _locationService.currentPosition();
      } catch (error) {
        return _friendlyLocationError(error);
      }
    }

    final anchor = CalibrationAnchor(
      id: 'field_${place.id}',
      name: place.name,
      latitude: position.latitude,
      longitude: position.longitude,
      mapX: place.x,
      mapY: place.y,
      fieldMeasured: true,
    );
    _fieldCalibrationAnchors = <CalibrationAnchor>[
      ..._fieldCalibrationAnchors.where((item) => item.id != anchor.id),
      anchor,
    ];
    await _preferencesStore.saveCalibrationAnchors(_fieldCalibrationAnchors);
    _acceptPosition(position, smooth: false);
    notifyListeners();

    final accuracy = position.accuracy.round();
    if (accuracy > 15) {
      return 'Punkt zapisany, ale dokładność GPS wynosiła ±$accuracy m. '
          'Dla najlepszego wyniku powtórz zapis na otwartej przestrzeni.';
    }
    return 'Zapisano kotwicę terenową „${place.name}” z dokładnością ±$accuracy m.';
  }

  Future<void> clearFieldCalibration() async {
    _fieldCalibrationAnchors = const <CalibrationAnchor>[];
    await _preferencesStore.clearCalibrationAnchors();
    final position = _lastGpsPosition;
    if (position != null) _acceptPosition(position, smooth: false);
    notifyListeners();
  }

  Future<bool> openLocationSettings() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    return serviceEnabled
        ? _locationService.openAppSettings()
        : _locationService.openLocationSettings();
  }

  void _acceptPosition(Position position, {bool smooth = true}) {
    _lastGpsPosition = position;
    final projected = MapCalibration.gpsToMap(
      position.latitude,
      position.longitude,
      fieldAnchors: _fieldCalibrationAnchors,
    );
    if (projected == null) {
      _userMapPosition = null;
      _locationError = 'Jesteś poza skalibrowanym obszarem mapy.';
      notifyListeners();
      return;
    }

    if (smooth && _userMapPosition != null) {
      final alpha = position.accuracy <= 6
          ? 0.70
          : position.accuracy <= 15
              ? 0.50
              : 0.32;
      _userMapPosition = Offset(
        _userMapPosition!.dx * (1 - alpha) + projected.dx * alpha,
        _userMapPosition!.dy * (1 - alpha) + projected.dy * alpha,
      );
    } else {
      _userMapPosition = projected;
    }

    _locationError = position.accuracy > 35
        ? 'Słaby sygnał GPS: dokładność ±${position.accuracy.round()} m.'
        : null;
    notifyListeners();
  }

  Future<void> _persistPlaces() async {
    await Future.wait<void>(<Future<void>>[
      _preferencesStore.saveCustomPlaces(_places),
      _preferencesStore.savePlaceOverrides(_placeOverrides.values.toList()),
      _preferencesStore.savePositions(_places),
    ]);
  }

  String _friendlyLocationError(Object error) {
    if (error is LocationException) return error.message;
    if (error is TimeoutException) {
      return 'GPS nie odpowiedział na czas. Wyjdź na otwartą przestrzeń i spróbuj ponownie.';
    }
    final text = error.toString().toLowerCase();
    if (text.contains('disabled')) {
      return 'Lokalizacja jest wyłączona. Włącz GPS w ustawieniach telefonu.';
    }
    if (text.contains('permission') || text.contains('denied')) {
      return 'Brak dostępu do lokalizacji. Włącz uprawnienie w ustawieniach aplikacji.';
    }
    return 'Nie udało się pobrać pozycji GPS. Spróbuj ponownie.';
  }

  @override
  void dispose() {
    _positionsSaveTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
