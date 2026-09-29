
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

const String ptasiaSplitVariant = 'obserwacje';
const String ptasiaSplitAppName = 'Ptasie Obserwacje';
const bool ptasiaSplitReadOnly = false;
const bool ptasiaSplitBudkiOnly = false;
const bool ptasiaSplitObservationsOnly = true;


const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const String adminPassword = String.fromEnvironment('ADMIN_PASSWORD', defaultValue: 'ptasia-admin');
const String superAdminEmail = String.fromEnvironment('SUPER_ADMIN_EMAIL', defaultValue: 'bartoszlawicki@gmail.com');
const String oauthRedirectTo = String.fromEnvironment(
  'SUPABASE_OAUTH_REDIRECT_TO',
  defaultValue: 'io.supabase.flutter://login-callback/',
);
const String passwordResetRedirectTo = String.fromEnvironment(
  'SUPABASE_PASSWORD_RESET_REDIRECT_TO',
  // Używamy tego samego callbacku co Google/OAuth. Supabase Flutter najpewniej
  // przechwytuje wtedy sesję po kliknięciu linku resetu hasła.
  defaultValue: 'io.supabase.flutter://login-callback/',
);

final GlobalKey<NavigatorState> ptasiaNavigatorKey = GlobalKey<NavigatorState>();


const MethodChannel _ptasiaNativeFilePicker = MethodChannel('pl.bartoszlawicki.ptasia_mapa/native_file_picker');

class PtasiaPickedFile {
  const PtasiaPickedFile({
    required this.name,
    required this.bytes,
  });

  final String name;
  final List<int> bytes;
}

Future<PtasiaPickedFile?> pickGpxKmlFileFromDevice() async {
  if (!Platform.isAndroid) {
    throw UnsupportedError('Import pliku jest teraz obsługiwany w aplikacji Android.');
  }

  final result = await _ptasiaNativeFilePicker.invokeMapMethod<String, dynamic>('pickGpxKmlFile');
  if (result == null) return null;

  final name = (result['name'] as String?)?.trim();
  final base64Text = result['base64'] as String?;

  if (base64Text == null || base64Text.isEmpty) {
    throw const FormatException('Wybrany plik jest pusty albo nie udało się go odczytać.');
  }

  return PtasiaPickedFile(
    name: (name == null || name.isEmpty) ? 'import.gpx' : name,
    bytes: base64Decode(base64Text),
  );
}


const String appVersionName = String.fromEnvironment('APP_VERSION_NAME', defaultValue: '0.9.3');
const int appVersionCode = int.fromEnvironment('APP_VERSION_CODE', defaultValue: 99);
const String appUpdateJsonUrl = String.fromEnvironment('APP_UPDATE_JSON_URL');
const String appUpdateApkUrl = String.fromEnvironment('APP_UPDATE_APK_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool supabaseReady = false;
  final cleanUrl = _normalizeSupabaseUrl(supabaseUrl);

  if (cleanUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: cleanUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          // W tej aplikacji zostawiamy implicit, bo jest prostszy i bardziej
          // odporny przy deep linkach na Androidzie: Google login, potwierdzenie
          // emaila i reset hasła wracają tym samym callbackiem do aplikacji.
          authFlowType: AuthFlowType.implicit,
        ),
      );
      supabaseReady = true;
    } catch (_) {
      supabaseReady = false;
    }
  }

  runApp(PtasiaApp(supabaseReady: supabaseReady));
}

String _normalizeSupabaseUrl(String raw) {
  var url = raw.trim();
  if (url.isEmpty) return '';
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  url = url.replaceAll('/rest/v1', '');
  url = url.replaceAll('/auth/v1', '');
  return url;
}

class PtasiaApp extends StatefulWidget {
  const PtasiaApp({super.key, required this.supabaseReady});

  final bool supabaseReady;

  @override
  State<PtasiaApp> createState() => _PtasiaAppState();
}

class _PtasiaAppState extends State<PtasiaApp> {
  late final AppState state;

  @override
  void initState() {
    super.initState();
    state = AppState(widget.supabaseReady);
    state.init();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Ptasie Obserwacje',
        theme: AppTheme.theme,
        navigatorKey: ptasiaNavigatorKey,
        routes: {
          '/reset-password': (_) => const PasswordResetPage(),
        },
        home: const HomePage(),
      ),
    );
  }
}

class AppTheme {
  static const green = Color(0xFF0A6B35);
  static const darkGreen = Color(0xFF064D2B);
  static const moss = Color(0xFF6B8E23);
  static const bark = Color(0xFF9A6427);
  static const cream = Color(0xFFFFFCF2);

  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: green,
      brightness: Brightness.light,
      primary: green,
      secondary: moss,
      tertiary: bark,
      surface: cream,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFEFF7EA),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.1,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDDEFD8),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w900 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: green,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: Color(0xFFB7D6B4), width: 1.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFDDE8D4))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: green, width: 1.7)),
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE1EADB)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF26352A),
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _ForestGradient extends StatelessWidget {
  const _ForestGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF064D2B), Color(0xFF0B7A3B), Color(0xFF5F8D2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}


class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    if (scope == null || scope.notifier == null) {
      throw StateError('Brak AppStateScope');
    }
    return scope.notifier!;
  }
}

class AppState extends ChangeNotifier {
  AppState(this.supabaseReady);

  final bool supabaseReady;
  final List<NestSite> sites = [];
  final List<BirdObservation> birdObservations = [];
  final Uuid _uuid = const Uuid();

  int currentTab = 0;
  bool adminMode = false;
  bool pickingOnMap = false;
  String? errorMessage;
  String? infoMessage;
  bool syncing = false;
  bool checkingUpdate = false;
  bool importingClanga = false;
  bool importingGpx = false;
  DateTime? lastClangaImportAt;
  DateTime? lastGpxImportAt;
  bool birdObservationsNewestFirst = true;
  String nestSiteSearchQuery = '';
  String birdObservationSearchQuery = '';
  Set<String> enabledBirdRarityGroups = {'pospolite', 'lokalne', 'rzadkie', 'bardzo_rzadkie'};
  Set<String> enabledBirdSpecies = <String>{};
  int birdObservationPageIndex = 0;
  bool showBirdObservationFilters = false;
  static const int birdObservationPageSize = 5;
  List<BirdObservation>? _cachedFilteredBirdObservations;
  int _cachedBirdObservationsLength = -1;
  String _cachedBirdObservationSearch = '';
  String _cachedBirdGroups = '';
  String _cachedBirdSpeciesFilter = '';
  bool _cachedBirdAdmin = false;
  Map<String, int>? _cachedBirdRarityCounts;
  List<String>? _cachedObservedSpeciesForFilter;
  bool updateDialogShown = false;
  UpdateInfo? availableUpdate;
  String? localGuestId;
  User? currentUser;
  String userRole = 'user';

  SupabaseClient? get client => supabaseReady ? Supabase.instance.client : null;
  bool get loggedIn => currentUser != null;
  bool get isSuperAdmin => (currentUser?.email ?? '').toLowerCase() == superAdminEmail.toLowerCase();
  bool get isAdminByProfile => userRole == 'admin' || userRole == 'super_admin';
  bool get isAdmin => adminMode || isAdminByProfile || isSuperAdmin;
  String get roleLabel {
    if (isSuperAdmin) return 'Super admin';
    if (isAdmin) return 'Administrator';
    if (loggedIn) return 'Użytkownik';
    return 'Gość';
  }

  Future<void> init() async {
    await _loadLocal();
    if (supabaseReady) {
      try {
        currentUser = client!.auth.currentUser;
        await _loadProfile();
        client!.auth.onAuthStateChange.listen((event) async {
          currentUser = event.session?.user;
          await _loadProfile();
          notifyListeners();

          if (event.event == AuthChangeEvent.passwordRecovery) {
            Future.microtask(() {
              ptasiaNavigatorKey.currentState?.pushNamed('/reset-password');
            });
          }
        });
      } catch (_) {
        currentUser = null;
      }
    }
    notifyListeners();
    Future.microtask(() => checkForUpdates(manual: false));
    if (supabaseReady && client != null) {
      Future.microtask(() => sync(silent: true));
    }
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    localGuestId = prefs.getString('local_guest_id');
    if (localGuestId == null || localGuestId!.isEmpty) {
      localGuestId = 'guest-${_uuid.v4()}';
      await prefs.setString('local_guest_id', localGuestId!);
    }
    birdObservationsNewestFirst = prefs.getBool('bird_observations_newest_first') ?? true;
    nestSiteSearchQuery = prefs.getString('nest_site_search_query') ?? '';
    birdObservationSearchQuery = prefs.getString('bird_observation_search_query') ?? '';
    enabledBirdRarityGroups = (prefs.getStringList('enabled_bird_rarity_groups') ?? const ['pospolite', 'lokalne', 'rzadkie', 'bardzo_rzadkie']).toSet();
    enabledBirdSpecies = (prefs.getStringList('enabled_bird_species') ?? const <String>[]).toSet();

    final rawBirds = prefs.getString('bird_observations_v1');
    if (rawBirds != null && rawBirds.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBirds);
        if (decoded is List) {
          birdObservations
            ..clear()
            ..addAll(decoded.whereType<Map>().map((e) => BirdObservation.fromJson(Map<String, dynamic>.from(e))));
        }
      } catch (_) {
        await prefs.setString('bird_observations_v1_broken_${DateTime.now().millisecondsSinceEpoch}', rawBirds);
        await prefs.remove('bird_observations_v1');
        birdObservations.clear();
      }
    }

    final raw = prefs.getString('sites_v1');
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        sites
          ..clear()
          ..addAll(decoded.whereType<Map>().map((e) => NestSite.fromJson(Map<String, dynamic>.from(e))));
      }
    } catch (_) {
      await prefs.setString('sites_v1_broken_${DateTime.now().millisecondsSinceEpoch}', raw);
      await prefs.remove('sites_v1');
      sites.clear();
    }
  }

  Future<void> saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(sites.map((e) => e.toJson()).toList());
    final rawBirds = jsonEncode(birdObservations.map((e) => e.toJson()).toList());
    await prefs.setString('sites_v1', raw);
    await prefs.setString('bird_observations_v1', rawBirds);
    await prefs.setBool('bird_observations_newest_first', birdObservationsNewestFirst);
    await prefs.setString('nest_site_search_query', nestSiteSearchQuery);
    await prefs.setString('bird_observation_search_query', birdObservationSearchQuery);
    await prefs.setStringList('enabled_bird_rarity_groups', enabledBirdRarityGroups.toList());
    await prefs.setStringList('enabled_bird_species', enabledBirdSpecies.toList());
  }

  Future<void> _loadProfile() async {
    userRole = 'user';
    if (!supabaseReady || currentUser == null) return;

    try {
      await client!.from('app_profiles').upsert({
        'user_id': currentUser!.id,
        'email': currentUser!.email ?? '',
        'role': isSuperAdmin ? 'super_admin' : 'user',
      }, onConflict: 'user_id');

      final row = await client!
          .from('app_profiles')
          .select('role')
          .eq('user_id', currentUser!.id)
          .maybeSingle();

      final role = row?['role']?.toString();
      if (role != null && role.isNotEmpty) userRole = role;
    } catch (_) {
      userRole = isSuperAdmin ? 'super_admin' : 'user';
    }
  }

  void setTab(int tab) {
    currentTab = tab;
    notifyListeners();
  }

  void setPicking(bool value) {
    pickingOnMap = value;
    notifyListeners();
  }

  void showError(String message) {
    errorMessage = message;
    infoMessage = null;
    notifyListeners();
  }

  void showInfo(String message) {
    infoMessage = message;
    errorMessage = null;
    notifyListeners();
  }

  void clearMessages() {
    errorMessage = null;
    infoMessage = null;
    notifyListeners();
  }

  List<NestSite> visibleSites() {
    final active = sites.where((s) => !s.deleted).toList();
    if (isAdmin) return active;

    // Gość i zwykły użytkownik widzą mapę oraz wszystkie nieukryte obiekty.
    // Edycja nadal jest ograniczona w canEdit(): admin albo właściciel obiektu.
    return active.where((s) => !s.hiddenFromUsers).toList();
  }

  Map<String, int> nestBoxOccupancyByBird() {
    final counts = <String, int>{};

    for (final site in visibleSites()) {
      final inspections = site.inspections
          .where((i) => !i.deleted && i.birdsPresent && i.birdSpecies.trim().isNotEmpty)
          .toList();

      if (inspections.isEmpty) continue;

      inspections.sort((a, b) => b.date.compareTo(a.date));
      final species = canonicalBirdSpeciesName(inspections.first.birdSpecies.trim());

      if (species.isEmpty) continue;
      counts[species] = (counts[species] ?? 0) + 1;
    }

    return counts;
  }

  List<MapEntry<String, int>> mostCommonNestBoxBirds({int limit = 10}) {
    final entries = nestBoxOccupancyByBird().entries.toList();

    entries.sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return birdSpeciesPolishName(a.key).compareTo(birdSpeciesPolishName(b.key));
    });

    return entries.take(limit).toList();
  }

  List<NestSite> searchedSites() {
    final list = visibleSites().toList();
    final query = _normalizeSpeciesForMatch(nestSiteSearchQuery);

    if (query.isEmpty) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    }

    final filtered = list.where((site) {
      final name = _normalizeSpeciesForMatch(site.name);
      return name.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final an = _normalizeSpeciesForMatch(a.name);
      final bn = _normalizeSpeciesForMatch(b.name);

      final aStarts = an.startsWith(query);
      final bStarts = bn.startsWith(query);
      if (aStarts != bStarts) return aStarts ? -1 : 1;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }

  Future<void> setNestSiteSearchQuery(String value) async {
    final clean = value.trim();
    if (nestSiteSearchQuery == clean) return;

    nestSiteSearchQuery = clean;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nest_site_search_query', clean);
  }

  Future<void> clearNestSiteSearchQuery() => setNestSiteSearchQuery('');

  List<NestSite> latestSites({int limit = 5}) {
    final list = visibleSites().toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  void invalidateBirdObservationCaches() {
    _cachedFilteredBirdObservations = null;
    _cachedBirdObservationsLength = -1;
    _cachedBirdRarityCounts = null;
    _cachedObservedSpeciesForFilter = null;
  }

  List<BirdObservation> visibleBirdObservations() {
    final active = birdObservations.where((o) => !o.deleted).toList();
    if (isAdmin) return active;
    return active.where((o) => !o.hiddenFromUsers).toList();
  }

  List<BirdObservation> filteredBirdObservations() {
    final groupsKey = (enabledBirdRarityGroups.toList()..sort()).join(',');
    final speciesKey = (enabledBirdSpecies.toList()..sort()).join(',');

    final cached = _cachedFilteredBirdObservations;
    if (cached != null &&
        _cachedBirdObservationsLength == birdObservations.length &&
        _cachedBirdObservationSearch == birdObservationSearchQuery &&
        _cachedBirdGroups == groupsKey &&
        _cachedBirdSpeciesFilter == speciesKey &&
        _cachedBirdAdmin == isAdmin) {
      return cached;
    }

    final query = _normalizeSpeciesForMatch(birdObservationSearchQuery);
    final result = <BirdObservation>[];

    for (final obs in visibleBirdObservations()) {
      final group = birdRarityGroupKey(obs.species);
      if (!enabledBirdRarityGroups.contains(group)) continue;

      if (enabledBirdSpecies.isNotEmpty &&
          !enabledBirdSpecies.contains(canonicalBirdSpeciesName(obs.species))) {
        continue;
      }

      if (query.isNotEmpty) {
        final full = _normalizeSpeciesForMatch(obs.fullSpeciesName);
        final polish = _normalizeSpeciesForMatch(obs.polishSpeciesName);
        final latin = _normalizeSpeciesForMatch(obs.latinSpeciesName);
        final place = _normalizeSpeciesForMatch(obs.placeDescription);

        if (!(full.contains(query) || polish.contains(query) || latin.contains(query) || place.contains(query))) {
          continue;
        }
      }

      result.add(obs);
    }

    _cachedBirdObservationsLength = birdObservations.length;
    _cachedBirdObservationSearch = birdObservationSearchQuery;
    _cachedBirdGroups = groupsKey;
    _cachedBirdSpeciesFilter = speciesKey;
    _cachedBirdAdmin = isAdmin;
    _cachedFilteredBirdObservations = result;

    return result;
  }

  Map<String, int> birdRarityGroupCounts() {
    final cached = _cachedBirdRarityCounts;
    if (cached != null) return cached;

    final counts = <String, int>{
      'pospolite': 0,
      'lokalne': 0,
      'rzadkie': 0,
      'bardzo_rzadkie': 0,
    };

    for (final obs in visibleBirdObservations()) {
      final key = birdRarityGroupKey(obs.species);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    _cachedBirdRarityCounts = counts;
    return counts;
  }

  List<String> observedSpeciesForFilter() {
    final cached = _cachedObservedSpeciesForFilter;
    if (cached != null) return cached;

    final set = visibleBirdObservations().map((o) => canonicalBirdSpeciesName(o.species)).toSet().toList();
    set.sort((a, b) => birdSpeciesPolishName(a).compareTo(birdSpeciesPolishName(b)));

    _cachedObservedSpeciesForFilter = set;
    return set;
  }

  void toggleBirdObservationFilters() {
    showBirdObservationFilters = !showBirdObservationFilters;
    notifyListeners();
  }

  Future<void> setBirdObservationSearchQuery(String value) async {
    final clean = value.trim();
    if (birdObservationSearchQuery == clean) return;

    birdObservationSearchQuery = clean;
    birdObservationPageIndex = 0;
    invalidateBirdObservationCaches();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bird_observation_search_query', clean);
  }

  Future<void> clearBirdObservationSearchQuery() => setBirdObservationSearchQuery('');

  Future<void> toggleBirdRarityGroup(String key, bool enabled) async {
    if (enabled) {
      enabledBirdRarityGroups.add(key);
    } else {
      enabledBirdRarityGroups.remove(key);
    }

    birdObservationPageIndex = 0;
    invalidateBirdObservationCaches();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('enabled_bird_rarity_groups', enabledBirdRarityGroups.toList());
  }

  Future<void> toggleBirdSpeciesFilter(String species, bool enabled) async {
    final canonical = canonicalBirdSpeciesName(species);

    if (enabled) {
      enabledBirdSpecies.add(canonical);
    } else {
      enabledBirdSpecies.remove(canonical);
    }

    birdObservationPageIndex = 0;
    invalidateBirdObservationCaches();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('enabled_bird_species', enabledBirdSpecies.toList());
  }

  Future<void> clearBirdSpeciesFilter() async {
    enabledBirdSpecies.clear();
    birdObservationPageIndex = 0;
    invalidateBirdObservationCaches();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('enabled_bird_species', enabledBirdSpecies.toList());
  }

  List<BirdObservation> latestBirdObservations({int limit = 20}) {
    final list = filteredBirdObservations().toList();
    list.sort((a, b) {
      final byDate = birdObservationsNewestFirst
          ? b.observedAt.compareTo(a.observedAt)
          : a.observedAt.compareTo(b.observedAt);
      if (byDate != 0) return byDate;
      return a.polishSpeciesName.compareTo(b.polishSpeciesName);
    });
    return list.take(limit).toList();
  }

  List<BirdObservation> pagedBirdObservations() {
    final list = latestBirdObservations(limit: 100000);
    final start = birdObservationPageIndex * birdObservationPageSize;

    if (start >= list.length && birdObservationPageIndex > 0) {
      birdObservationPageIndex = 0;
      return list.take(birdObservationPageSize).toList();
    }

    return list.skip(start).take(birdObservationPageSize).toList();
  }

  int birdObservationTotalFilteredCount() => filteredBirdObservations().length;

  int birdObservationTotalPages() {
    final total = birdObservationTotalFilteredCount();
    if (total == 0) return 1;
    return ((total - 1) ~/ birdObservationPageSize) + 1;
  }

  int birdObservationRangeStart() {
    final total = birdObservationTotalFilteredCount();
    if (total == 0) return 0;
    return birdObservationPageIndex * birdObservationPageSize + 1;
  }

  int birdObservationRangeEnd() {
    final total = birdObservationTotalFilteredCount();
    final end = (birdObservationPageIndex + 1) * birdObservationPageSize;
    return end > total ? total : end;
  }

  Future<void> setBirdObservationPage(int page) async {
    final maxPage = birdObservationTotalPages() - 1;
    final next = page.clamp(0, maxPage).toInt();

    if (birdObservationPageIndex == next) return;
    birdObservationPageIndex = next;
    notifyListeners();
  }

  Future<void> nextBirdObservationPage() => setBirdObservationPage(birdObservationPageIndex + 1);

  Future<void> previousBirdObservationPage() => setBirdObservationPage(birdObservationPageIndex - 1);

  Future<void> setBirdObservationsNewestFirst(bool value) async {
    if (birdObservationsNewestFirst == value) return;
    birdObservationsNewestFirst = value;
    birdObservationPageIndex = 0;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bird_observations_newest_first', value);
  }

  Map<String, int> commonBirds() {
    final map = <String, int>{};
    for (final s in visibleSites()) {
      for (final i in s.inspections) {
        if (i.birdsPresent && i.birdSpecies.trim().isNotEmpty) {
          map[i.birdSpecies] = (map[i.birdSpecies] ?? 0) + 1;
        }
      }
    }
    for (final o in visibleBirdObservations()) {
      if (o.species.trim().isNotEmpty) {
        map[o.species] = (map[o.species] ?? 0) + max(1, o.count);
      }
    }
    final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries.take(8));
  }

  List<NestSite> repairSites() {
    final list = visibleSites().where(_siteNeedsRepair).toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<NestSite> cleanedSites() {
    final list = visibleSites().where((s) => _latestCleanedInspection(s) != null).toList();
    list.sort((a, b) {
      final ad = _latestCleanedInspection(a)?.date ?? DateTime(1900);
      final bd = _latestCleanedInspection(b)?.date ?? DateTime(1900);
      return bd.compareTo(ad);
    });
    return list;
  }

  List<NestSite> toCleanSites() {
    final now = DateTime.now();
    final list = visibleSites().where((s) => !_cleanedInSelectedSeason(s, now)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<LatLng> currentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Lokalizacja w telefonie jest wyłączona.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Brak zgody na GPS. Nadaj zgodę w Androidzie.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('GPS zablokowany na stałe. Wejdź w ustawienia aplikacji i nadaj zgodę.');
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return LatLng(pos.latitude, pos.longitude);
  }

  Future<List<NearbySite>> findNearbySites({
    required double latitude,
    required double longitude,
    double radiusMeters = 35,
    String? excludeId,
  }) async {
    final center = LatLng(latitude, longitude);
    final distance = const Distance();
    final found = <String, NearbySite>{};

    void addCandidate(NestSite site) {
      if (site.deleted) return;
      if (excludeId != null && site.id == excludeId) return;

      final meters = distance.as(LengthUnit.Meter, center, LatLng(site.latitude, site.longitude));
      if (meters <= radiusMeters) {
        final old = found[site.id];
        final result = NearbySite(site: site, distanceMeters: meters);
        if (old == null || result.distanceMeters < old.distanceMeters) {
          found[site.id] = result;
        }
      }
    }

    for (final site in sites) {
      addCandidate(site);
    }

    if (supabaseReady && client != null) {
      try {
        final latDelta = radiusMeters / 111111.0;
        final lonDivider = 111111.0 * max(0.2, cos(latitude * pi / 180.0).abs());
        final lonDelta = radiusMeters / lonDivider;

        final rows = await client!
            .from('nest_sites')
            .select()
            .eq('deleted', false)
            .gte('latitude', latitude - latDelta)
            .lte('latitude', latitude + latDelta)
            .gte('longitude', longitude - lonDelta)
            .lte('longitude', longitude + lonDelta)
            .limit(25);

        for (final row in rows) {
          if (row is Map) {
            addCandidate(NestSite.fromServerMap(Map<String, dynamic>.from(row)));
          }
        }
      } catch (_) {
        // Brak internetu albo brak tabeli nie może blokować dodawania obiektu.
      }
    }

    final result = found.values.toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return result;
  }

  NestSite createSite({
    required String name,
    required String type,
    required double latitude,
    required double longitude,
    String placeDescription = '',
    String technicalStatus = 'Dobry',
    bool repairNeeded = false,
    String damageDescription = '',
    String notes = '',
    List<String> photoPaths = const [],
  }) {
    if (!canCreateObjects) {
      showInfo('Gość może tylko oglądać obiekty na mapie. Dodawanie wymaga zalogowania.');
      throw StateError('guest cannot create objects');
    }

    final now = DateTime.now();
    final site = NestSite(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Nowy obiekt' : name.trim(),
      type: type,
      latitude: latitude,
      longitude: longitude,
      placeDescription: placeDescription,
      technicalStatus: technicalStatus,
      repairNeeded: repairNeeded,
      damageDescription: damageDescription,
      notes: notes,
      photoPaths: List<String>.from(photoPaths),
      ownerId: currentUser?.id ?? localGuestId ?? 'guest',
      ownerEmail: currentUser?.email ?? 'gość',
      reportStatus: loggedIn ? 'Zgłoszona' : 'Zgłoszona anonimowo',
      createdAt: now,
      updatedAt: now,
      locallyChanged: true,
    );
    sites.add(site);
    saveLocal();
    notifyListeners();
    return site;
  }

  BirdObservation createBirdObservation({
    required String species,
    required double latitude,
    required double longitude,
    DateTime? observedAt,
    int count = 1,
    String placeDescription = '',
    String behaviour = '',
    String notes = '',
    bool sensitive = false,
    String source = 'Ptasie Obserwacje',
    String externalId = '',
    String externalUrl = '',
    List<String> photoPaths = const [],
  }) {
    if (!canCreateObjects) {
      showInfo('Gość może oglądać obserwacje, ale dodawanie wymaga zalogowania.');
      throw StateError('guest cannot create bird observations');
    }

    final now = DateTime.now();
    final obs = BirdObservation(
      id: _uuid.v4(),
      species: canonicalBirdSpeciesName(species.trim().isEmpty ? birdSpecies.first : species.trim()),
      latitude: latitude,
      longitude: longitude,
      observedAt: observedAt ?? now,
      count: max(1, count),
      placeDescription: placeDescription,
      behaviour: behaviour,
      notes: notes,
      sensitive: sensitive || isRareBirdSpecies(canonicalBirdSpeciesName(species)),
      hiddenFromUsers: false,
      deleted: false,
      ownerId: currentUser?.id ?? localGuestId ?? 'guest',
      ownerEmail: currentUser?.email ?? 'gość',
      createdAt: now,
      updatedAt: now,
      locallyChanged: true,
      source: source,
      externalId: externalId,
      externalUrl: externalUrl,
      photoPaths: List<String>.from(photoPaths),
    );
    birdObservations.add(obs);
    saveLocal();
    notifyListeners();
    return obs;
  }


  Future<void> importClangaObservations({int limit = 25}) async {
    if (importingClanga) return;

    importingClanga = true;
    clearMessages();
    notifyListeners();

    try {
      final drafts = await fetchClangaObservationDrafts(limit: limit);

      if (drafts.isEmpty) {
        showInfo('Nie znaleziono obserwacji do importu z Clanga. Strona mogła chwilowo nie odpowiedzieć.');
        return;
      }

      var added = 0;
      var skipped = 0;
      final now = DateTime.now();

      for (final d in drafts) {
        final alreadyExists = birdObservations.any((o) {
          final sameExternal = d.externalId.isNotEmpty && o.externalId == d.externalId;
          final sameUrl = d.externalUrl.isNotEmpty && o.externalUrl == d.externalUrl;
          final sameSpeciesPlaceDate = o.source == 'Clanga' &&
              _normalizeSpeciesForMatch(o.species) == _normalizeSpeciesForMatch(d.species) &&
              o.observedAt.year == d.observedAt.year &&
              o.observedAt.month == d.observedAt.month &&
              o.observedAt.day == d.observedAt.day &&
              _normalizeSpeciesForMatch(o.placeDescription) == _normalizeSpeciesForMatch(d.placeDescription);
          return sameExternal || sameUrl || sameSpeciesPlaceDate;
        });

        if (alreadyExists) {
          skipped++;
          continue;
        }

        final obs = BirdObservation(
          id: _uuid.v4(),
          species: canonicalBirdSpeciesName(d.species),
          latitude: d.latitude,
          longitude: d.longitude,
          observedAt: d.observedAt,
          count: d.count,
          placeDescription: d.placeDescription,
          behaviour: d.behaviour,
          notes: d.notes,
          sensitive: d.sensitive,
          hiddenFromUsers: false,
          deleted: false,
          ownerId: 'clanga',
          ownerEmail: 'Clanga.com',
          createdAt: now,
          updatedAt: now,
          locallyChanged: loggedIn || isAdmin,
          source: 'Clanga',
          externalId: d.externalId,
          externalUrl: d.externalUrl,
        );

        birdObservations.add(obs);
        added++;
      }

      lastClangaImportAt = now;
      await saveLocal();
      notifyListeners();

      if (added > 0 && supabaseReady && client != null && (loggedIn || isAdmin)) {
        await sync(silent: true);
      }

      showInfo('Clanga: dodano $added obserwacji, pominięto duplikaty $skipped. Gatunki rzadkie oznaczono automatycznie.');
    } catch (e) {
      showError('Nie udało się pobrać obserwacji z Clanga. Sprawdź internet albo spróbuj później. Szczegóły: $e');
    } finally {
      importingClanga = false;
      notifyListeners();
    }
  }

  Future<void> updateBirdObservation(BirdObservation obs) async {
    obs.updatedAt = DateTime.now();
    obs.locallyChanged = true;
    await saveLocal();
    notifyListeners();
  }

  bool canEditBirdObservation(BirdObservation obs) {
    if (isAdmin) return true;
    if (!loggedIn) return false;
    return obs.ownerId == currentUser!.id;
  }

  Future<void> deleteBirdObservation(BirdObservation obs) async {
    obs.deleted = true;
    obs.updatedAt = DateTime.now();
    obs.locallyChanged = true;
    await saveLocal();
    notifyListeners();
  }

  Future<void> updateSite(NestSite site) async {
    site.updatedAt = DateTime.now();
    site.locallyChanged = true;
    await saveLocal();
    notifyListeners();
  }

  bool canEdit(NestSite site) {
    if (isAdmin) return true;
    if (!loggedIn) return false;
    return site.ownerId == currentUser!.id;
  }

  bool get canCreateObjects => loggedIn || isAdmin;
  bool get canAddInspections => loggedIn || isAdmin;

  Future<void> deleteSite(NestSite site) async {
    site.deleted = true;
    site.updatedAt = DateTime.now();
    site.locallyChanged = true;
    await saveLocal();
    notifyListeners();
  }

  Future<void> requestDelete(NestSite site, String reason) async {
    site.deleteRequested = true;
    site.deleteReason = reason;
    site.updatedAt = DateTime.now();
    site.locallyChanged = true;
    await saveLocal();
    notifyListeners();
  }

  Future<void> _upsertNestSiteSafe(NestSite site) async {
    final data = site.toServerMap();

    try {
      await client!.from('nest_sites').upsert(data, onConflict: 'id');
    } catch (e) {
      final msg = e.toString();

      // Starsza baza mogła nie mieć jeszcze kolumny photo_urls. Wtedy zapisujemy obiekt bez zdjęć,
      // żeby synchronizacja całej aplikacji nie padała.
      if (msg.contains('photo_urls') || msg.contains('photo url') || msg.contains('PGRST204')) {
        final fallback = Map<String, dynamic>.from(data)..remove('photo_urls');
        await client!.from('nest_sites').upsert(fallback, onConflict: 'id');
        return;
      }

      rethrow;
    }
  }

  Future<void> _upsertInspectionSafe(NestSite site, Inspection inspection) async {
    try {
      await client!.from('inspections').upsert(inspection.toServerMap(site.id), onConflict: 'id');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('inspections') || msg.contains('relation') || msg.contains('does not exist')) {
        throw Exception('Brakuje tabeli inspections. Uruchom w Supabase aktualny schema.sql.');
      }
      rethrow;
    }
  }

  Future<void> _upsertBirdObservationSafe(BirdObservation obs) async {
    final data = obs.toServerMap();

    try {
      await client!.from('bird_observations').upsert(data, onConflict: 'id');
    } catch (e) {
      final msg = e.toString();

      // Starsza baza może jeszcze nie mieć kolumn source/external_id/external_url.
      // Wtedy zapisujemy obserwację bez tych pól, żeby sync nie blokował aplikacji.
      if (msg.contains('source') || msg.contains('external_id') || msg.contains('external_url') || msg.contains('PGRST204')) {
        final fallback = Map<String, dynamic>.from(data)
          ..remove('source')
          ..remove('external_id')
          ..remove('external_url');
        await client!.from('bird_observations').upsert(fallback, onConflict: 'id');
        return;
      }

      if (msg.contains('bird_observations') || msg.contains('relation') || msg.contains('does not exist') || msg.contains('Could not find')) {
        throw Exception('Brakuje tabeli bird_observations. Uruchom w Supabase aktualny plik supabase/schema.sql.');
      }
      rethrow;
    }
  }

  Future<List<BirdObservation>> _loadBirdObservationsSafe({bool silent = false}) async {
    try {
      final rows = await client!
          .from('bird_observations')
          .select()
          .eq('deleted', false)
          .order('observed_at', ascending: false);

      final list = rows.map<BirdObservation>((r) => BirdObservation.fromServerMap(Map<String, dynamic>.from(r))).toList();
      if (isAdmin) return list;
      return list.where((o) => !o.hiddenFromUsers).toList();
    } catch (e) {
      final msg = e.toString();
      if (!silent && (msg.contains('bird_observations') || msg.contains('Could not find') || msg.contains('schema'))) {
        showError('Nie udało się pobrać obserwacji ptaków. Uruchom aktualny supabase/schema.sql. Szczegóły: $e');
      }
      return <BirdObservation>[];
    }
  }

  Future<List<Inspection>> _loadInspectionsSafe(String siteId) async {
    try {
      final rows = await client!
          .from('inspections')
          .select()
          .eq('nest_site_id', siteId)
          .eq('deleted', false)
          .order('date', ascending: false);

      return rows.map<Inspection>((r) => Inspection.fromServerMap(Map<String, dynamic>.from(r))).toList();
    } catch (_) {
      // Brak tabeli inspekcji nie może ukrywać mapy i obiektów.
      return <Inspection>[];
    }
  }

  Future<void> sync({bool silent = false}) async {
    if (!supabaseReady || client == null) {
      if (!silent) showError('Supabase nie jest skonfigurowany. Sprawdź SUPABASE_URL i SUPABASE_ANON_KEY.');
      return;
    }

    if (syncing) return;
    syncing = true;
    if (!silent) clearMessages();
    notifyListeners();

    try {
      final localBeforeSync = {for (final s in sites) s.id: s};
      final localBirdsBeforeSync = {for (final o in birdObservations) o.id: o};

      // 1. Wyślij lokalne zmiany. Robimy kopię listy, żeby nie modyfikować jej podczas pętli.
      final changedSites = sites.where((s) => s.locallyChanged).toList();
      for (final site in changedSites) {
        await _upsertNestSiteSafe(site);

        final changedInspections = site.inspections.where((i) => i.locallyChanged).toList();
        for (final inspection in changedInspections) {
          await _upsertInspectionSafe(site, inspection);
          inspection.locallyChanged = false;
        }

        site.locallyChanged = false;
      }

      final changedBirdObservations = birdObservations.where((o) => o.locallyChanged).toList();
      for (final obs in changedBirdObservations) {
        await _upsertBirdObservationSafe(obs);
        obs.locallyChanged = false;
      }

      // 2. Pobierz widoczne obiekty także dla gościa.
      // Wcześniej gość nie pobierał obiektów z Supabase, dlatego mapa mogła wyglądać jak pusta.
      dynamic query = client!.from('nest_sites').select();
      query = query.eq('deleted', false);

      if (!isAdmin) {
        query = query.eq('hidden_from_users', false);
      }

      final rows = await query.order('updated_at', ascending: false);

      final remoteSites = <NestSite>[];
      for (final row in rows) {
        final site = NestSite.fromServerMap(Map<String, dynamic>.from(row));

        final previousLocal = localBeforeSync[site.id];
        if (site.photoPaths.isEmpty && previousLocal != null && previousLocal.photoPaths.isNotEmpty) {
          site.photoPaths = previousLocal.photoPaths;
        }

        site.inspections = await _loadInspectionsSafe(site.id);

        // Jeżeli lokalnie mamy inspekcje, których jeszcze nie ma z serwera,
        // zachowujemy je zamiast nadpisać pustką.
        if (previousLocal != null && site.inspections.isEmpty && previousLocal.inspections.isNotEmpty) {
          site.inspections = previousLocal.inspections;
        }

        remoteSites.add(site);
      }

      final remoteBirdObservations = await _loadBirdObservationsSafe(silent: true);
      for (final obs in remoteBirdObservations) {
        final previousLocal = localBirdsBeforeSync[obs.id];
        if (obs.photoPaths.isEmpty && previousLocal != null && previousLocal.photoPaths.isNotEmpty) {
          obs.photoPaths = previousLocal.photoPaths;
        }
      }

      // 3. Zachowaj lokalne niewysłane zmiany, jeśli coś nie zdążyło pójść na serwer.
      final stillLocalChanged = sites.where((s) => s.locallyChanged).toList();
      final stillLocalBirdsChanged = birdObservations.where((o) => o.locallyChanged).toList();

      sites
        ..clear()
        ..addAll(remoteSites)
        ..addAll(stillLocalChanged.where((local) => remoteSites.every((remote) => remote.id != local.id)));

      birdObservations
        ..clear()
        ..addAll(remoteBirdObservations)
        ..addAll(stillLocalBirdsChanged.where((local) => remoteBirdObservations.every((remote) => remote.id != local.id)));

      await saveLocal();
      if (!silent) showInfo('Synchronizacja zakończona. Pobrano obiekty: ${remoteSites.length}, obserwacje ptaków: ${remoteBirdObservations.length}.');
    } catch (e) {
      final msg = e.toString();
      if (!silent) {
        if (msg.contains('relation') || msg.contains('schema') || msg.contains('does not exist') || msg.contains('Could not find')) {
          showError('Błąd synchronizacji Supabase. Uruchom w Supabase aktualny plik supabase/schema.sql, potem spróbuj ponownie. Szczegóły: $e');
        } else if (msg.contains('JWT') || msg.contains('permission') || msg.contains('policy') || msg.contains('row-level security')) {
          showError('Błąd uprawnień Supabase/RLS. Sprawdź polityki w supabase/schema.sql. Szczegóły: $e');
        } else {
          showError('Błąd synchronizacji: $e');
        }
      }
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  void markUpdateDialogShown() {
    updateDialogShown = true;
  }

  Future<void> checkForUpdates({bool manual = false}) async {
    if (checkingUpdate) return;

    final hasJson = appUpdateJsonUrl.trim().isNotEmpty;
    final hasDirectApk = appUpdateApkUrl.trim().isNotEmpty;

    if (!hasJson) {
      if (manual && hasDirectApk) {
        showInfo('Brak adresu latest.json. Otwieram stronę pobierania.');
        await openUpdateDownload();
      } else if (manual) {
        showInfo('Brak adresu aktualizacji. Workflow powinien przekazać APP_UPDATE_JSON_URL do aplikacji.');
      }
      return;
    }

    checkingUpdate = true;
    if (manual) notifyListeners();

    try {
      final uri = Uri.parse(appUpdateJsonUrl.trim());
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 404) {
        if (manual) {
          if (hasDirectApk) {
            showInfo('Nie znaleziono latest.json. Otwieram stronę pobierania najnowszej wersji.');
            await openUpdateDownload();
          } else {
            showInfo('Nie znaleziono latest.json. Sprawdź, czy workflow utworzył Release i czy repo lub plik aktualizacji jest publicznie dostępny.');
          }
        }
        return;
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        if (manual) showError('Nie udało się sprawdzić aktualizacji. Kod HTTP: ${res.statusCode}');
        return;
      }

      final data = jsonDecode(res.body);
      if (data is! Map) {
        if (manual) showError('Plik aktualizacji ma zły format.');
        return;
      }

      final info = UpdateInfo.fromJson(Map<String, dynamic>.from(data));
      if (info.versionCode > appVersionCode && info.apkUrl.isNotEmpty) {
        availableUpdate = info;
        updateDialogShown = false;
        showInfo('Dostępna jest nowa wersja programu: ${info.versionName}. Kliknij ikonę aktualizacji na górze albo przycisk Pobierz.');
      } else if (manual) {
        showInfo('Masz aktualną wersję programu: $appVersionName ($appVersionCode).');
      }
    } catch (e) {
      if (manual) showError('Błąd sprawdzania aktualizacji: $e');
    } finally {
      checkingUpdate = false;
      notifyListeners();
    }
  }

  Future<void> openUpdateDownload() async {
    final url = availableUpdate?.apkUrl.trim().isNotEmpty == true
        ? availableUpdate!.apkUrl.trim()
        : appUpdateApkUrl.trim();

    if (url.isEmpty) {
      showError('Brak linku do APK.');
      return;
    }

    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      showError('Nie udało się otworzyć linku aktualizacji.');
    }
  }

  Future<void> signIn(String email, String password) async {
    if (!supabaseReady || client == null) {
      showError('Brak konfiguracji Supabase.');
      return;
    }

    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.trim().isEmpty) {
      showError('Wpisz email i hasło.');
      return;
    }

    try {
      final res = await client!.auth.signInWithPassword(
        email: cleanEmail,
        password: password.trim(),
      );
      currentUser = res.user;
      await _loadProfile();
      showInfo('Zalogowano.');
      notifyListeners();
      await sync();
    } catch (e) {
      showError('Błąd logowania: ${_friendlyAuthError(e)}');
    }
  }

  Future<void> register(String email, String password) async {
    if (!supabaseReady || client == null) {
      showError('Brak konfiguracji Supabase. Sprawdź SUPABASE_URL i SUPABASE_ANON_KEY w GitHub Secrets.');
      return;
    }

    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty) {
      showError('Wpisz email.');
      return;
    }
    if (cleanPassword.length < 6) {
      showError('Hasło powinno mieć minimum 6 znaków.');
      return;
    }

    try {
      AuthResponse res;
      try {
        res = await client!.auth.signUp(
          email: cleanEmail,
          password: cleanPassword,
          emailRedirectTo: oauthRedirectTo,
        );
      } catch (e) {
        // Jeśli w Supabase nie dodano redirect URL do allow list, rejestracja
        // nie powinna całkiem padać. Próbujemy jeszcze raz bez własnego redirectu.
        if (_looksLikeRedirectProblem(e)) {
          res = await client!.auth.signUp(
            email: cleanEmail,
            password: cleanPassword,
          );
        } else {
          rethrow;
        }
      }

      currentUser = res.user ?? client!.auth.currentUser;

      // Gdy w Supabase wyłączysz Confirm email, konto jest aktywne od razu.
      // Dodatkowo próbujemy od razu zalogować użytkownika, żeby nie musiał nic potwierdzać.
      if (client!.auth.currentSession == null) {
        try {
          final login = await client!.auth.signInWithPassword(
            email: cleanEmail,
            password: cleanPassword,
          );
          currentUser = login.user ?? currentUser;
        } catch (_) {
          // Jeśli Supabase nadal wymaga potwierdzenia emaila, nie wywracamy aplikacji.
        }
      }

      await _loadProfile();
      if (client!.auth.currentSession == null) {
        showInfo('Konto utworzone. Sprawdź email i kliknij link potwierdzający, potem zaloguj się w aplikacji.');
      } else {
        showInfo('Konto utworzone i zalogowano.');
      }
      notifyListeners();

      try {
        await sync();
      } catch (_) {
        // Konto zostało utworzone poprawnie. Błąd synchronizacji nie może być pokazany jako błąd rejestracji.
      }
    } catch (e) {
      if (_looksLikeEmailProviderProblem(e)) {
        showError('Rejestracja email/hasło jest wyłączona w Supabase. Włącz Authentication → Providers → Email.');
      } else {
        showError('Błąd rejestracji: ${_friendlyAuthError(e)}');
      }
    }
  }

  Future<void> sendPasswordReset(String email) async {
    if (!supabaseReady || client == null) {
      showError('Brak konfiguracji Supabase.');
      return;
    }

    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      showError('Najpierw wpisz email, potem kliknij reset hasła.');
      return;
    }

    try {
      try {
        await client!.auth.resetPasswordForEmail(
          cleanEmail,
          redirectTo: passwordResetRedirectTo,
        );
      } catch (e) {
        // Awaryjnie: jeśli Redirect URL nie jest dodany w Supabase, wyślij link
        // przez domyślny Site URL zamiast całkiem kończyć błędem.
        if (_looksLikeRedirectProblem(e)) {
          await client!.auth.resetPasswordForEmail(cleanEmail);
        } else {
          rethrow;
        }
      }
      showInfo('Wysłano link do resetu hasła na podany email.');
    } catch (e) {
      showError('Błąd resetu hasła: ${_friendlyAuthError(e)}');
    }
  }

  Future<void> signInWithGoogle() async {
    if (!supabaseReady || client == null) {
      showError('Brak konfiguracji Supabase.');
      return;
    }
    try {
      await client!.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: oauthRedirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: const {'prompt': 'select_account'},
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('provider is not enabled') || msg.contains('Unsupported provider')) {
        showError('Logowanie Google nie jest włączone w Supabase. Włącz Authentication → Providers → Google albo użyj logowania email/hasło.');
      } else {
        showError('Błąd Google OAuth: ${_friendlyAuthError(e)}');
      }
    }
  }


  bool _looksLikeRedirectProblem(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('redirect') ||
        msg.contains('not allowed') ||
        msg.contains('not in allow list') ||
        msg.contains('invalid url') ||
        msg.contains('invalid redirect');
  }

  bool _looksLikeEmailProviderProblem(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('email provider is disabled') ||
        msg.contains('email signups are disabled') ||
        msg.contains('signup disabled') ||
        msg.contains('email provider not enabled');
  }

  Future<void> diagnoseAuth() async {
    if (!supabaseReady || client == null) {
      showError('Supabase nie jest skonfigurowany w APK. Sprawdź sekrety GitHub: SUPABASE_URL i SUPABASE_ANON_KEY.');
      return;
    }

    try {
      final uri = Uri.parse('${_normalizeSupabaseUrl(supabaseUrl)}/auth/v1/settings');
      final response = await http.get(
        uri,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        showInfo('Połączenie z Supabase Auth działa. Jeżeli logowanie nadal nie działa, sprawdź w Supabase: Email provider, Confirm email, Redirect URLs i Google provider.');
      } else {
        showError('Supabase Auth odpowiada błędem ${response.statusCode}. Najczęściej to zły SUPABASE_ANON_KEY albo problem z projektem.');
      }
    } catch (e) {
      showError('Nie udało się połączyć z Supabase Auth: $e');
    }
  }

  String _friendlyAuthError(Object error) {
    final raw = error.toString();
    final msg = raw.toLowerCase();

    if (msg.contains('invalid login credentials')) {
      return 'nieprawidłowy email albo hasło.';
    }
    if (msg.contains('email not confirmed')) {
      return 'email nie został jeszcze potwierdzony.';
    }
    if (msg.contains('already registered') || msg.contains('user already exists')) {
      return 'konto z tym adresem email już istnieje.';
    }
    if (msg.contains('signup disabled') || msg.contains('email signups are disabled')) {
      return 'rejestracja email/hasło jest wyłączona w Supabase.';
    }
    if (msg.contains('redirect') || msg.contains('not allowed') || msg.contains('invalid url')) {
      return 'redirect URL nie jest dodany w Supabase. Dodaj io.supabase.flutter://login-callback/ w Authentication → URL Configuration.';
    }
    if (msg.contains('provider is not enabled') || msg.contains('unsupported provider')) {
      return 'logowanie Google nie jest włączone w Supabase.';
    }
    if (msg.contains('socket') || msg.contains('network') || msg.contains('failed host lookup')) {
      return 'brak połączenia z internetem.';
    }

    return raw;
  }

  Future<void> signOut() async {
    try {
      await client?.auth.signOut();
    } catch (_) {}
    currentUser = null;
    userRole = 'user';
    adminMode = false;
    await _loadLocal();
    notifyListeners();
  }

  Future<void> enableAdminWithPassword(String password) async {
    if (password == adminPassword) {
      adminMode = true;
      currentTab = 0;
      showInfo('Tryb administratora włączony.');
    } else {
      showError('Nieprawidłowe hasło administratora.');
    }
  }

  Future<void> disableAdmin() async {
    adminMode = false;
    if (currentTab > 1) currentTab = 0;
    notifyListeners();
  }

  Future<void> grantAdmin(String email) async {
    if (!isSuperAdmin) {
      showError('Tylko super administrator może nadawać uprawnienia.');
      return;
    }
    if (!supabaseReady || client == null) {
      showError('Brak Supabase.');
      return;
    }
    try {
      await client!.from('app_profiles').upsert({
        'email': email.trim(),
        'role': 'admin',
      }, onConflict: 'email');
      showInfo('Nadano uprawnienia admin dla $email');
    } catch (e) {
      showError('Błąd nadawania uprawnień: $e');
    }
  }

  String exportCsv() {
    final rows = <List<String>>[
      ['id', 'nazwa', 'typ', 'lat', 'lng', 'status', 'ptaki', 'wlasciciel', 'utworzono']
    ];
    for (final s in visibleSites()) {
      rows.add([
        s.id,
        s.name,
        s.type,
        s.latitude.toString(),
        s.longitude.toString(),
        s.technicalStatus,
        s.inspections.where((i) => i.birdsPresent).map((i) => i.birdSpecies).join('; '),
        s.ownerEmail,
        s.createdAt.toIso8601String(),
      ]);
    }
    return rows.map((r) => r.map(_csvCell).join(',')).join('\n');
  }

  String exportKml() {
    final b = StringBuffer();
    b.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    b.writeln('<kml xmlns="http://www.opengis.net/kml/2.2"><Document>');
    for (final s in visibleSites()) {
      b.writeln('<Placemark><name>${_xml(s.name)}</name><description>${_xml(s.type)}</description><Point><coordinates>${s.longitude},${s.latitude},0</coordinates></Point></Placemark>');
    }
    b.writeln('</Document></kml>');
    return b.toString();
  }

  String exportGpx() {
    final b = StringBuffer();
    b.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    b.writeln('<gpx version="1.1" creator="Ptasie Obserwacje">');
    for (final s in visibleSites()) {
      b.writeln('<wpt lat="${s.latitude}" lon="${s.longitude}"><name>${_xml(s.name)}</name><desc>${_xml(s.type)}</desc></wpt>');
    }
    b.writeln('</gpx>');
    return b.toString();
  }

  Future<void> importSimpleGpxKml(String text) async {
    final result = await importNestSitesFromText(text, fileName: 'wklejony GPX/KML');
    showInfo('Import: dodano ${result.added} budek, pominięto duplikaty ${result.skippedDuplicates}, błędne punkty ${result.skippedInvalid}.');
  }

  Future<void> importNestSitesFromGpxFile() async {
    if (importingGpx) return;

    if (!canCreateObjects) {
      showInfo('Import budek z GPX wymaga zalogowania albo trybu administratora.');
      return;
    }

    importingGpx = true;
    clearMessages();
    notifyListeners();

    try {
      final file = await pickGpxKmlFileFromDevice();

      if (file == null) {
        showInfo('Nie wybrano pliku GPX/KML.');
        return;
      }

      if (file.bytes.isEmpty) {
        showError('Nie udało się odczytać pliku ${file.name}.');
        return;
      }

      final text = decodePtasiaTextFileBytes(file.bytes, fileName: file.name);
      final result = await importNestSitesFromText(text, fileName: file.name);
      lastGpxImportAt = DateTime.now();

      if (result.added > 0 && supabaseReady && client != null && (loggedIn || isAdmin)) {
        await sync(silent: true);
      }

      showInfo(
        'GPX/KML: dodano ${result.added} budek z pliku ${file.name}. '
        'Pominięto duplikaty ${result.skippedDuplicates}, błędne punkty ${result.skippedInvalid}.',
      );
    } catch (e) {
      showError('Nie udało się wczytać pliku GPX: $e');
    } finally {
      importingGpx = false;
      notifyListeners();
    }
  }

  Future<GpxImportResult> importNestSitesFromText(String text, {String fileName = 'import.gpx'}) async {
    if (!canCreateObjects) {
      showInfo('Import budek wymaga zalogowania albo trybu administratora.');
      return const GpxImportResult();
    }

    final drafts = parseNestSiteDraftsFromGpxKml(text, fileName: fileName);
    if (drafts.isEmpty) {
      return const GpxImportResult(skippedInvalid: 1);
    }

    final distance = const Distance();
    final now = DateTime.now();
    var added = 0;
    var skippedDuplicates = 0;
    var skippedInvalid = 0;

    bool isDuplicate(GpxNestSiteDraft d) {
      final point = LatLng(d.latitude, d.longitude);
      return sites.any((site) {
        if (site.deleted) return false;
        final meters = distance.as(LengthUnit.Meter, point, LatLng(site.latitude, site.longitude));
        if (meters <= 6) return true;

        final sameName = d.name.trim().isNotEmpty &&
            site.name.trim().toLowerCase() == d.name.trim().toLowerCase();
        return sameName && meters <= 25;
      });
    }

    for (final d in drafts) {
      if (!_validLatLng(d.latitude, d.longitude)) {
        skippedInvalid++;
        continue;
      }
      if (isDuplicate(d)) {
        skippedDuplicates++;
        continue;
      }

      final site = NestSite(
        id: _uuid.v4(),
        name: d.name.trim().isEmpty ? 'Budka GPX ${added + 1}' : d.name.trim(),
        type: d.type.trim().isEmpty ? 'Budka lęgowa' : d.type.trim(),
        latitude: d.latitude,
        longitude: d.longitude,
        placeDescription: d.placeDescription,
        technicalStatus: 'Do kontroli',
        repairNeeded: false,
        notes: d.notes,
        ownerId: currentUser?.id ?? localGuestId ?? 'guest',
        ownerEmail: currentUser?.email ?? 'gość',
        reportStatus: loggedIn ? 'Zaimportowana z GPX' : 'Zaimportowana lokalnie',
        createdAt: now,
        updatedAt: now,
        locallyChanged: true,
      );

      sites.add(site);
      added++;
    }

    await saveLocal();
    notifyListeners();
    return GpxImportResult(
      added: added,
      skippedDuplicates: skippedDuplicates,
      skippedInvalid: skippedInvalid,
    );
  }
}

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';
String _xml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

class GpxImportResult {
  const GpxImportResult({
    this.added = 0,
    this.skippedDuplicates = 0,
    this.skippedInvalid = 0,
  });

  final int added;
  final int skippedDuplicates;
  final int skippedInvalid;
}

class GpxNestSiteDraft {
  const GpxNestSiteDraft({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.type = 'Budka lęgowa',
    this.placeDescription = '',
    this.notes = '',
  });

  final String name;
  final double latitude;
  final double longitude;
  final String type;
  final String placeDescription;
  final String notes;
}


String decodePtasiaTextFileBytes(List<int> bytes, {String fileName = ''}) {
  if (bytes.isEmpty) return '';

  final head = _asciiHead(bytes, 800);
  if (head.contains('windows-1250') || head.contains('cp1250')) {
    return _decodeCentralEuropean8Bit(bytes, windows1250: true);
  }
  if (head.contains('iso-8859-2') || head.contains('latin2') || head.contains('iso8859-2')) {
    return _decodeCentralEuropean8Bit(bytes, windows1250: false);
  }

  try {
    final utf = utf8.decode(bytes, allowMalformed: false);
    if (!_looksMojibake(utf)) return utf;
  } catch (_) {
    // Plik może być w Windows-1250 albo ISO-8859-2. To częste przy starszych GPX/KML.
  }

  final candidates = <String>[
    utf8.decode(bytes, allowMalformed: true),
    _decodeCentralEuropean8Bit(bytes, windows1250: true),
    _decodeCentralEuropean8Bit(bytes, windows1250: false),
  ];

  candidates.sort((a, b) => _decodeQualityScore(b).compareTo(_decodeQualityScore(a)));
  return candidates.first;
}

String _asciiHead(List<int> bytes, int maxLen) {
  final buffer = StringBuffer();
  final n = bytes.length < maxLen ? bytes.length : maxLen;

  for (var i = 0; i < n; i++) {
    final b = bytes[i];
    if (b >= 32 && b <= 126) {
      buffer.writeCharCode(b);
    } else {
      buffer.write(' ');
    }
  }

  return buffer.toString().toLowerCase();
}

bool _looksMojibake(String text) {
  return text.contains('�') ||
      text.contains('Å‚') ||
      text.contains('Å„') ||
      text.contains('Å›') ||
      text.contains('Åº') ||
      text.contains('Å¼') ||
      text.contains('Ä…') ||
      text.contains('Ä‡') ||
      text.contains('Ä™') ||
      text.contains('Ã³') ||
      text.contains('Â');
}

int _decodeQualityScore(String text) {
  var score = 0;

  const goodChars = 'ąćęłńóśźżĄĆĘŁŃÓŚŹŻ';
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    if (goodChars.contains(ch)) score += 6;
    if (ch == '\n' || ch == ' ') score += 1;
  }

  final lower = text.toLowerCase();
  for (final word in const [
    'budka',
    'budki',
    'gniazdo',
    'gniazda',
    'lęgowa',
    'lęgowy',
    'żołna',
    'łabędź',
    'bocian',
    'czapla',
    'sójka',
    'dzięcioł',
    'nazwa',
    'opis',
    'miejsce',
  ]) {
    if (lower.contains(word)) score += 20;
  }

  for (final bad in const ['�', 'Å‚', 'Å„', 'Å›', 'Åº', 'Å¼', 'Ä…', 'Ä‡', 'Ä™', 'Ã³', 'Â']) {
    score -= bad.allMatches(text).length * 40;
  }

  return score;
}

String _decodeCentralEuropean8Bit(List<int> bytes, {required bool windows1250}) {
  final buffer = StringBuffer();

  final map = windows1250 ? _windows1250PolishMap : _iso88592PolishMap;

  for (final b in bytes) {
    if (b == 0) continue;
    final mapped = map[b];
    if (mapped != null) {
      buffer.write(mapped);
    } else if (b < 128) {
      buffer.writeCharCode(b);
    } else {
      // Dla znaków innych niż polskie zostawiamy zachowanie zbliżone do Latin-1.
      // Najważniejsze jest poprawne zachowanie nazw typu Łódź, Gdańsk, Żołna.
      buffer.writeCharCode(b);
    }
  }

  return buffer.toString();
}

const Map<int, String> _windows1250PolishMap = {
  0x8C: 'Ś',
  0x8F: 'Ź',
  0x9C: 'ś',
  0x9F: 'ź',
  0xA3: 'Ł',
  0xA5: 'Ą',
  0xAF: 'Ż',
  0xB3: 'ł',
  0xB9: 'ą',
  0xBF: 'ż',
  0xC6: 'Ć',
  0xCA: 'Ę',
  0xD1: 'Ń',
  0xD3: 'Ó',
  0xE6: 'ć',
  0xEA: 'ę',
  0xF1: 'ń',
  0xF3: 'ó',
};

const Map<int, String> _iso88592PolishMap = {
  0xA1: 'Ą',
  0xA3: 'Ł',
  0xA6: 'Ś',
  0xAC: 'Ź',
  0xAF: 'Ż',
  0xB1: 'ą',
  0xB3: 'ł',
  0xB6: 'ś',
  0xBC: 'ź',
  0xBF: 'ż',
  0xC6: 'Ć',
  0xCA: 'Ę',
  0xD1: 'Ń',
  0xD3: 'Ó',
  0xE6: 'ć',
  0xEA: 'ę',
  0xF1: 'ń',
  0xF3: 'ó',
};

List<GpxNestSiteDraft> parseNestSiteDraftsFromGpxKml(String text, {String fileName = ''}) {
  final result = <GpxNestSiteDraft>[];
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  // GPX: bierzemy głównie waypointy, bo trackpointy potrafią mieć tysiące punktów trasy.
  final gpxPointRegex = RegExp(
    r'<(?:[a-zA-Z0-9_\-]+:)?(wpt|rtept)\b([^>]*)>([\s\S]*?)</(?:[a-zA-Z0-9_\-]+:)?\1>',
    caseSensitive: false,
  );

  var index = 1;
  for (final m in gpxPointRegex.allMatches(normalized)) {
    final attrs = m.group(2) ?? '';
    final body = m.group(3) ?? '';
    final lat = double.tryParse(_xmlAttr(attrs, 'lat'));
    final lon = double.tryParse(_xmlAttr(attrs, 'lon'));
    if (lat == null || lon == null || !_validLatLng(lat, lon)) continue;

    final rawName = _firstXmlTag(body, const ['name', 'cmt', 'desc']);
    final desc = _firstXmlTag(body, const ['desc', 'cmt']);
    final type = _guessNestType('$rawName\n$desc');
    final name = rawName.trim().isEmpty ? 'Budka GPX $index' : rawName.trim();

    result.add(GpxNestSiteDraft(
      name: name,
      type: type,
      latitude: lat,
      longitude: lon,
      placeDescription: desc.trim().isEmpty ? 'Import z pliku GPX ${fileName.trim()}'.trim() : desc.trim(),
      notes: 'Import z pliku GPX/KML: ${fileName.trim().isEmpty ? 'bez nazwy' : fileName.trim()}',
    ));
    index++;
  }

  if (result.isNotEmpty) return result;

  // Awaryjnie KML: pojedyncze Placemark/Point/coordinates.
  final placemarkRegex = RegExp(
    r'<(?:[a-zA-Z0-9_\-]+:)?Placemark\b[^>]*>([\s\S]*?)</(?:[a-zA-Z0-9_\-]+:)?Placemark>',
    caseSensitive: false,
  );
  final coordinatesRegex = RegExp(
    r'<(?:[a-zA-Z0-9_\-]+:)?coordinates\b[^>]*>\s*([-0-9\.]+)\s*,\s*([-0-9\.]+)(?:\s*,\s*[-0-9\.]*)?\s*</(?:[a-zA-Z0-9_\-]+:)?coordinates>',
    caseSensitive: false,
  );

  index = 1;
  for (final pm in placemarkRegex.allMatches(normalized)) {
    final body = pm.group(1) ?? '';
    final coords = coordinatesRegex.firstMatch(body);
    if (coords == null) continue;

    final lon = double.tryParse(coords.group(1) ?? '');
    final lat = double.tryParse(coords.group(2) ?? '');
    if (lat == null || lon == null || !_validLatLng(lat, lon)) continue;

    final rawName = _firstXmlTag(body, const ['name', 'description']);
    final desc = _firstXmlTag(body, const ['description']);
    final name = rawName.trim().isEmpty ? 'Budka KML $index' : rawName.trim();

    result.add(GpxNestSiteDraft(
      name: name,
      type: _guessNestType('$rawName\n$desc'),
      latitude: lat,
      longitude: lon,
      placeDescription: desc.trim().isEmpty ? 'Import z pliku KML ${fileName.trim()}'.trim() : desc.trim(),
      notes: 'Import z pliku GPX/KML: ${fileName.trim().isEmpty ? 'bez nazwy' : fileName.trim()}',
    ));
    index++;
  }

  return result;
}

String _xmlAttr(String attrs, String name) {
  final m = RegExp("$name\\s*=\\s*[\"']([^\"']+)[\"']", caseSensitive: false).firstMatch(attrs);
  return _decodeXml(m?.group(1) ?? '');
}

String _firstXmlTag(String body, List<String> names) {
  for (final name in names) {
    final re = RegExp(
      '<(?:[a-zA-Z0-9_\\-]+:)?$name\\b[^>]*>([\\s\\S]*?)</(?:[a-zA-Z0-9_\\-]+:)?$name>',
      caseSensitive: false,
    );
    final m = re.firstMatch(body);
    if (m != null) {
      return _decodeXml(_stripXmlTags(m.group(1) ?? '').trim());
    }
  }
  return '';
}

String _stripXmlTags(String value) {
  return value
      .replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _decodeXml(String value) {
  var text = value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");

  text = text.replaceAllMapped(
    RegExp(r'&#x([0-9a-fA-F]+);'),
    (m) {
      final code = int.tryParse(m.group(1) ?? '', radix: 16);
      return code == null ? m.group(0)! : String.fromCharCode(code);
    },
  );

  text = text.replaceAllMapped(
    RegExp(r'&#([0-9]+);'),
    (m) {
      final code = int.tryParse(m.group(1) ?? '');
      return code == null ? m.group(0)! : String.fromCharCode(code);
    },
  );

  return text.trim();
}

bool _validLatLng(double lat, double lng) {
  return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 && !(lat == 0 && lng == 0);
}

String _guessNestType(String text) {
  final t = text.toLowerCase();
  if (t.contains('dziupla natural')) return 'Dziupla naturalna';
  if (t.contains('dziupla sztucz')) return 'Dziupla sztuczna';
  if (t.contains('karmnik')) return 'Karmnik';
  if (t.contains('schronienie')) return 'Schronienie';
  if (t.contains('budka') || t.contains('nest') || t.contains('box')) return 'Budka lęgowa';
  return 'Budka lęgowa';
}


bool _ensureLoggedInForChanges(BuildContext context, AppState state, String action) {
  final normalizedAction = action.toLowerCase();

  if (ptasiaSplitReadOnly) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ptasia Strefa jest tylko do oglądania. Dodawanie i edycja są wyłączone.')),
    );
    return false;
  }

  if (ptasiaSplitBudkiOnly && normalizedAction.contains('obserw')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Obserwacje są w osobnej aplikacji Ptasie Obserwacje.')),
    );
    return false;
  }

  if (ptasiaSplitObservationsOnly &&
      (normalizedAction.contains('budk') ||
       normalizedAction.contains('obiekt') ||
       normalizedAction.contains('czysz') ||
       normalizedAction.contains('napraw'))) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Budki, czyszczenie i naprawy są w osobnej aplikacji Ptasie Budki.')),
    );
    return false;
  }

  if (state.canCreateObjects) return true;

  state.showInfo('Jesteś w trybie Gość. Możesz oglądać obiekty na mapie, ale $action wymaga zalogowania.');
  Future.microtask(() {
    if (context.mounted) _showAccountDialog(context);
  });
  return false;
}

Future<void> _addPhotoToExistingSite(BuildContext context, NestSite site, ImageSource source) async {
  final state = AppStateScope.of(context);
  if (!state.canEdit(site)) {
    state.showInfo('Gość może tylko oglądać obiekty. Dodawanie zdjęć wymaga zalogowania i uprawnień do obiektu.');
    return;
  }

  try {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 82, maxWidth: 1800);
    if (picked == null) return;

    site.photoPaths.add(picked.path);
    await state.updateSite(site);

    if (!context.mounted) return;
    state.showInfo('Dodano zdjęcie do obiektu.');
  } catch (e) {
    state.showError('Nie udało się dodać zdjęcia: $e');
  }
}

Future<void> _openGoogleMapsTo(NestSite site) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${site.latitude},${site.longitude}&travelmode=walking',
  );

  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    final fallback = Uri.parse('https://www.google.com/maps/search/?api=1&query=${site.latitude},${site.longitude}');
    await launchUrl(fallback, mode: LaunchMode.externalApplication);
  }
}


Future<LatLng?> _getLocationWithPrompt(BuildContext context, AppState state) async {
  try {
    return await state.currentLocation();
  } catch (e) {
    final message = e.toString();
    if (!context.mounted) return null;

    final lower = message.toLowerCase();
    final needsLocationSettings = lower.contains('wyłączona') ||
        lower.contains('location services') ||
        lower.contains('service');

    final needsAppSettings = lower.contains('zablokowany') ||
        lower.contains('deniedforever') ||
        lower.contains('na stałe');

    if (needsLocationSettings || needsAppSettings) {
      final open = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(needsLocationSettings ? 'Włączyć GPS?' : 'Nadać zgodę na GPS?'),
          content: Text(
            needsLocationSettings
                ? 'Ta funkcja potrzebuje lokalizacji. Włącz GPS w ustawieniach telefonu i wróć do aplikacji.'
                : 'Ta funkcja potrzebuje zgody na lokalizację. Otwórz ustawienia aplikacji i nadaj zgodę GPS.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Otwórz ustawienia')),
          ],
        ),
      );

      if (open == true) {
        if (needsLocationSettings) {
          await Geolocator.openLocationSettings();
        } else {
          await Geolocator.openAppSettings();
        }
      }
      return null;
    }

    state.showError('Nie udało się pobrać GPS: $message');
    return null;
  }
}

bool _siteNeedsRepair(NestSite site) {
  final status = site.technicalStatus.toLowerCase();
  return site.repairNeeded ||
      site.damageDescription.trim().isNotEmpty ||
      status.contains('uszkodz') ||
      status.contains('zabrudz') ||
      status.contains('spad') ||
      status.contains('zalanie') ||
      status.contains('napraw');
}

Inspection? _latestCleanedInspection(NestSite site) {
  final cleaned = site.inspections.where((i) => i.cleaned && !i.deleted).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return cleaned.isEmpty ? null : cleaned.first;
}

DateTime _cleaningSeasonStart(DateTime now) {
  final thisYearStart = DateTime(now.year, 10, 16);
  final previousSeasonEndExclusive = DateTime(now.year, 3, 1);
  if (!now.isBefore(thisYearStart)) return thisYearStart;
  if (now.isBefore(previousSeasonEndExclusive)) return DateTime(now.year - 1, 10, 16);
  return thisYearStart;
}

DateTime _cleaningSeasonEndExclusive(DateTime start) => DateTime(start.year + 1, 3, 1);

bool _isCleaningPeriod(DateTime now) {
  final start = _cleaningSeasonStart(now);
  final end = _cleaningSeasonEndExclusive(start);
  return !now.isBefore(start) && now.isBefore(end);
}

bool _cleanedInSelectedSeason(NestSite site, DateTime now) {
  final start = _cleaningSeasonStart(now);
  final end = _cleaningSeasonEndExclusive(start);
  return site.inspections.any((i) => i.cleaned && !i.deleted && !i.date.isBefore(start) && i.date.isBefore(end));
}

int _daysBetweenDates(DateTime from, DateTime to) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(to.year, to.month, to.day);
  return max(0, b.difference(a).inDays);
}

String _cleaningCounterText(DateTime now) {
  final start = _cleaningSeasonStart(now);
  final endExclusive = _cleaningSeasonEndExclusive(start);
  final endVisible = endExclusive.subtract(const Duration(days: 1));
  final format = DateFormat('dd.MM.yyyy');

  if (_isCleaningPeriod(now)) {
    final days = _daysBetweenDates(now, endExclusive);
    return 'Trwa okres czyszczenia. Do końca zostało $days dni (do ${format.format(endVisible)}).';
  }

  final days = _daysBetweenDates(now, start);
  return 'Do okresu czyszczenia zostało $days dni. Start: ${format.format(start)}.';
}

class UpdateInfo {
  UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    this.notes = '',
  });

  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String notes;

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    int parseCode(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return UpdateInfo(
      versionCode: parseCode(json['versionCode'] ?? json['version_code'] ?? json['build']),
      versionName: (json['versionName'] ?? json['version_name'] ?? json['version'] ?? '').toString(),
      apkUrl: (json['apkUrl'] ?? json['apk_url'] ?? json['url'] ?? json['downloadUrl'] ?? '').toString(),
      notes: (json['notes'] ?? json['opis'] ?? json['changelog'] ?? '').toString(),
    );
  }
}

class NearbySite {
  const NearbySite({
    required this.site,
    required this.distanceMeters,
  });

  final NestSite site;
  final double distanceMeters;

  String get distanceText {
    if (distanceMeters < 10) return '${distanceMeters.toStringAsFixed(1)} m';
    return '${distanceMeters.round()} m';
  }
}



class ClangaObservationDraft {
  const ClangaObservationDraft({
    required this.externalId,
    required this.externalUrl,
    required this.species,
    required this.latitude,
    required this.longitude,
    required this.observedAt,
    required this.count,
    required this.placeDescription,
    required this.behaviour,
    required this.notes,
    required this.sensitive,
  });

  final String externalId;
  final String externalUrl;
  final String species;
  final double latitude;
  final double longitude;
  final DateTime observedAt;
  final int count;
  final String placeDescription;
  final String behaviour;
  final String notes;
  final bool sensitive;
}

Future<List<ClangaObservationDraft>> fetchClangaObservationDrafts({int limit = 25}) async {
  final listHtml = await _fetchFirstWorkingClangaList();
  final links = _extractClangaNewsLinks(listHtml).take(limit).toList();
  final drafts = <ClangaObservationDraft>[];

  // Jeżeli Clanga zmieni układ strony i nie znajdziemy linków, próbujemy
  // odczytać aktualną stronę jako pojedynczy wpis zamiast wywalać import.
  if (links.isEmpty) {
    final fallback = _parseClangaDetail('list-${DateTime.now().millisecondsSinceEpoch}', 'https://clanga.com/index.php/news/show//pl/', listHtml);
    if (fallback != null) drafts.add(fallback);
    return drafts;
  }

  for (final link in links) {
    try {
      final html = await _fetchClangaHtml(link.url, timeout: const Duration(seconds: 14));
      final draft = _parseClangaDetail(link.id, link.url, html);
      if (draft != null) drafts.add(draft);
    } catch (_) {
      // Pojedyncza obserwacja z Clanga nie może wywalić całego importu.
    }
  }

  return drafts;
}

const Map<String, String> _clangaHeaders = {
  'User-Agent': 'PtasiaMapa/0.6.5 Android Flutter; kontakt: bartoszlawicki@gmail.com',
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'pl,en;q=0.8',
  'Connection': 'close',
};

class _ClangaLink {
  const _ClangaLink(this.id, this.url);
  final String id;
  final String url;
}

Future<String> _fetchFirstWorkingClangaList() async {
  const urls = [
    // Najpierw HTTP. Na części telefonów HTTPS Clanga potrafi rzucać
    // HandshakeException, a HTTP działa poprawnie.
    'http://www.clanga.com/index.php/news/show//pl/',
    'http://clanga.com/index.php/news/show//pl/',
    'http://www.clanga.com/index.php/home/show',
    'http://clanga.com/index.php/home/show',
    // Fallback HTTPS, z akceptacją problematycznego certyfikatu tylko dla Clanga.
    'https://www.clanga.com/index.php/news/show//pl/',
    'https://clanga.com/index.php/news/show//pl/',
    'https://www.clanga.com/index.php/home/show',
    'https://clanga.com/index.php/home/show',
  ];

  Object? lastError;
  for (final url in urls) {
    try {
      return await _fetchClangaHtml(url, timeout: const Duration(seconds: 16));
    } catch (e) {
      lastError = e;
    }
  }

  throw Exception('Clanga nie odpowiedziała. Ostatni błąd: $lastError');
}

Future<String> _fetchClangaHtml(String url, {Duration timeout = const Duration(seconds: 14)}) async {
  Object? lastError;

  for (final candidate in _clangaUrlVariants(url)) {
    try {
      final html = await _fetchClangaHtmlWithIo(candidate).timeout(timeout);
      if (html.trim().isNotEmpty) return html;
      lastError = 'pusta odpowiedź z $candidate';
    } catch (e) {
      lastError = e;
    }
  }

  throw Exception('Clanga nie odpowiedziała. Ostatni błąd: $lastError');
}

List<String> _clangaUrlVariants(String raw) {
  var value = raw.trim().replaceAll('&amp;', '&');
  if (value.startsWith('//')) value = 'http:$value';

  final candidates = <String>[];
  void add(String url) {
    if (url.isEmpty) return;
    if (!candidates.contains(url)) candidates.add(url);
  }

  if (value.startsWith('http://') || value.startsWith('https://')) {
    // HTTP jako pierwszy, bo to omija problem TLS/handshake na niektórych Androidach.
    add(value.replaceFirst('https://', 'http://'));
    add(value.replaceFirst('http://', 'https://'));
  } else {
    if (!value.startsWith('/')) value = '/$value';
    add('http://www.clanga.com$value');
    add('http://clanga.com$value');
    add('https://www.clanga.com$value');
    add('https://clanga.com$value');
  }

  final snapshot = List<String>.from(candidates);
  for (final url in snapshot) {
    if (url.contains('://www.clanga.com')) {
      add(url.replaceFirst('://www.clanga.com', '://clanga.com'));
    } else if (url.contains('://clanga.com')) {
      add(url.replaceFirst('://clanga.com', '://www.clanga.com'));
    }
  }

  return candidates;
}

Future<String> _fetchClangaHtmlWithIo(String url) async {
  final uri = Uri.parse(url);
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..badCertificateCallback = (cert, host, port) => host.endsWith('clanga.com');

  try {
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    _clangaHeaders.forEach((key, value) {
      request.headers.set(key, value);
    });

    final response = await request.close();

    if (response.isRedirect) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      throw Exception('HTTP ${response.statusCode} redirect do ${location ?? 'brak adresu'}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode} dla $url');
    }

    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }

    return decodePtasiaTextFileBytes(bytes, fileName: url);
  } finally {
    client.close(force: true);
  }
}

List<_ClangaLink> _extractClangaNewsLinks(String html) {
  final found = <String, _ClangaLink>{};
  final patterns = [
    RegExp(r'''href\s*=\s*["\']([^"\']*?/index\.php/news/show/(\d+)(?:/pl/)?)''', caseSensitive: false),
    RegExp(r'''href\s*=\s*["\']([^"\']*?news/show/(\d+)(?:/pl/)?)''', caseSensitive: false),
  ];

  for (final pattern in patterns) {
    for (final m in pattern.allMatches(html)) {
      final rawUrl = m.group(1) ?? '';
      final id = m.group(2) ?? '';
      if (id.isEmpty) continue;
      final url = _absoluteClangaUrl(rawUrl);
      found[id] = _ClangaLink(id, url);
    }
  }

  return found.values.toList();
}

String _absoluteClangaUrl(String raw) {
  var value = raw.trim().replaceAll('&amp;', '&');
  if (value.startsWith('//')) value = 'http:$value';
  if (value.startsWith('http://') || value.startsWith('https://')) {
    // Zostawiamy HTTP, jeśli taki link był na stronie. To ważne dla telefonów,
    // na których HTTPS Clanga kończy się HandshakeException.
    return value;
  }
  if (!value.startsWith('/')) value = '/$value';
  return 'http://www.clanga.com$value';
}

ClangaObservationDraft? _parseClangaDetail(String id, String url, String html) {
  final text = _htmlToPlainText(html);
  if (text.trim().isEmpty) return null;

  final species = _guessSpeciesFromClangaText(text);
  if (species.trim().isEmpty) return null;

  final place = _extractClangaPlace(text);
  final coordinates = _extractCoordinatesFromText(text) ?? _guessPolandLatLngFromText('$place\n$text');
  if (coordinates == null) return null;

  final observedAt = _extractClangaDate(text) ?? DateTime.now();
  final count = _extractClangaCount(text);
  final autoSensitive = isRareBirdSpecies('$species\n$text') || _looksLikeClangaRareRecord(text);
  final sourceNote = 'Źródło: Clanga.com. Import automatyczny z publicznej strony obserwacji. Link: $url';
  final approxNote = _extractCoordinatesFromText(text) == null
      ? 'Lokalizacja może być przybliżona na podstawie opisu miejsca. '
      : '';

  return ClangaObservationDraft(
    externalId: 'clanga-$id',
    externalUrl: url,
    species: species,
    latitude: coordinates.latitude,
    longitude: coordinates.longitude,
    observedAt: observedAt,
    count: count,
    placeDescription: place.isEmpty ? 'Clanga — lokalizacja z opisu' : place,
    behaviour: '',
    notes: '$approxNote$sourceNote\n\n${_shortenText(text, 900)}',
    sensitive: autoSensitive,
  );
}

String _htmlToPlainText(String html) {
  var text = html;
  text = text.replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ');
  text = text.replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ');
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</(p|div|li|tr|h1|h2|h3|td)>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
  text = _decodeHtmlEntities(text);
  text = text.replaceAll(RegExp(r'[ \t\x0B\f\r]+'), ' ');
  text = text.replaceAll(RegExp(r'\n\s+'), '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

String _decodeHtmlEntities(String value) {
  var s = value;
  const named = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&quot;': '"',
    '&#039;': "'",
    '&apos;': "'",
    '&lt;': '<',
    '&gt;': '>',
    '&oacute;': 'ó',
    '&Oacute;': 'Ó',
    '&aogon;': 'ą',
    '&Aogon;': 'Ą',
    '&cacute;': 'ć',
    '&Cacute;': 'Ć',
    '&eogon;': 'ę',
    '&Eogon;': 'Ę',
    '&lstrok;': 'ł',
    '&Lstrok;': 'Ł',
    '&nacute;': 'ń',
    '&Nacute;': 'Ń',
    '&sacute;': 'ś',
    '&Sacute;': 'Ś',
    '&zacute;': 'ź',
    '&Zacute;': 'Ź',
    '&zdot;': 'ż',
    '&Zdot;': 'Ż',
  };
  named.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m.group(1) ?? '');
    if (code == null) return m.group(0) ?? '';
    return String.fromCharCode(code);
  });
  s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    final code = int.tryParse(m.group(1) ?? '', radix: 16);
    if (code == null) return m.group(0) ?? '';
    return String.fromCharCode(code);
  });
  return s;
}

String _guessSpeciesFromClangaText(String text) {
  final normalizedText = _normalizeSpeciesForMatch(text);

  for (final species in birdSpecies) {
    final pieces = species.split('—').map((e) => e.trim()).where((e) => e.isNotEmpty);
    for (final part in pieces) {
      final n = _normalizeSpeciesForMatch(part);
      if (n.length >= 4 && normalizedText.contains(n)) return canonicalBirdSpeciesName(species);
    }
  }

  final plLatin = RegExp(
    r'([A-ZĄĆĘŁŃÓŚŹŻ][a-ząćęłńóśźżA-ZĄĆĘŁŃÓŚŹŻ\- ]{2,40})\s*,\s*([A-Z][a-z]+\s+[a-z]+)',
  ).firstMatch(text);
  if (plLatin != null) {
    final pl = (plLatin.group(1) ?? '').trim();
    final latin = (plLatin.group(2) ?? '').trim();
    if (pl.isNotEmpty && latin.isNotEmpty) return canonicalBirdSpeciesName('$pl — $latin');
  }

  final latinOnly = RegExp(r'\b([A-Z][a-z]+\s+[a-z]+)\b').firstMatch(text);
  if (latinOnly != null) return canonicalBirdSpeciesName(latinOnly.group(1)!.trim());

  final lines = text.split('\n').map((e) => e.trim()).where((e) => e.length > 3).toList();
  for (final line in lines) {
    final l = line.toLowerCase();
    if (l.contains('clanga') || l.contains('obserwacje') || l.contains('strona główna')) continue;
    if (line.length < 60 && !line.contains('http') && !line.contains('Copyright')) return canonicalBirdSpeciesName(line);
  }

  return '';
}

String _extractClangaPlace(String text) {
  final oneLine = text.replaceAll('\n', ' ');
  final patterns = [
    RegExp(r'([^\.\n]{3,140}\bwoj\.[^\.\n]{0,60})', caseSensitive: false),
    RegExp(r'([^\.\n]{3,140}\bpow\.[^\.\n]{0,60})', caseSensitive: false),
    RegExp(r'([^\.\n]{3,140}\b(?:zb\.|stawy|jez\.|jezioro|rzeka|ujście|mierzeja|wyspa|dolina|zalew|port)\b[^\.\n]{0,80})', caseSensitive: false),
  ];

  for (final p in patterns) {
    final m = p.firstMatch(oneLine);
    if (m == null) continue;
    var place = (m.group(1) ?? '').trim();
    place = place.replaceAll(RegExp(r'\s+'), ' ');
    place = place.split(RegExp(r'obs\./info|obserwator|ptak|zobacz foto', caseSensitive: false)).first.trim();
    if (place.length > 160) place = place.substring(0, 160).trim();
    if (place.length >= 3) return place;
  }

  return '';
}

LatLng? _extractCoordinatesFromText(String text) {
  final patterns = [
    RegExp(r'\b(4[9]|5[0-5])[,.](\d{3,8})\s*[,; ]\s*(1[4-9]|2[0-4])[,.](\d{3,8})\b'),
    RegExp(r'\bN\s*(4[9]|5[0-5])[,.](\d{3,8})\s*[,; ]\s*E\s*(1[4-9]|2[0-4])[,.](\d{3,8})\b', caseSensitive: false),
  ];

  for (final p in patterns) {
    final m = p.firstMatch(text);
    if (m == null) continue;
    final lat = double.tryParse('${m.group(1)}.${m.group(2)}');
    final lng = double.tryParse('${m.group(3)}.${m.group(4)}');
    if (lat != null && lng != null && lat >= 49 && lat <= 55.2 && lng >= 14 && lng <= 24.5) {
      return LatLng(lat, lng);
    }
  }

  return null;
}

LatLng? _guessPolandLatLngFromText(String text) {
  final n = _normalizeSpeciesForMatch(text);
  final places = <String, LatLng>{
    'zb turawski': LatLng(50.728, 18.130),
    'zbiornik turawski': LatLng(50.728, 18.130),
    'turawa': LatLng(50.741, 18.107),
    'tarnobrzeg': LatLng(50.573, 21.679),
    'darlowo': LatLng(54.421, 16.410),
    'darłowo': LatLng(54.421, 16.410),
    'gdansk': LatLng(54.352, 18.646),
    'gdańsk': LatLng(54.352, 18.646),
    'gdynia': LatLng(54.519, 18.530),
    'sopot': LatLng(54.441, 18.560),
    'elblag': LatLng(54.157, 19.404),
    'elbląg': LatLng(54.157, 19.404),
    'warszawa': LatLng(52.229, 21.012),
    'krakow': LatLng(50.064, 19.945),
    'kraków': LatLng(50.064, 19.945),
    'wroclaw': LatLng(51.107, 17.038),
    'wrocław': LatLng(51.107, 17.038),
    'poznan': LatLng(52.407, 16.925),
    'poznań': LatLng(52.407, 16.925),
    'lublin': LatLng(51.246, 22.568),
    'bialystok': LatLng(53.132, 23.168),
    'białystok': LatLng(53.132, 23.168),
    'olsztyn': LatLng(53.778, 20.480),
    'szczecin': LatLng(53.428, 14.553),
    'rzeszow': LatLng(50.041, 21.999),
    'rzeszów': LatLng(50.041, 21.999),
    'opole': LatLng(50.675, 17.921),
    'katowice': LatLng(50.264, 19.023),
    'kielce': LatLng(50.866, 20.628),
    'lodz': LatLng(51.759, 19.456),
    'łódź': LatLng(51.759, 19.456),
    'torun': LatLng(53.013, 18.598),
    'toruń': LatLng(53.013, 18.598),
    'bydgoszcz': LatLng(53.123, 18.008),
    'zielona gora': LatLng(51.935, 15.506),
    'zielona góra': LatLng(51.935, 15.506),
    'gorzow': LatLng(52.736, 15.228),
    'gorzów': LatLng(52.736, 15.228),
    'woj opolskie': LatLng(50.675, 17.921),
    'woj podkarpackie': LatLng(50.041, 21.999),
    'woj pomorskie': LatLng(54.352, 18.646),
    'woj zachodniopomorskie': LatLng(53.428, 14.553),
    'woj warminsko mazurskie': LatLng(53.778, 20.480),
    'woj warmińsko mazurskie': LatLng(53.778, 20.480),
    'woj podlaskie': LatLng(53.132, 23.168),
    'woj lubelskie': LatLng(51.246, 22.568),
    'woj mazowieckie': LatLng(52.229, 21.012),
    'woj wielkopolskie': LatLng(52.407, 16.925),
    'woj dolnoslaskie': LatLng(51.107, 17.038),
    'woj dolnośląskie': LatLng(51.107, 17.038),
    'woj slaskie': LatLng(50.264, 19.023),
    'woj śląskie': LatLng(50.264, 19.023),
    'woj malopolskie': LatLng(50.064, 19.945),
    'woj małopolskie': LatLng(50.064, 19.945),
    'woj swietokrzyskie': LatLng(50.866, 20.628),
    'woj świętokrzyskie': LatLng(50.866, 20.628),
    'woj lodzkie': LatLng(51.759, 19.456),
    'woj łódzkie': LatLng(51.759, 19.456),
    'woj kujawsko pomorskie': LatLng(53.013, 18.598),
    'woj lubuskie': LatLng(52.736, 15.228),
  };

  for (final entry in places.entries) {
    if (n.contains(_normalizeSpeciesForMatch(entry.key))) return entry.value;
  }

  return null;
}

DateTime? _extractClangaDate(String text) {
  final m = RegExp(r'\b([0-3]?\d)[\.\-/ ]([01]?\d)[\.\-/ ]((?:20)?\d{2})\b').firstMatch(text);
  if (m == null) return null;
  final day = int.tryParse(m.group(1) ?? '');
  final month = int.tryParse(m.group(2) ?? '');
  var year = int.tryParse(m.group(3) ?? '');
  if (day == null || month == null || year == null) return null;
  if (year < 100) year += 2000;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day, 12);
}

int _extractClangaCount(String text) {
  final m = RegExp(r'\b(\d{1,4})\s*(?:os\.|osob|ad\.|juv\.|subad\.|imm\.|samiec|samica)?\b', caseSensitive: false).firstMatch(text);
  final count = int.tryParse(m?.group(1) ?? '') ?? 1;
  if (count < 1 || count > 10000) return 1;
  return count;
}

bool _looksLikeClangaRareRecord(String text) {
  final n = _normalizeSpeciesForMatch(text);
  const rareWords = [
    'pierwsze stwierdzenie',
    'komisja faunistyczna',
    'podlegajacych weryfikacji',
    'rzadki',
    'rzadka',
    'rare',
    'orlica',
    'pallas',
    'ichthyaetus',
    'blyth',
    'blythi',
    'clanga',
    'glareola',
    'pastor roseus',
    'steryna',
  ];
  for (final word in rareWords) {
    if (n.contains(_normalizeSpeciesForMatch(word))) return true;
  }
  return false;
}

String _shortenText(String text, int maxChars) {
  final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (clean.length <= maxChars) return clean;
  return '${clean.substring(0, maxChars).trim()}…';
}

class BirdObservation {
  BirdObservation({
    required this.id,
    required this.species,
    required this.latitude,
    required this.longitude,
    required this.observedAt,
    this.count = 1,
    this.placeDescription = '',
    this.behaviour = '',
    this.notes = '',
    this.sensitive = false,
    this.hiddenFromUsers = false,
    this.deleted = false,
    this.ownerId = '',
    this.ownerEmail = '',
    this.source = 'Ptasie Obserwacje',
    this.externalId = '',
    this.externalUrl = '',
    required this.createdAt,
    required this.updatedAt,
    this.locallyChanged = false,
    List<String>? photoPaths,
  }) : photoPaths = photoPaths ?? [];

  String id;
  String species;
  double latitude;
  double longitude;
  DateTime observedAt;
  int count;
  String placeDescription;
  String behaviour;
  String notes;
  bool sensitive;
  bool hiddenFromUsers;
  bool deleted;
  String ownerId;
  String ownerEmail;
  String source;
  String externalId;
  String externalUrl;
  DateTime createdAt;
  DateTime updatedAt;
  bool locallyChanged;
  List<String> photoPaths;

  String get shortSpecies => birdSpeciesPolishName(species);
  String get polishSpeciesName => birdSpeciesPolishName(species);
  String get latinSpeciesName => birdSpeciesLatinName(species);
  String get fullSpeciesName => birdSpeciesFullName(species);

  Map<String, dynamic> toJson() => {
        'id': id,
        'species': species,
        'latitude': latitude,
        'longitude': longitude,
        'observedAt': observedAt.toIso8601String(),
        'count': count,
        'placeDescription': placeDescription,
        'behaviour': behaviour,
        'notes': notes,
        'sensitive': sensitive,
        'hiddenFromUsers': hiddenFromUsers,
        'deleted': deleted,
        'ownerId': ownerId,
        'ownerEmail': ownerEmail,
        'source': source,
        'externalId': externalId,
        'externalUrl': externalUrl,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'locallyChanged': locallyChanged,
        'photoPaths': photoPaths,
      };

  factory BirdObservation.fromJson(Map<String, dynamic> j) => BirdObservation(
        id: _string(j['id']),
        species: canonicalBirdSpeciesName(_string(j['species'], fallback: birdSpecies.first)),
        latitude: _double(j['latitude']),
        longitude: _double(j['longitude']),
        observedAt: _date(j['observedAt']),
        count: max(1, _int(j['count'])),
        placeDescription: _string(j['placeDescription']),
        behaviour: _string(j['behaviour']),
        notes: _string(j['notes']),
        sensitive: _bool(j['sensitive']),
        hiddenFromUsers: _bool(j['hiddenFromUsers']),
        deleted: _bool(j['deleted']),
        ownerId: _string(j['ownerId']),
        ownerEmail: _string(j['ownerEmail']),
        source: _string(j['source'], fallback: 'Ptasie Obserwacje'),
        externalId: _string(j['externalId']),
        externalUrl: _string(j['externalUrl']),
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
        locallyChanged: _bool(j['locallyChanged']),
        photoPaths: _stringList(j['photoPaths']),
      );

  Map<String, dynamic> toServerMap() => {
        'id': id,
        'species': species,
        'latitude': latitude,
        'longitude': longitude,
        'observed_at': observedAt.toIso8601String(),
        'count': count,
        'place_description': placeDescription,
        'behaviour': behaviour,
        'notes': notes,
        'sensitive': sensitive,
        'hidden_from_users': hiddenFromUsers,
        'deleted': deleted,
        'owner_id': ownerId,
        'owner_email': ownerEmail,
        'source': source,
        'external_id': externalId,
        'external_url': externalUrl,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'photo_urls': photoPaths,
      };

  factory BirdObservation.fromServerMap(Map<String, dynamic> j) => BirdObservation(
        id: _string(j['id']),
        species: canonicalBirdSpeciesName(_string(j['species'], fallback: birdSpecies.first)),
        latitude: _double(j['latitude']),
        longitude: _double(j['longitude']),
        observedAt: _date(j['observed_at']),
        count: max(1, _int(j['count'])),
        placeDescription: _string(j['place_description']),
        behaviour: _string(j['behaviour']),
        notes: _string(j['notes']),
        sensitive: _bool(j['sensitive']),
        hiddenFromUsers: _bool(j['hidden_from_users']),
        deleted: _bool(j['deleted']),
        ownerId: _string(j['owner_id']),
        ownerEmail: _string(j['owner_email']),
        source: _string(j['source'], fallback: 'Ptasie Obserwacje'),
        externalId: _string(j['external_id']),
        externalUrl: _string(j['external_url']),
        createdAt: _date(j['created_at']),
        updatedAt: _date(j['updated_at']),
        photoPaths: _stringList(j['photo_urls']),
      );
}

class NestSite {
  NestSite({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.placeDescription = '',
    this.technicalStatus = 'Dobry',
    this.repairNeeded = false,
    this.damageDescription = '',
    this.notes = '',
    this.reportStatus = 'Zgłoszona',
    this.deleteRequested = false,
    this.deleteReason = '',
    this.hiddenFromUsers = false,
    this.deleted = false,
    this.ownerId = '',
    this.ownerEmail = '',
    this.source = 'Ptasie Obserwacje',
    this.externalId = '',
    this.externalUrl = '',
    required this.createdAt,
    required this.updatedAt,
    this.locallyChanged = false,
    List<String>? photoPaths,
    List<Inspection>? inspections,
  })  : photoPaths = photoPaths ?? [],
        inspections = inspections ?? [];

  String id;
  String name;
  String type;
  double latitude;
  double longitude;
  String placeDescription;
  String technicalStatus;
  bool repairNeeded;
  String damageDescription;
  String notes;
  String reportStatus;
  bool deleteRequested;
  String deleteReason;
  bool hiddenFromUsers;
  bool deleted;
  String ownerId;
  String ownerEmail;
  String source;
  String externalId;
  String externalUrl;
  DateTime createdAt;
  DateTime updatedAt;
  bool locallyChanged;
  List<String> photoPaths;
  List<Inspection> inspections;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'latitude': latitude,
        'longitude': longitude,
        'placeDescription': placeDescription,
        'technicalStatus': technicalStatus,
        'repairNeeded': repairNeeded,
        'damageDescription': damageDescription,
        'notes': notes,
        'reportStatus': reportStatus,
        'deleteRequested': deleteRequested,
        'deleteReason': deleteReason,
        'hiddenFromUsers': hiddenFromUsers,
        'deleted': deleted,
        'ownerId': ownerId,
        'ownerEmail': ownerEmail,
        'source': source,
        'externalId': externalId,
        'externalUrl': externalUrl,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'locallyChanged': locallyChanged,
        'photoPaths': photoPaths,
        'inspections': inspections.map((e) => e.toJson()).toList(),
      };

  factory NestSite.fromJson(Map<String, dynamic> j) => NestSite(
        id: _string(j['id']),
        name: _string(j['name'], fallback: 'Obiekt'),
        type: _string(j['type'], fallback: 'Budka lęgowa'),
        latitude: _double(j['latitude']),
        longitude: _double(j['longitude']),
        placeDescription: _string(j['placeDescription']),
        technicalStatus: _string(j['technicalStatus'], fallback: 'Dobry'),
        repairNeeded: _bool(j['repairNeeded']),
        damageDescription: _string(j['damageDescription']),
        notes: _string(j['notes']),
        reportStatus: _string(j['reportStatus'], fallback: 'Zgłoszona'),
        deleteRequested: _bool(j['deleteRequested']),
        deleteReason: _string(j['deleteReason']),
        hiddenFromUsers: _bool(j['hiddenFromUsers']),
        deleted: _bool(j['deleted']),
        ownerId: _string(j['ownerId']),
        ownerEmail: _string(j['ownerEmail']),
        source: _string(j['source'], fallback: 'Ptasie Obserwacje'),
        externalId: _string(j['externalId']),
        externalUrl: _string(j['externalUrl']),
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
        locallyChanged: _bool(j['locallyChanged']),
        photoPaths: _stringList(j['photoPaths']),
        inspections: (j['inspections'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Inspection.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toServerMap() => {
        'id': id,
        'name': name,
        'type': type,
        'latitude': latitude,
        'longitude': longitude,
        'place_description': placeDescription,
        'technical_status': technicalStatus,
        'repair_needed': repairNeeded,
        'damage_description': damageDescription,
        'notes': notes,
        'report_status': reportStatus,
        'delete_requested': deleteRequested,
        'delete_reason': deleteReason,
        'hidden_from_users': hiddenFromUsers,
        'deleted': deleted,
        'owner_id': ownerId,
        'owner_email': ownerEmail,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'photo_urls': photoPaths,
      };

  factory NestSite.fromServerMap(Map<String, dynamic> j) => NestSite(
        id: _string(j['id']),
        name: _string(j['name'], fallback: 'Obiekt'),
        type: _string(j['type'], fallback: 'Budka lęgowa'),
        latitude: _double(j['latitude']),
        longitude: _double(j['longitude']),
        placeDescription: _string(j['place_description']),
        technicalStatus: _string(j['technical_status'], fallback: 'Dobry'),
        repairNeeded: _bool(j['repair_needed']),
        damageDescription: _string(j['damage_description']),
        notes: _string(j['notes']),
        reportStatus: _string(j['report_status'], fallback: 'Zgłoszona'),
        deleteRequested: _bool(j['delete_requested']),
        deleteReason: _string(j['delete_reason']),
        hiddenFromUsers: _bool(j['hidden_from_users']),
        deleted: _bool(j['deleted']),
        ownerId: _string(j['owner_id']),
        ownerEmail: _string(j['owner_email']),
        createdAt: _date(j['created_at']),
        updatedAt: _date(j['updated_at']),
        photoPaths: _stringList(j['photo_urls']),
      );
}

class Inspection {
  Inspection({
    required this.id,
    required this.date,
    this.inspector = '',
    this.cleaned = false,
    this.cleanedBy = '',
    this.condition = 'Dobry',
    this.birdsPresent = false,
    this.birdSpecies = '',
    this.eggsCount = 0,
    this.chicksCount = 0,
    this.adultsCount = 0,
    this.notes = '',
    this.deleted = false,
    this.locallyChanged = false,
  });

  String id;
  DateTime date;
  String inspector;
  bool cleaned;
  String cleanedBy;
  String condition;
  bool birdsPresent;
  String birdSpecies;
  int eggsCount;
  int chicksCount;
  int adultsCount;
  String notes;
  bool deleted;
  bool locallyChanged;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'inspector': inspector,
        'cleaned': cleaned,
        'cleanedBy': cleanedBy,
        'condition': condition,
        'birdsPresent': birdsPresent,
        'birdSpecies': birdSpecies,
        'eggsCount': eggsCount,
        'chicksCount': chicksCount,
        'adultsCount': adultsCount,
        'notes': notes,
        'deleted': deleted,
        'locallyChanged': locallyChanged,
      };

  factory Inspection.fromJson(Map<String, dynamic> j) => Inspection(
        id: _string(j['id']),
        date: _date(j['date']),
        inspector: _string(j['inspector']),
        cleaned: _bool(j['cleaned']),
        cleanedBy: _string(j['cleanedBy']),
        condition: _string(j['condition'], fallback: 'Dobry'),
        birdsPresent: _bool(j['birdsPresent']),
        birdSpecies: _string(j['birdSpecies']),
        eggsCount: _int(j['eggsCount']),
        chicksCount: _int(j['chicksCount']),
        adultsCount: _int(j['adultsCount']),
        notes: _string(j['notes']),
        deleted: _bool(j['deleted']),
        locallyChanged: _bool(j['locallyChanged']),
      );

  Map<String, dynamic> toServerMap(String siteId) => {
        'id': id,
        'nest_site_id': siteId,
        'date': date.toIso8601String(),
        'inspector': inspector,
        'cleaned': cleaned,
        'cleaned_by': cleanedBy,
        'condition': condition,
        'birds_present': birdsPresent,
        'bird_species': birdSpecies,
        'eggs_count': eggsCount,
        'chicks_count': chicksCount,
        'adults_count': adultsCount,
        'notes': notes,
        'deleted': deleted,
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory Inspection.fromServerMap(Map<String, dynamic> j) => Inspection(
        id: _string(j['id']),
        date: _date(j['date']),
        inspector: _string(j['inspector']),
        cleaned: _bool(j['cleaned']),
        cleanedBy: _string(j['cleaned_by']),
        condition: _string(j['condition'], fallback: 'Dobry'),
        birdsPresent: _bool(j['birds_present']),
        birdSpecies: _string(j['bird_species']),
        eggsCount: _int(j['eggs_count']),
        chicksCount: _int(j['chicks_count']),
        adultsCount: _int(j['adults_count']),
        notes: _string(j['notes']),
        deleted: _bool(j['deleted']),
      );
}

String _string(dynamic v, {String fallback = ''}) => v?.toString() ?? fallback;
double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
int _int(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
bool _bool(dynamic v) => v == true || v == 1 || v == 'true';
DateTime _date(dynamic v) => DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
List<String> _stringList(dynamic v) {
  if (v is List) {
    return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  }
  if (v is String && v.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(v);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      }
    } catch (_) {}
    return v.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  return <String>[];
}


const objectTypes = [
  'Budka lęgowa',
  'Dziupla naturalna',
  'Dziupla sztuczna',
  'Karmnik',
  'Schronienie',
  'Inne',
];

const technicalStatuses = [
  'Dobry',
  'Do kontroli',
  'Zabrudzona',
  'Uszkodzona',
  'Zalanie',
  'Spadła',
  'Zajęta przez inne zwierzę',
];


const rareBirdSpeciesKeywords = [
  'bocian czarny',
  'ciconia nigra',
  'bielik',
  'haliaeetus albicilla',
  'kania ruda',
  'milvus milvus',
  'kania czarna',
  'milvus migrans',
  'orlik krzykliwy',
  'clanga pomarina',
  'sokol wedrowny',
  'sokół wędrowny',
  'falco peregrinus',
  'plomykowka',
  'płomykówka',
  'tyto alba',
  'soweczka',
  'sóweczka',
  'glaucidium passerinum',
  'wlochatka',
  'włochatka',
  'aegolius funereus',
  'lelek',
  'caprimulgus europaeus',
  'zimorodek',
  'alcedo atthis',
  'zolna',
  'żołna',
  'merops apiaster',
  'dudek',
  'upupa epops',
  'derkacz',
  'crex crex',
  'rycyk',
  'limosa limosa',
  'krwawodziob',
  'krwawodziób',
  'tringa totanus',
  'turkawka',
  'streptopelia turtur',
  'orlica',
  'ichthyaetus ichthyaetus',
  'mewa orlica',
  'pallas gull',
  "pallas's gull",
  'zaroślówka',
  'zaroslowka',
  'acrocephalus dumetorum',
  'zaganiacz mały',
  'zaganiacz maly',
  'hippolais caligata',
  'czapla nadobna',
  'egretta garzetta',
  'warzęcha',
  'warzęcha',
  'platalea leucorodia',
];

String _normalizeSpeciesForMatch(String value) {
  var s = value.toLowerCase().trim();
  const from = 'ąćęłńóśźż';
  const to = 'acelnoszz';
  for (var i = 0; i < from.length; i++) {
    s = s.replaceAll(from[i], to[i]);
  }
  s = s.replaceAll('—', ' ');
  s = s.replaceAll('-', ' ');
  s = s.replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

bool isRareBirdSpecies(String value) {
  final normalized = _normalizeSpeciesForMatch(value);
  if (normalized.isEmpty) return false;

  for (final keyword in rareBirdSpeciesKeywords) {
    final k = _normalizeSpeciesForMatch(keyword);
    if (k.isNotEmpty && normalized.contains(k)) return true;
  }

  return false;
}

const birdSpecies = [
  'Bocian biały — Ciconia ciconia',
  'Bocian czarny — Ciconia nigra',
  'Łabędź niemy — Cygnus olor',
  'Gęgawa — Anser anser',
  'Krzyżówka — Anas platyrhynchos',
  'Cyranka — Spatula querquedula',
  'Gągoł — Bucephala clangula',
  'Nurogęś — Mergus merganser',
  'Kania ruda — Milvus milvus',
  'Kania czarna — Milvus migrans',
  'Bielik — Haliaeetus albicilla',
  'Błotniak stawowy — Circus aeruginosus',
  'Jastrząb — Accipiter gentilis',
  'Krogulec — Accipiter nisus',
  'Myszołów — Buteo buteo',
  'Orlik krzykliwy — Clanga pomarina',
  'Pustułka — Falco tinnunculus',
  'Kobuz — Falco subbuteo',
  'Sokół wędrowny — Falco peregrinus',
  'Kuropatwa — Perdix perdix',
  'Przepiórka — Coturnix coturnix',
  'Bażant — Phasianus colchicus',
  'Wodnik — Rallus aquaticus',
  'Derkacz — Crex crex',
  'Łyska — Fulica atra',
  'Czajka — Vanellus vanellus',
  'Sieweczka rzeczna — Charadrius dubius',
  'Kszyk — Gallinago gallinago',
  'Rycyk — Limosa limosa',
  'Krwawodziób — Tringa totanus',
  'Mewa śmieszka — Chroicocephalus ridibundus',
  'Rybitwa rzeczna — Sterna hirundo',
  'Grzywacz — Columba palumbus',
  'Sierpówka — Streptopelia decaocto',
  'Turkawka — Streptopelia turtur',
  'Kukułka — Cuculus canorus',
  'Płomykówka — Tyto alba',
  'Puszczyk — Strix aluco',
  'Uszatka — Asio otus',
  'Sóweczka — Glaucidium passerinum',
  'Włochatka — Aegolius funereus',
  'Lelek — Caprimulgus europaeus',
  'Jerzyk — Apus apus',
  'Zimorodek — Alcedo atthis',
  'Żołna — Merops apiaster',
  'Dudek — Upupa epops',
  'Krętogłów — Jynx torquilla',
  'Dzięcioł zielony — Picus viridis',
  'Dzięcioł czarny — Dryocopus martius',
  'Dzięcioł duży — Dendrocopos major',
  'Dzięcioł średni — Dendrocoptes medius',
  'Dzięciołek — Dryobates minor',
  'Skowronek — Alauda arvensis',
  'Brzegówka — Riparia riparia',
  'Dymówka — Hirundo rustica',
  'Oknówka — Delichon urbicum',
  'Świergotek drzewny — Anthus trivialis',
  'Pliszka siwa — Motacilla alba',
  'Pliszka żółta — Motacilla flava',
  'Strzyżyk — Troglodytes troglodytes',
  'Pokrzywnica — Prunella modularis',
  'Rudzik — Erithacus rubecula',
  'Słowik szary — Luscinia luscinia',
  'Słowik rdzawy — Luscinia megarhynchos',
  'Kopciuszek — Phoenicurus ochruros',
  'Pleszka — Phoenicurus phoenicurus',
  'Pokląskwa — Saxicola rubetra',
  'Kląskawka — Saxicola rubicola',
  'Białorzytka — Oenanthe oenanthe',
  'Kos — Turdus merula',
  'Kwiczoł — Turdus pilaris',
  'Drozd śpiewak — Turdus philomelos',
  'Paszkot — Turdus viscivorus',
  'Świerszczak — Locustella naevia',
  'Strumieniówka — Locustella fluviatilis',
  'Rokitniczka — Acrocephalus schoenobaenus',
  'Trzcinniczek — Acrocephalus scirpaceus',
  'Łozówka — Acrocephalus palustris',
  'Zaganiacz — Hippolais icterina',
  'Jarzębatka — Curruca nisoria',
  'Piegża — Curruca curruca',
  'Cierniówka — Curruca communis',
  'Gajówka — Sylvia borin',
  'Kapturka — Sylvia atricapilla',
  'Świstunka leśna — Phylloscopus sibilatrix',
  'Pierwiosnek — Phylloscopus collybita',
  'Piecuszek — Phylloscopus trochilus',
  'Mysikrólik — Regulus regulus',
  'Zniczek — Regulus ignicapilla',
  'Muchołówka szara — Muscicapa striata',
  'Muchołówka mała — Ficedula parva',
  'Muchołówka żałobna — Ficedula hypoleuca',
  'Muchołówka białoszyja — Ficedula albicollis',
  'Raniuszek — Aegithalos caudatus',
  'Sikora uboga — Poecile palustris',
  'Czarnogłówka — Poecile montanus',
  'Sikora czubatka — Lophophanes cristatus',
  'Sosnówka — Periparus ater',
  'Modraszka — Cyanistes caeruleus',
  'Bogatka — Parus major',
  'Kowalik — Sitta europaea',
  'Pełzacz leśny — Certhia familiaris',
  'Pełzacz ogrodowy — Certhia brachydactyla',
  'Remiz — Remiz pendulinus',
  'Wilga — Oriolus oriolus',
  'Gąsiorek — Lanius collurio',
  'Sójka — Garrulus glandarius',
  'Sroka — Pica pica',
  'Orzechówka — Nucifraga caryocatactes',
  'Kawka — Coloeus monedula',
  'Gawron — Corvus frugilegus',
  'Wrona siwa — Corvus cornix',
  'Kruk — Corvus corax',
  'Szpak — Sturnus vulgaris',
  'Wróbel — Passer domesticus',
  'Mazurek — Passer montanus',
  'Zięba — Fringilla coelebs',
  'Jer — Fringilla montifringilla',
  'Kulczyk — Serinus serinus',
  'Dzwoniec — Chloris chloris',
  'Szczygieł — Carduelis carduelis',
  'Czyż — Spinus spinus',
  'Makolągwa — Linaria cannabina',
  'Czeczotka — Acanthis flammea',
  'Krzyżodziób świerkowy — Loxia curvirostra',
  'Dziwonia — Carpodacus erythrinus',
  'Gil — Pyrrhula pyrrhula',
  'Grubodziób — Coccothraustes coccothraustes',
  'Trznadel — Emberiza citrinella',
  'Potrzos — Emberiza schoeniclus',
  'Ortolan — Emberiza hortulana',
  'Orlik grubodzioby — Clanga clanga',
  'Mewa orlica — Ichthyaetus ichthyaetus',
  'Szpak różowy — Pastor roseus',
  'Żwirowiec łąkowy — Glareola pratincola',
  'Zaroślówka — Acrocephalus dumetorum',
];


const Map<String, String> birdSpeciesAliases = {
  "pallas's gull": 'Mewa orlica — Ichthyaetus ichthyaetus',
  'pallas gull': 'Mewa orlica — Ichthyaetus ichthyaetus',
  'great black headed gull': 'Mewa orlica — Ichthyaetus ichthyaetus',
  'ichthyaetus ichthyaetus': 'Mewa orlica — Ichthyaetus ichthyaetus',
  'greater spotted eagle': 'Orlik grubodzioby — Clanga clanga',
  'clanga clanga': 'Orlik grubodzioby — Clanga clanga',
  'lesser spotted eagle': 'Orlik krzykliwy — Clanga pomarina',
  'clanga pomarina': 'Orlik krzykliwy — Clanga pomarina',
  'rosy starling': 'Szpak różowy — Pastor roseus',
  'pastor roseus': 'Szpak różowy — Pastor roseus',
  'collared pratincole': 'Żwirowiec łąkowy — Glareola pratincola',
  'glareola pratincola': 'Żwirowiec łąkowy — Glareola pratincola',
  "blyth's reed warbler": 'Zaroślówka — Acrocephalus dumetorum',
  'blyths reed warbler': 'Zaroślówka — Acrocephalus dumetorum',
  'acrocephalus dumetorum': 'Zaroślówka — Acrocephalus dumetorum',
};

String canonicalBirdSpeciesName(String value) {
  final raw = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (raw.isEmpty) return birdSpecies.first;

  final normalized = _normalizeSpeciesForMatch(raw);

  for (final entry in birdSpeciesAliases.entries) {
    final key = _normalizeSpeciesForMatch(entry.key);
    if (key.isNotEmpty && (normalized == key || normalized.contains(key))) {
      return entry.value;
    }
  }

  for (final species in birdSpecies) {
    final speciesNorm = _normalizeSpeciesForMatch(species);
    if (normalized == speciesNorm) return species;

    final parts = species.split('—').map((e) => e.trim()).where((e) => e.isNotEmpty);
    for (final part in parts) {
      final partNorm = _normalizeSpeciesForMatch(part);
      if (partNorm.isNotEmpty && normalized == partNorm) return species;
    }
  }

  // Jeżeli wpis z Clanga albo ręcznie wpisany tekst zawiera znany gatunek
  // w środku dłuższego opisu, też zamieniamy go na wersję PL — łacina.
  for (final species in birdSpecies) {
    final parts = species.split('—').map((e) => e.trim()).where((e) => e.isNotEmpty);
    for (final part in parts) {
      final partNorm = _normalizeSpeciesForMatch(part);
      if (partNorm.length >= 4 && normalized.contains(partNorm)) return species;
    }
  }

  final latinMatch = RegExp(r'\b([A-Z][a-z]+\s+[a-z]+)\b').firstMatch(raw);
  if (latinMatch != null) {
    final latin = latinMatch.group(1)!.trim();
    final latinNorm = _normalizeSpeciesForMatch(latin);
    for (final species in birdSpecies) {
      final latinPart = birdSpeciesLatinName(species);
      if (_normalizeSpeciesForMatch(latinPart) == latinNorm) return species;
    }
  }

  return raw;
}

String birdSpeciesPolishName(String value) {
  final canonical = canonicalBirdSpeciesName(value);
  final parts = canonical.split('—').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  if (parts.length >= 2) return parts.first;
  if (RegExp(r'^[A-Z][a-z]+\s+[a-z]+$').hasMatch(canonical.trim())) return 'Nieznana nazwa polska';
  return canonical.trim().isEmpty ? 'Nieznany gatunek' : canonical.trim();
}

String birdSpeciesLatinName(String value) {
  final canonical = canonicalBirdSpeciesName(value);
  final parts = canonical.split('—').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  if (parts.length >= 2) return parts.sublist(1).join(' — ');
  if (RegExp(r'^[A-Z][a-z]+\s+[a-z]+$').hasMatch(canonical.trim())) return canonical.trim();
  return '';
}

String birdSpeciesFullName(String value) {
  final pl = birdSpeciesPolishName(value);
  final latin = birdSpeciesLatinName(value);

  if (latin.isEmpty) return pl;
  if (pl == 'Nieznana nazwa polska') return latin;
  return '$pl — $latin';
}

String birdSpeciesTwoLineName(String value) {
  final pl = birdSpeciesPolishName(value);
  final latin = birdSpeciesLatinName(value);

  if (latin.isEmpty) return pl;
  if (pl == 'Nieznana nazwa polska') return latin;
  return '$pl\n$latin';
}


String birdRarityGroupKey(String species) {
  final full = canonicalBirdSpeciesName(species);
  final norm = _normalizeSpeciesForMatch(full);

  if (isRareBirdSpecies(full)) {
    if (norm.contains('mewa orlica') ||
        norm.contains('ichthyaetus ichthyaetus') ||
        norm.contains('szpak rozowy') ||
        norm.contains('pastor roseus') ||
        norm.contains('zwirowiec lakowy') ||
        norm.contains('glareola pratincola') ||
        norm.contains('zaroslowka') ||
        norm.contains('acrocephalus dumetorum')) {
      return 'bardzo_rzadkie';
    }
    return 'rzadkie';
  }

  for (final token in const [
    'orlik krzykliwy',
    'kania ruda',
    'kania czarna',
    'bielik',
    'rybolow',
    'plomykowka',
    'sowa uszata',
    'zimorodek',
    'dudek',
    'kraska',
    'zolna',
    'ortolan',
  ]) {
    if (norm.contains(_normalizeSpeciesForMatch(token))) return 'lokalne';
  }

  return 'pospolite';
}

String birdRarityGroupLabel(String key) {
  switch (key) {
    case 'pospolite':
      return 'Pospolite / częste';
    case 'lokalne':
      return 'Lokalne / mniej liczne';
    case 'rzadkie':
      return 'Rzadkie w Polsce';
    case 'bardzo_rzadkie':
      return 'Bardzo rzadkie / zalatujące';
    default:
      return key;
  }
}

IconData birdRarityGroupIcon(String key) {
  switch (key) {
    case 'pospolite':
      return Icons.eco;
    case 'lokalne':
      return Icons.place;
    case 'rzadkie':
      return Icons.warning_amber;
    case 'bardzo_rzadkie':
      return Icons.priority_high;
    default:
      return Icons.flutter_dash;
  }
}

Color birdRarityGroupColor(String key) {
  switch (key) {
    case 'pospolite':
      return AppTheme.green;
    case 'lokalne':
      return Colors.blueGrey;
    case 'rzadkie':
      return Colors.orange.shade800;
    case 'bardzo_rzadkie':
      return Colors.red.shade800;
    default:
      return AppTheme.green;
  }
}


class KeepAlivePage extends StatefulWidget {
  const KeepAlivePage({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isAdmin = state.isAdmin;

    final update = state.availableUpdate;
    if (update != null && !state.updateDialogShown) {
      state.markUpdateDialogShown();
      Future.microtask(() {
        if (context.mounted) _showUpdateDialog(context, update);
      });
    }

    final pages = <Widget>[
      const KeepAlivePage(child: BirdObservationsPage()),
      if (isAdmin) const KeepAlivePage(child: AdminPage()),
    ];

    final items = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.travel_explore), label: 'Obserwacje'),
      if (isAdmin) const NavigationDestination(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
    ];

    if (state.currentTab >= pages.length) {
      Future.microtask(() => state.setTab(0));
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const _ForestGradient(),
        title: _AppTitle(state: state),
        actions: [
          IconButton(
            onPressed: () => _showInfoDialog(context),
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            tooltip: 'Sprawdź aktualizację',
            onPressed: state.checkingUpdate ? null : () => state.checkForUpdates(manual: true),
            icon: Icon(state.checkingUpdate ? Icons.hourglass_top : Icons.system_update_alt),
          ),
          IconButton(
            tooltip: state.loggedIn ? 'Konto / wyloguj' : 'Zaloguj / zarejestruj',
            onPressed: () => _showAccountDialog(context),
            icon: Icon(state.loggedIn ? Icons.account_circle : Icons.login),
          ),
          IconButton(
            tooltip: state.isAdmin ? 'Wyłącz admina' : 'Włącz admina',
            onPressed: () {
              if (state.isAdmin) {
                state.disableAdmin();
              } else {
                _showAdminPasswordDialog(context);
              }
            },
            icon: Icon(state.isAdmin ? Icons.shield : Icons.shield_outlined),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (state.errorMessage != null || state.infoMessage != null)
              MessageBanner(
                text: state.errorMessage ?? state.infoMessage!,
                error: state.errorMessage != null,
                onClose: state.clearMessages,
              ),
            Expanded(child: pages[min(state.currentTab, pages.length - 1)]),
            const PtasiaSplitVariantBanner(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: NavigationBar(
            height: 72,
            selectedIndex: min(state.currentTab, items.length - 1),
            onDestinationSelected: state.setTab,
            destinations: items,
          ),
        ),
      ),
    );
  }
}


class PtasiaSplitVariantBanner extends StatelessWidget {
  const PtasiaSplitVariantBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFFEAF6E6),
      child: const Text(
        'Ptasie Obserwacje — Ta wersja zawiera tylko obserwacje ptaków: lista 5 wpisów, mapa obserwacji, dodawanie obserwacji, filtry gatunków.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _AppTitle extends StatelessWidget {
  const _AppTitle({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('🐦', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        const Flexible(
          child: Text(
            'Ptasie Obserwacje',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _RoleChip(label: state.roleLabel, admin: state.isAdmin),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.admin});

  final String label;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 98),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
      ),
    );
  }
}


class MessageBanner extends StatelessWidget {
  const MessageBanner({super.key, required this.text, required this.error, required this.onClose});

  final String text;
  final bool error;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: error ? Colors.red.shade50 : Colors.green.shade50,
      child: ListTile(
        dense: true,
        leading: Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: error ? Colors.red : Colors.green),
        title: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
      ),
    );
  }
}

class PtasiaStrefaBanner extends StatelessWidget {
  const PtasiaStrefaBanner({super.key, this.compact = true});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, compact ? 4 : 8, 12, compact ? 10 : 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF8E5), Color(0xFFE7F5D8), Color(0xFFD9EFCB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFCDE5B7)),
          boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 16, offset: Offset(0, 7))],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 7 : 11),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/ptasia_strefa_logo.png',
                  width: compact ? 36 : 44,
                  height: compact ? 36 : 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => CircleAvatar(
                    radius: compact ? 18 : 22,
                    backgroundColor: primary.withOpacity(0.12),
                    child: Icon(Icons.flutter_dash, color: primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ptasia Strefa',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF184D2A),
                      ),
                ),
              ),
              const SizedBox(width: 6),
              _BannerButton(
                tooltip: 'Otwórz stronę Ptasia Strefa',
                label: 'WWW',
                icon: Icons.language,
                onTap: () => _openUrl('https://ptasiastrefa.pl/'),
              ),
              const SizedBox(width: 6),
              _BannerButton(
                tooltip: 'Otwórz YouTube Ptasia Strefa',
                label: 'YT',
                icon: Icons.play_circle_fill,
                onTap: () => _openUrl('https://www.youtube.com/@ptasiastrefa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  const _BannerButton({required this.tooltip, required this.label, required this.icon, required this.onTap});

  final String tooltip;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.86),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD3E7C5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFF0B7A3B)),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0B7A3B))),
            ],
          ),
        ),
      ),
    );
  }
}


Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  final tries = <LaunchMode>[
    LaunchMode.externalApplication,
    LaunchMode.inAppBrowserView,
    LaunchMode.platformDefault,
  ];

  for (final mode in tries) {
    try {
      final ok = await launchUrl(uri, mode: mode);
      if (ok) return;
    } catch (_) {}
  }

  if (url.contains('@ptasiastrefa')) {
    final fallback = Uri.parse('https://www.youtube.com/channel/UC13xLJTa9qif7DarMrFmUqQ');
    for (final mode in tries) {
      try {
        final ok = await launchUrl(fallback, mode: mode);
        if (ok) return;
      } catch (_) {}
    }
  }
}


class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController controller = MapController();
  bool showSiteSearch = false;
  LatLng center = const LatLng(54.3520, 18.6466);
  LatLng? myLocation;

  Future<void> _showMyLocationOnMap(BuildContext context, AppState state) async {
    final p = await _getLocationWithPrompt(context, state);
    if (p == null || !mounted) return;

    setState(() {
      myLocation = p;
      center = p;
    });
    controller.move(p, 17);
  }

  Future<void> _openAddWithGpsAndDuplicateCheck(BuildContext context, AppState state) async {
    try {
      final p = await _getLocationWithPrompt(context, state);
      if (p == null) return;
      center = p;
      controller.move(p, 16);

      final nearby = await state.findNearbySites(
        latitude: p.latitude,
        longitude: p.longitude,
        radiusMeters: 50,
      );

      if (!context.mounted) return;

      if (nearby.isNotEmpty) {
        final nearest = nearby.first;
        final decision = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Budka może już istnieć'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('W pobliżu Twojej lokalizacji są już dodane obiekty. Sprawdź, czy nie dodajesz tej samej budki drugi raz.'),
                  const SizedBox(height: 12),
                  for (final item in nearby.take(3)) _NearbySiteTile(result: item),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Anuluj')),
              TextButton(onPressed: () => Navigator.pop(context, 'show'), child: const Text('Pokaż najbliższą')),
              FilledButton(onPressed: () => Navigator.pop(context, 'add'), child: const Text('Dodaj mimo to')),
            ],
          ),
        );

        if (!context.mounted) return;

        if (decision == 'show') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => SiteDetailsPage(site: nearest.site)));
          return;
        }

        if (decision != 'add') return;
      }

      Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddSitePage(initialPoint: p)));
    } catch (e) {
      state.showError('Nie udało się pobrać GPS: $e. Możesz użyć przycisku Mapa i wskazać punkt ręcznie.');
    }
  }


  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final sites = state.searchedSites();
    final allVisibleSites = state.visibleSites();

    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 12,
            onTap: (_, point) {
              if (state.pickingOnMap) {
                state.setPicking(false);
                if (!_ensureLoggedInForChanges(context, state, 'dodawanie budki')) return;
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AddSitePage(initialPoint: point),
                ));
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'pl.bartoszlawicki.ptasia_mapa_clean',
            ),
            MarkerLayer(
              markers: [
                ...sites.map((s) {
                  return Marker(
                    point: LatLng(s.latitude, s.longitude),
                    width: 54,
                    height: 54,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SiteDetailsPage(site: s))),
                      child: ObjectMarker(site: s),
                    ),
                  );
                }),
                if (myLocation != null)
                  Marker(
                    point: myLocation!,
                    width: 54,
                    height: 54,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.withOpacity(0.18),
                        border: Border.all(color: Colors.blue, width: 3),
                      ),
                      child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 14,
          top: 18,
          right: 14,
          child: _MapStatsBanner(sites: sites, state: state),
        ),
        if (showSiteSearch)
          Positioned(
            left: 14,
            top: 88,
            right: 14,
            child: SiteSearchCard(
              state: state,
              sites: sites,
              compact: true,
              onClose: () => setState(() => showSiteSearch = false),
              onSiteSelected: (site) {
                final point = LatLng(site.latitude, site.longitude);
                setState(() {
                  center = point;
                  showSiteSearch = false;
                });
                controller.move(point, 17);
              },
            ),
          ),
        if (sites.isEmpty)
          Positioned(
            left: 14,
            bottom: 18,
            right: 94,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  state.nestSiteSearchQuery.isNotEmpty && allVisibleSites.isNotEmpty
                      ? 'Brak budki o takiej nazwie. Zmień tekst szukania albo wyczyść filtr.'
                      : 'Mapa działa. Brak widocznych obiektów — dodaj budkę z GPS albo wskaż punkt na mapie.',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        Positioned(
          right: 12,
          top: 142,
          child: Column(
            children: [
              MapRoundButton(
                icon: Icons.search,
                label: 'Szukaj',
                onTap: () => setState(() => showSiteSearch = !showSiteSearch),
              ),
              const SizedBox(height: 10),
              MapRoundButton(
                icon: Icons.my_location,
                label: 'GPS',
                onTap: () => _showMyLocationOnMap(context, state),
              ),
              MapRoundButton(
                icon: Icons.add_location_alt,
                label: 'Mapa',
                onTap: () {
                  if (!_ensureLoggedInForChanges(context, state, 'wskazanie miejsca i dodanie budki')) return;
                  state.setPicking(true);
                },
              ),
              MapRoundButton(
                icon: Icons.upload_file,
                label: state.importingGpx ? '...' : 'GPX',
                onTap: state.importingGpx
                    ? null
                    : () {
                        if (!_ensureLoggedInForChanges(context, state, 'import budek z pliku GPX')) return;
                        state.importNestSitesFromGpxFile();
                      },
              ),
              MapRoundButton(
                icon: Icons.sync,
                label: state.syncing ? '...' : 'Sync',
                onTap: state.syncing ? null : () => state.sync(),
              ),
              MapRoundButton(
                icon: Icons.add_home_work,
                label: 'Budka',
                onTap: () {
                  if (!_ensureLoggedInForChanges(context, state, 'dodawanie budki')) return;
                  _openAddWithGpsAndDuplicateCheck(context, state);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class SiteSearchCard extends StatefulWidget {
  const SiteSearchCard({
    super.key,
    required this.state,
    required this.sites,
    this.compact = false,
    this.onSiteSelected,
    this.onClose,
  });

  final AppState state;
  final List<NestSite> sites;
  final bool compact;
  final ValueChanged<NestSite>? onSiteSelected;
  final VoidCallback? onClose;

  @override
  State<SiteSearchCard> createState() => _SiteSearchCardState();
}

class _SiteSearchCardState extends State<SiteSearchCard> {
  late final TextEditingController controller;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.state.nestSiteSearchQuery);
  }

  @override
  void didUpdateWidget(covariant SiteSearchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final external = widget.state.nestSiteSearchQuery;
    if (external != controller.text) {
      controller.text = external;
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _setSearchDebounced(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 250), () {
      widget.state.setNestSiteSearchQuery(value);
    });
  }

  void _openSite(NestSite site) {
    widget.onSiteSelected?.call(site);
    FocusScope.of(context).unfocus();

    if (widget.compact) return;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SiteDetailsPage(site: site)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.state.nestSiteSearchQuery;
    final showResults = query.isNotEmpty;
    final maxResults = widget.compact ? 4 : 8;
    final results = widget.sites.take(maxResults).toList();

    return Material(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(18),
      elevation: widget.compact ? 6 : 0,
      shadowColor: Colors.black26,
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 10 : 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.compact && widget.onClose != null) ...[
              Row(
                children: [
                  const Icon(Icons.search, color: AppTheme.green),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Szukaj budki', style: TextStyle(fontWeight: FontWeight.w900))),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Zamknij',
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: widget.compact,
                labelText: 'Szukaj budki po nazwie',
                hintText: 'np. Budka Łódź albo budka lodz...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Wyczyść szukanie',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          controller.clear();
                          widget.state.clearNestSiteSearchQuery();
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFFF4F8F1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFD6EACF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.green, width: 1.7),
                ),
              ),
              onChanged: _setSearchDebounced,
              onSubmitted: (_) {
                if (widget.sites.length == 1) _openSite(widget.sites.first);
              },
            ),
            if (showResults) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    widget.sites.isEmpty ? Icons.search_off : Icons.check_circle,
                    color: widget.sites.isEmpty ? Colors.orange.shade800 : AppTheme.green,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.sites.isEmpty
                          ? 'Nie znaleziono budki o tej nazwie.'
                          : 'Znaleziono: ${widget.sites.length}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (results.isNotEmpty) ...[
                const SizedBox(height: 6),
                for (final site in results)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openSite(site),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          SizedBox(width: 30, height: 30, child: ObjectMarker(site: site)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              site.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (!widget.compact)
                            Text(
                              site.type,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}


class MapRoundButton extends StatelessWidget {
  const MapRoundButton({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 6,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 66,
            height: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: onTap == null ? Colors.grey : AppTheme.green, size: 22),
                Text(label, style: TextStyle(color: onTap == null ? Colors.grey : AppTheme.green, fontSize: 11, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ObjectMarker extends StatelessWidget {
  const ObjectMarker({super.key, required this.site});

  final NestSite site;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (site.type) {
      case 'Budka lęgowa':
        icon = Icons.house_rounded;
        color = const Color(0xFF7A4A20);
        break;
      case 'Dziupla naturalna':
        icon = Icons.nature_rounded;
        color = const Color(0xFF2E7D32);
        break;
      case 'Dziupla sztuczna':
        icon = Icons.account_tree_rounded;
        color = const Color(0xFF5E35B1);
        break;
      case 'Karmnik':
        icon = Icons.ramen_dining_rounded;
        color = const Color(0xFFEF6C00);
        break;
      case 'Schronienie':
        icon = Icons.roofing_rounded;
        color = const Color(0xFF3949AB);
        break;
      default:
        icon = Icons.location_on_rounded;
        color = Colors.blueGrey;
    }

    final needsRepair = _siteNeedsRepair(site);
    final cleaned = _latestCleanedInspection(site) != null;
    if (site.hiddenFromUsers) color = Colors.grey;
    if (site.deleteRequested) color = Colors.red;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: color, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        if (needsRepair)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.build_rounded, color: Colors.white, size: 13),
            ),
          )
        else if (cleaned)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppTheme.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 13),
            ),
          ),
      ],
    );
  }
}

class _MapStatsBanner extends StatelessWidget {
  const _MapStatsBanner({required this.sites, required this.state});

  final List<NestSite> sites;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.pickingOnMap) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1).withOpacity(0.97),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE2C474)),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.touch_app, color: Color(0xFFB8792A)),
              SizedBox(width: 8),
              Expanded(child: Text('Kliknij mapę, aby wybrać miejsce budki.', style: TextStyle(fontWeight: FontWeight.w900))),
            ],
          ),
        ),
      );
    }

    final birds = sites.where((s) => s.inspections.any((i) => i.birdsPresent)).length + state.visibleBirdObservations().length;
    final repair = sites.where((s) => s.repairNeeded).length;
    final requests = sites.where((s) => s.deleteRequested || s.reportStatus.toLowerCase().contains('zgłosz')).length;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A6B35), Color(0xFF168547), Color(0xFF35A764)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.park, color: Colors.white, size: 19),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tryb: ${state.roleLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _MapStatItem(icon: Icons.park, value: sites.length, label: 'Obiekty')),
                Expanded(child: _MapStatItem(icon: Icons.flutter_dash, value: birds, label: 'Ptaki')),
                Expanded(child: _MapStatItem(icon: Icons.build, value: repair, label: 'Naprawy')),
                Expanded(child: _MapStatItem(icon: Icons.notifications_none, value: requests, label: 'Zgłosz.')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapStatItem extends StatelessWidget {
  const _MapStatItem({required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withOpacity(0.18),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text('$value', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
      ],
    );
  }
}


class AddSitePage extends StatefulWidget {
  const AddSitePage({super.key, this.initialPoint, this.editSite});

  final LatLng? initialPoint;
  final NestSite? editSite;

  @override
  State<AddSitePage> createState() => _AddSitePageState();
}

class _AddSitePageState extends State<AddSitePage> {
  late final TextEditingController name;
  late final TextEditingController place;
  late final TextEditingController damage;
  late final TextEditingController notes;
  late String type;
  late String status;
  late bool repairNeeded;
  late double lat;
  late double lng;
  final MapController addMapController = MapController();
  final ImagePicker imagePicker = ImagePicker();
  final List<String> photoPaths = [];
  bool checkingNearby = false;
  List<NearbySite> nearbySites = [];

  @override
  void initState() {
    super.initState();
    final s = widget.editSite;
    name = TextEditingController(text: s?.name ?? '');
    place = TextEditingController(text: s?.placeDescription ?? '');
    damage = TextEditingController(text: s?.damageDescription ?? '');
    notes = TextEditingController(text: s?.notes ?? '');
    type = s?.type ?? 'Budka lęgowa';
    status = s?.technicalStatus ?? 'Dobry';
    repairNeeded = s?.repairNeeded ?? false;
    photoPaths.addAll(s?.photoPaths ?? const []);
    lat = s?.latitude ?? widget.initialPoint?.latitude ?? 54.3520;
    lng = s?.longitude ?? widget.initialPoint?.longitude ?? 18.6466;

    Future.microtask(_refreshNearbyCandidates);
  }

  void _setLocation(LatLng point, {bool moveMap = true}) {
    setState(() {
      lat = point.latitude;
      lng = point.longitude;
    });
    if (moveMap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          addMapController.move(point, 17);
        } catch (_) {}
      });
    }
    Future.microtask(_refreshNearbyCandidates);
  }

  Future<void> _useGpsForForm(AppState state) async {
    try {
      final p = await _getLocationWithPrompt(context, state);
      if (p == null) return;
      _setLocation(p);
      state.showInfo('Pobrano lokalizację GPS.');
    } catch (e) {
      state.showError(e.toString());
    }
  }

  Future<void> _refreshNearbyCandidates() async {
    if (!mounted) return;
    final state = AppStateScope.of(context);
    setState(() => checkingNearby = true);
    final results = await state.findNearbySites(
      latitude: lat,
      longitude: lng,
      radiusMeters: 50,
      excludeId: widget.editSite?.id,
    );
    if (!mounted) return;
    setState(() {
      nearbySites = results;
      checkingNearby = false;
    });
  }

  Future<bool> _confirmDuplicateIfNeeded(AppState state) async {
    final results = await state.findNearbySites(
      latitude: lat,
      longitude: lng,
      radiusMeters: 50,
      excludeId: widget.editSite?.id,
    );

    if (!mounted) return false;

    setState(() => nearbySites = results);
    if (results.isEmpty) return true;

    final nearest = results.first;
    final decision = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Możliwy duplikat'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Jesteś bardzo blisko obiektu, który jest już w systemie. '
                'Sprawdź, czy nie dodajesz tej samej budki drugi raz.',
              ),
              const SizedBox(height: 12),
              _NearbySiteTile(result: nearest),
              if (results.length > 1) ...[
                const SizedBox(height: 8),
                Text('Inne bliskie obiekty: ${results.length - 1}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'show'),
            child: const Text('Pokaż obiekt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Dodaj mimo to'),
          ),
        ],
      ),
    );

    if (!mounted) return false;

    if (decision == 'show') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SiteDetailsPage(site: nearest.site)));
      return false;
    }

    return decision == 'save';
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await imagePicker.pickImage(source: source, imageQuality: 82, maxWidth: 1800);
      if (picked == null) return;
      setState(() => photoPaths.add(picked.path));
    } catch (e) {
      AppStateScope.of(context).showError('Nie udało się dodać zdjęcia: $e');
    }
  }

  Future<void> _save() async {
    final state = AppStateScope.of(context);
    final canSave = await _confirmDuplicateIfNeeded(state);
    if (!canSave) return;

    if (widget.editSite == null) {
      state.createSite(
        name: name.text,
        type: type,
        latitude: lat,
        longitude: lng,
        placeDescription: place.text,
        technicalStatus: status,
        repairNeeded: repairNeeded,
        damageDescription: damage.text,
        notes: notes.text,
        photoPaths: List<String>.from(photoPaths),
      );
    } else {
      final s = widget.editSite!;
      s.name = name.text;
      s.type = type;
      s.latitude = lat;
      s.longitude = lng;
      s.placeDescription = place.text;
      s.technicalStatus = status;
      s.repairNeeded = repairNeeded;
      s.damageDescription = damage.text;
      s.notes = notes.text;
      s.photoPaths = List<String>.from(photoPaths);
      await state.updateSite(s);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    if (!state.canCreateObjects) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dodaj obiekt')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tryb Gość', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text('Gość może tylko oglądać obiekty na mapie. Dodawanie i edycja budek wymaga zalogowania.'),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => _showAccountDialog(context),
                      icon: const Icon(Icons.login),
                      label: const Text('Zaloguj się'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.editSite == null ? 'Dodaj obiekt' : 'Edytuj obiekt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DropdownButtonFormField<String>(
            value: type,
            decoration: const InputDecoration(labelText: 'Typ obiektu'),
            items: objectTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => type = v ?? type),
          ),
          const SizedBox(height: 10),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nazwa / numer')),
          const SizedBox(height: 10),
          TextField(controller: place, decoration: const InputDecoration(labelText: 'Opis miejsca')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: status,
            decoration: const InputDecoration(labelText: 'Stan techniczny'),
            items: technicalStatuses.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => status = v ?? status),
          ),
          SwitchListTile(
            value: repairNeeded,
            onChanged: (v) => setState(() => repairNeeded = v),
            title: const Text('Wymaga naprawy'),
          ),
          TextField(controller: damage, decoration: const InputDecoration(labelText: 'Opis uszkodzenia')),
          const SizedBox(height: 10),
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notatki'), maxLines: 3),
          const SizedBox(height: 16),
          _SectionTitle('Zdjęcia budki / lokalizacji / uszkodzenia'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final path in photoPaths)
                        _PhotoThumb(
                          path: path,
                          onRemove: () => setState(() => photoPaths.remove(path)),
                        ),
                      _PhotoButton(
                        icon: Icons.photo_camera,
                        label: 'Aparat',
                        onTap: () => _pickPhoto(ImageSource.camera),
                      ),
                      _PhotoButton(
                        icon: Icons.photo_library,
                        label: 'Galeria',
                        onTap: () => _pickPhoto(ImageSource.gallery),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Możesz dodać zdjęcia budki, otoczenia, lokalizacji lub uszkodzenia.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _SectionTitle('Lokalizacja budki'),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SizedBox(
                  height: 230,
                  child: FlutterMap(
                    mapController: addMapController,
                    options: MapOptions(
                      initialCenter: LatLng(lat, lng),
                      initialZoom: 16,
                      onTap: (_, point) => _setLocation(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'pl.bartoszlawicki.ptasia_mapa_clean',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(lat, lng),
                            width: 62,
                            height: 62,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 54, shadows: [Shadow(color: Colors.black38, blurRadius: 8)]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    children: [
                      Text(
                        'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _useGpsForForm(state),
                              icon: const Icon(Icons.my_location),
                              label: const Text('Z GPS'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: checkingNearby ? null : _refreshNearbyCandidates,
                              icon: checkingNearby
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.radar),
                              label: const Text('Sprawdź'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('Możesz dotknąć mapy, aby wskazać dokładne miejsce budki.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (nearbySites.isNotEmpty)
            _NearbyWarningCard(
              results: nearbySites,
              onOpen: (site) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => SiteDetailsPage(site: site)));
              },
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 5, height: 22, decoration: BoxDecoration(color: AppTheme.green, borderRadius: BorderRadius.circular(12))),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
      ],
    );
  }
}


class _PhotoButton extends StatelessWidget {
  const _PhotoButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFFEFF7EA),
          border: Border.all(color: const Color(0xFFDDE8D4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.green),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            File(path),
            width: 86,
            height: 86,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 86,
              height: 86,
              color: const Color(0xFFEFF7EA),
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
        Positioned(
          right: -8,
          top: -8,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}


class _NearbyWarningCard extends StatelessWidget {
  const _NearbyWarningCard({
    required this.results,
    required this.onOpen,
  });

  final List<NearbySite> results;
  final ValueChanged<NestSite> onOpen;

  @override
  Widget build(BuildContext context) {
    final nearest = results.first;
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Możliwy duplikat',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('W pobliżu jest już obiekt. Sprawdź, czy ta budka nie została wcześniej dodana.'),
            const SizedBox(height: 10),
            _NearbySiteTile(result: nearest),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => onOpen(nearest.site),
                icon: const Icon(Icons.visibility),
                label: const Text('Pokaż obiekt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbySiteTile extends StatelessWidget {
  const _NearbySiteTile({required this.result});

  final NearbySite result;

  @override
  Widget build(BuildContext context) {
    final site = result.site;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ObjectMarker(site: site),
      title: Text(site.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${site.type}\nOdległość: ${result.distanceText} • Stan: ${site.technicalStatus}'),
      isThreeLine: true,
    );
  }
}





class BirdObservationPaginationBar extends StatelessWidget {
  const BirdObservationPaginationBar({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final total = state.birdObservationTotalFilteredCount();
    final start = state.birdObservationRangeStart();
    final end = state.birdObservationRangeEnd();
    final canPrev = state.birdObservationPageIndex > 0;
    final canNext = state.birdObservationPageIndex < state.birdObservationTotalPages() - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6EACF)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: canPrev ? state.previousBirdObservationPage : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Poprzednie'),
          ),
          Expanded(
            child: Text(
              total == 0 ? '0 z 0' : '$start–$end z $total',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          FilledButton.icon(
            onPressed: canNext ? state.nextBirdObservationPage : null,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Następne'),
          ),
        ],
      ),
    );
  }
}

class BirdObservationSearchAndFilterCard extends StatefulWidget {
  const BirdObservationSearchAndFilterCard({super.key, required this.state});

  final AppState state;

  @override
  State<BirdObservationSearchAndFilterCard> createState() => _BirdObservationSearchAndFilterCardState();
}

class _BirdObservationSearchAndFilterCardState extends State<BirdObservationSearchAndFilterCard> {
  late final TextEditingController controller;
  bool showSpeciesList = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.state.birdObservationSearchQuery);
  }

  @override
  void didUpdateWidget(covariant BirdObservationSearchAndFilterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final external = widget.state.birdObservationSearchQuery;
    if (external != controller.text) {
      controller.text = external;
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final counts = state.birdRarityGroupCounts();
    final species = showSpeciesList ? state.observedSpeciesForFilter() : const <String>[];
    final activeSpeciesCount = state.enabledBirdSpecies.length;
    final filteredCount = state.filteredBirdObservations().length;

    return Card(
      color: const Color(0xFFF4F8F1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Szukaj ptaka w obserwacjach',
                hintText: 'np. żuraw, zuraw, Clanga clanga...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.birdObservationSearchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Wyczyść szukanie',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          controller.clear();
                          state.clearBirdObservationSearchQuery();
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onChanged: state.setBirdObservationSearchQuery,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.filter_alt, color: AppTheme.green),
                const SizedBox(width: 8),
                Expanded(child: Text('Widoczne obserwacje: $filteredCount', style: const TextStyle(fontWeight: FontWeight.w900))),
                if (activeSpeciesCount > 0)
                  TextButton.icon(
                    onPressed: state.clearBirdSpeciesFilter,
                    icon: const Icon(Icons.clear),
                    label: Text('Ptaki: $activeSpeciesCount'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Filtr obserwacji według rzadkości w Polsce', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in const ['pospolite', 'lokalne', 'rzadkie', 'bardzo_rzadkie'])
                  FilterChip(
                    selected: state.enabledBirdRarityGroups.contains(key),
                    avatar: Icon(
                      birdRarityGroupIcon(key),
                      size: 18,
                      color: state.enabledBirdRarityGroups.contains(key) ? Colors.white : birdRarityGroupColor(key),
                    ),
                    label: Text('${birdRarityGroupLabel(key)} (${counts[key] ?? 0})'),
                    selectedColor: birdRarityGroupColor(key),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: state.enabledBirdRarityGroups.contains(key) ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w800,
                    ),
                    onSelected: (value) => state.toggleBirdRarityGroup(key, value),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: species.isEmpty ? null : () => setState(() => showSpeciesList = !showSpeciesList),
              icon: Icon(showSpeciesList ? Icons.expand_less : Icons.expand_more),
              label: Text(showSpeciesList ? 'Ukryj wybór konkretnego ptaka' : 'Wybierz konkretnego ptaka'),
            ),
            if (showSpeciesList) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 230),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in species)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: state.enabledBirdSpecies.contains(canonicalBirdSpeciesName(item)),
                        onChanged: (value) => state.toggleBirdSpeciesFilter(item, value ?? false),
                        title: Text(birdSpeciesPolishName(item), style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(
                          birdSpeciesLatinName(item).isEmpty
                              ? birdRarityGroupLabel(birdRarityGroupKey(item))
                              : '${birdSpeciesLatinName(item)} • ${birdRarityGroupLabel(birdRarityGroupKey(item))}',
                        ),
                        secondary: Icon(birdRarityGroupIcon(birdRarityGroupKey(item)), color: birdRarityGroupColor(birdRarityGroupKey(item))),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class BirdObservationSortBar extends StatelessWidget {
  const BirdObservationSortBar({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    Widget option({
      required bool newestFirst,
      required IconData icon,
      required String label,
    }) {
      final selected = state.birdObservationsNewestFirst == newestFirst;

      return ChoiceChip(
        selected: selected,
        avatar: Icon(icon, size: 18, color: selected ? Colors.white : AppTheme.green),
        label: Text(label),
        selectedColor: AppTheme.green,
        backgroundColor: const Color(0xFFF4F8F1),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w900,
        ),
        side: BorderSide(color: selected ? AppTheme.green : const Color(0xFFD6EACF)),
        onSelected: (_) => state.setBirdObservationsNewestFirst(newestFirst),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6EACF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sort, color: AppTheme.green),
              SizedBox(width: 8),
              Text('Sortowanie obserwacji według daty', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              option(newestFirst: true, icon: Icons.arrow_downward, label: 'Najnowsze pierwsze'),
              option(newestFirst: false, icon: Icons.arrow_upward, label: 'Najstarsze pierwsze'),
            ],
          ),
        ],
      ),
    );
  }
}

class BirdObservationsPage extends StatelessWidget {
  const BirdObservationsPage({super.key});

  Future<void> _openAddBirdWithGps(BuildContext context, AppState state) async {
    if (!_ensureLoggedInForChanges(context, state, 'dodawanie obserwacji ptaka')) return;
    final point = await _getLocationWithPrompt(context, state);
    if (!context.mounted || point == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddBirdObservationPage(initialPoint: point)));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final observations = state.pagedBirdObservations();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFDDEFD8),
                      child: Icon(Icons.travel_explore, color: AppTheme.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Obserwacje ptaków',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          const Text('Mapa i lista obserwacji ptaków. Tu dodasz obserwację ręcznie, z GPS albo pobierzesz publiczne wpisy z Clanga.'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (state.canCreateObjects) ...[
                      FilledButton.icon(
                        onPressed: () => _openAddBirdWithGps(context, state),
                        icon: const Icon(Icons.my_location),
                        label: const Text('Dodaj z GPS'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddBirdObservationPage())),
                        icon: const Icon(Icons.edit_location_alt),
                        label: const Text('Dodaj ręcznie'),
                      ),
                    ] else
                      FilledButton.icon(
                        onPressed: () => _showAccountDialog(context),
                        icon: const Icon(Icons.login),
                        label: const Text('Zaloguj, aby dodać obserwację'),
                      ),
                    OutlinedButton.icon(
                      onPressed: state.importingClanga ? null : () => state.importClangaObservations(limit: 40),
                      icon: Icon(state.importingClanga ? Icons.hourglass_top : Icons.cloud_download),
                      label: Text(state.importingClanga ? 'Pobieram Clanga...' : 'Pobierz z Clanga'),
                    ),
                  ],
                ),
                if (state.lastClangaImportAt != null) ...[
                  const SizedBox(height: 8),
                  Text('Ostatni import Clanga: ${DateFormat('dd.MM.yyyy HH:mm').format(state.lastClangaImportAt!)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: state.toggleBirdObservationFilters,
                  icon: Icon(state.showBirdObservationFilters ? Icons.expand_less : Icons.tune),
                  label: Text(state.showBirdObservationFilters ? 'Ukryj filtry obserwacji' : 'Pokaż filtry obserwacji'),
                ),
                if (state.showBirdObservationFilters) ...[
                  const SizedBox(height: 8),
                  BirdObservationSearchAndFilterCard(state: state),
                ],
                const SizedBox(height: 12),
                BirdObservationSortBar(state: state),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF6E6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Pokazuję tylko 5 obserwacji naraz — użyj przycisków Poprzednie/Następne.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 8),
                BirdObservationPaginationBar(state: state),
              ],
            ),
          ),
        ),
        BirdObservationsMapCard(observations: observations),
        if (observations.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Brak obserwacji. Kliknij „Dodaj z GPS”, „Dodaj ręcznie” albo „Pobierz z Clanga”.'),
            ),
          )
        else
          for (final obs in observations)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: obs.sensitive ? Colors.orange.shade100 : const Color(0xFFDDEFD8),
                  child: Icon(obs.sensitive ? Icons.visibility_off : Icons.flutter_dash, color: obs.sensitive ? Colors.orange.shade800 : AppTheme.green),
                ),
                title: Text(obs.polishSpeciesName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(
                  '${obs.latinSpeciesName.isEmpty ? 'Łacina: —' : 'Łacina: ${obs.latinSpeciesName}'}\n''Grupa: ${birdRarityGroupLabel(birdRarityGroupKey(obs.species))}\n'
                  '${DateFormat('dd.MM.yyyy HH:mm').format(obs.observedAt)} • ${obs.count} os. • ${obs.source}\n'
                  '${obs.placeDescription.isEmpty ? 'Lat ${obs.latitude.toStringAsFixed(5)}, Lng ${obs.longitude.toStringAsFixed(5)}' : obs.placeDescription}'
                  '${obs.sensitive ? '\nGatunek rzadki/wrażliwy — lokalizacja może być ukrywana.' : ''}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Nawiguj',
                  icon: const Icon(Icons.navigation),
                  onPressed: () async {
                    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${obs.latitude},${obs.longitude}');
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BirdObservationDetailsPage(observation: obs))),
              ),
            ),
      ],
    );
  }
}

class BirdObservationsMapCard extends StatelessWidget {
  const BirdObservationsMapCard({super.key, required this.observations});

  final List<BirdObservation> observations;

  LatLng get _center {
    if (observations.isEmpty) return const LatLng(52.10, 19.30);
    var lat = 0.0;
    var lng = 0.0;
    for (final o in observations) {
      lat += o.latitude;
      lng += o.longitude;
    }
    return LatLng(lat / observations.length, lng / observations.length);
  }

  double get _zoom {
    if (observations.isEmpty) return 5.8;
    if (observations.length == 1) return 12.0;
    return 6.2;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.map, color: AppTheme.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mapa obserwacji',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                Text('${observations.length} pkt', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black54)),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Mapa obserwacji na pełny ekran',
                  icon: const Icon(Icons.fullscreen, color: AppTheme.green),
                  onPressed: observations.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const BirdObservationsFullscreenMapPage()),
                          ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 280,
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: _zoom,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'pl.bartoszlawicki.ptasia_mapa_clean',
                        ),
                        MarkerLayer(
                          markers: observations.map((obs) {
                            return Marker(
                              point: LatLng(obs.latitude, obs.longitude),
                              width: 48,
                              height: 48,
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BirdObservationDetailsPage(observation: obs))),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: obs.sensitive ? Colors.orange.shade100 : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: obs.sensitive ? Colors.orange.shade800 : AppTheme.green, width: 3),
                                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
                                  ),
                                  child: Icon(
                                    obs.source == 'Clanga' ? Icons.cloud_done : Icons.flutter_dash,
                                    color: obs.sensitive ? Colors.orange.shade900 : AppTheme.green,
                                    size: 26,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    if (observations.isEmpty)
                      const Positioned.fill(
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white70,
                              borderRadius: BorderRadius.all(Radius.circular(18)),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(14),
                              child: Text(
                                'Tu pojawią się punkty obserwacji po dodaniu wpisów albo pobraniu z Clanga.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pomarańczowe punkty oznaczają gatunki rzadkie lub wrażliwe. Punkty z Clanga mogą mieć lokalizację przybliżoną z opisu.',
              style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class BirdObservationDetailsPage extends StatelessWidget {
  const BirdObservationDetailsPage({super.key, required this.observation});

  final BirdObservation observation;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final canEdit = state.canEditBirdObservation(observation);

    return Scaffold(
      appBar: AppBar(title: Text(observation.shortSpecies)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFDDEFD8), child: Icon(Icons.flutter_dash, color: AppTheme.green)),
              title: Text(observation.polishSpeciesName, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(
                '${observation.latinSpeciesName.isEmpty ? 'Nazwa łacińska: —' : 'Nazwa łacińska: ${observation.latinSpeciesName}'}\n'
                'Grupa: ${birdRarityGroupLabel(birdRarityGroupKey(observation.species))}\n'
                'Data: ${DateFormat('dd.MM.yyyy HH:mm').format(observation.observedAt)}\n'
                'Liczba: ${observation.count}\n'
                'Lat ${observation.latitude.toStringAsFixed(5)}, Lng ${observation.longitude.toStringAsFixed(5)}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Nawiguj',
                icon: const Icon(Icons.navigation),
                onPressed: () async {
                  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${observation.latitude},${observation.longitude}');
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Opis miejsca: ${observation.placeDescription.isEmpty ? '—' : observation.placeDescription}'),
                  Text('Zachowanie: ${observation.behaviour.isEmpty ? '—' : observation.behaviour}'),
                  Text('Notatki: ${observation.notes.isEmpty ? '—' : observation.notes}'),
                  Text('Autor: ${observation.ownerEmail}'),
                  Text('Źródło: ${observation.source}'),
                  if (observation.externalUrl.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => launchUrl(Uri.parse(observation.externalUrl), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Otwórz wpis źródłowy'),
                    ),
                  if (observation.sensitive) const Text('Gatunek wrażliwy', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w900)),
                  if (observation.hiddenFromUsers) const Text('Ukryta dla użytkowników', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Zdjęcia obserwacji', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 10),
                  if (observation.photoPaths.isEmpty)
                    const Text('Brak zdjęć.')
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final p in observation.photoPaths)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(p),
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 96,
                                height: 96,
                                color: const Color(0xFFEFF7EA),
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (canEdit)
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddBirdObservationPage(editObservation: observation))),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edytuj'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    await state.deleteBirdObservation(observation);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Usuń'),
                ),
                if (state.isAdmin)
                  FilledButton.icon(
                    onPressed: () async {
                      observation.hiddenFromUsers = !observation.hiddenFromUsers;
                      await state.updateBirdObservation(observation);
                    },
                    icon: Icon(observation.hiddenFromUsers ? Icons.visibility : Icons.visibility_off),
                    label: Text(observation.hiddenFromUsers ? 'Pokaż użytkownikom' : 'Ukryj'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}


class BirdObservationsFullscreenMapPage extends StatelessWidget {
  const BirdObservationsFullscreenMapPage({super.key});

  LatLng _center(List<BirdObservation> observations) {
    if (observations.isEmpty) return const LatLng(52.10, 19.30);

    var lat = 0.0;
    var lng = 0.0;

    for (final o in observations) {
      lat += o.latitude;
      lng += o.longitude;
    }

    return LatLng(lat / observations.length, lng / observations.length);
  }

  double _zoom(List<BirdObservation> observations) {
    if (observations.isEmpty) return 5.8;
    if (observations.length == 1) return 13.0;
    return 6.4;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final observations = state.latestBirdObservations(limit: 1000);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa obserwacji'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '${observations.length} pkt',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _center(observations),
              initialZoom: _zoom(observations),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'pl.bartoszlawicki.ptasia_mapa_clean',
              ),
              MarkerLayer(
                markers: observations.map((obs) {
                  return Marker(
                    point: LatLng(obs.latitude, obs.longitude),
                    width: 54,
                    height: 54,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => BirdObservationDetailsPage(observation: obs)),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: obs.sensitive ? Colors.orange.shade100 : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: obs.sensitive ? Colors.orange.shade800 : AppTheme.green,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x44000000), blurRadius: 8, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Icon(
                          obs.source == 'Clanga' ? Icons.cloud_done : Icons.flutter_dash,
                          color: obs.sensitive ? Colors.orange.shade900 : AppTheme.green,
                          size: 28,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 3)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    state.birdObservationsNewestFirst
                        ? 'Sortowanie listy: najnowsze pierwsze. Dotknij punktu, żeby otworzyć szczegóły.'
                        : 'Sortowanie listy: najstarsze pierwsze. Dotknij punktu, żeby otworzyć szczegóły.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
          if (observations.isEmpty)
            const Positioned.fill(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Brak obserwacji do pokazania na mapie.',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class AddBirdObservationPage extends StatefulWidget {
  const AddBirdObservationPage({super.key, this.initialPoint, this.editObservation});

  final LatLng? initialPoint;
  final BirdObservation? editObservation;

  @override
  State<AddBirdObservationPage> createState() => _AddBirdObservationPageState();
}

class _AddBirdObservationPageState extends State<AddBirdObservationPage> {
  final place = TextEditingController();
  final behaviour = TextEditingController();
  final notes = TextEditingController();
  final countCtrl = TextEditingController(text: '1');
  final MapController addMapController = MapController();
  final ImagePicker imagePicker = ImagePicker();
  final List<String> photoPaths = [];

  String species = birdSpecies.first;
  DateTime observedAt = DateTime.now();
  bool sensitive = false;
  late double lat;
  late double lng;

  @override
  void initState() {
    super.initState();
    final o = widget.editObservation;
    species = canonicalBirdSpeciesName(o?.species ?? birdSpecies.first);
    place.text = o?.placeDescription ?? '';
    behaviour.text = o?.behaviour ?? '';
    notes.text = o?.notes ?? '';
    countCtrl.text = '${o?.count ?? 1}';
    observedAt = o?.observedAt ?? DateTime.now();
    sensitive = (o?.sensitive ?? false) || isRareBirdSpecies(species);
    photoPaths.addAll(o?.photoPaths ?? const []);
    lat = o?.latitude ?? widget.initialPoint?.latitude ?? 54.3520;
    lng = o?.longitude ?? widget.initialPoint?.longitude ?? 18.6466;
  }

  @override
  void dispose() {
    place.dispose();
    behaviour.dispose();
    notes.dispose();
    countCtrl.dispose();
    super.dispose();
  }

  void _setSpecies(String value) {
    final autoSensitive = isRareBirdSpecies(value);
    setState(() {
      species = canonicalBirdSpeciesName(value);
      if (autoSensitive) sensitive = true;
    });
  }

  void _setLocation(LatLng point, {bool moveMap = true}) {
    setState(() {
      lat = point.latitude;
      lng = point.longitude;
    });
    if (moveMap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          addMapController.move(point, 16);
        } catch (_) {}
      });
    }
  }

  Future<void> _useGps(AppState state) async {
    final p = await _getLocationWithPrompt(context, state);
    if (p == null) return;
    _setLocation(p);
    state.showInfo('Pobrano lokalizację GPS.');
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await imagePicker.pickImage(source: source, imageQuality: 82, maxWidth: 1800);
      if (picked == null) return;
      setState(() => photoPaths.add(picked.path));
    } catch (e) {
      AppStateScope.of(context).showError('Nie udało się dodać zdjęcia: $e');
    }
  }

  Future<void> _save() async {
    final state = AppStateScope.of(context);
    final count = max(1, int.tryParse(countCtrl.text.trim()) ?? 1);

    if (widget.editObservation == null) {
      state.createBirdObservation(
        species: species,
        latitude: lat,
        longitude: lng,
        observedAt: observedAt,
        count: count,
        placeDescription: place.text,
        behaviour: behaviour.text,
        notes: notes.text,
        sensitive: sensitive,
        photoPaths: List<String>.from(photoPaths),
      );
    } else {
      final o = widget.editObservation!;
      o.species = canonicalBirdSpeciesName(species);
      o.latitude = lat;
      o.longitude = lng;
      o.observedAt = observedAt;
      o.count = count;
      o.placeDescription = place.text;
      o.behaviour = behaviour.text;
      o.notes = notes.text;
      o.sensitive = sensitive || isRareBirdSpecies(canonicalBirdSpeciesName(species));
      o.source = o.source.isEmpty ? 'Ptasie Obserwacje' : o.source;
      o.photoPaths = List<String>.from(photoPaths);
      await state.updateBirdObservation(o);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    if (!state.canCreateObjects) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dodaj obserwację')), 
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Wymagane logowanie', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text('Gość może oglądać obserwacje, ale dodawanie wymaga logowania.'),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => _showAccountDialog(context),
                      icon: const Icon(Icons.login),
                      label: const Text('Zaloguj się'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.editObservation == null ? 'Dodaj obserwację ptaka' : 'Edytuj obserwację')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Autocomplete<String>(
            initialValue: TextEditingValue(text: species),
            optionsBuilder: (value) {
              final q = _normalizeSpeciesForMatch(value.text);
              if (q.isEmpty) return birdSpecies.take(30);
              return birdSpecies.where((s) => _normalizeSpeciesForMatch(s).contains(q)).take(30);
            },
            onSelected: _setSpecies,
            fieldViewBuilder: (context, controller, focusNode, onSubmit) {
              if (controller.text != species) {
                controller.value = TextEditingValue(
                  text: species,
                  selection: TextSelection.collapsed(offset: species.length),
                );
              }
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Gatunek ptaka — polska / łacińska',
                  suffixIcon: isRareBirdSpecies(species)
                      ? const Tooltip(message: 'Rozpoznany gatunek rzadki / wrażliwy', child: Icon(Icons.visibility_off, color: Colors.orange))
                      : null,
                ),
                onChanged: _setSpecies,
              );
            },
          ),
          Builder(
            builder: (context) {
              final pl = birdSpeciesPolishName(species);
              final latin = birdSpeciesLatinName(species);

              return Card(
                color: const Color(0xFFF4F8F1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.translate, color: AppTheme.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nazwa polska: $pl\nNazwa łacińska: ${latin.isEmpty ? '—' : latin}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: countCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Liczba osobników'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(DateFormat('dd.MM.yyyy HH:mm').format(observedAt), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Data i godzina'),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: observedAt,
                    );
                    if (picked == null || !context.mounted) return;
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(observedAt));
                    setState(() {
                      observedAt = DateTime(picked.year, picked.month, picked.day, time?.hour ?? observedAt.hour, time?.minute ?? observedAt.minute);
                    });
                  },
                ),
              ),
            ],
          ),
          Builder(
            builder: (context) {
              final autoSensitive = isRareBirdSpecies(species);
              return SwitchListTile(
                value: sensitive || autoSensitive,
                onChanged: autoSensitive ? null : (v) => setState(() => sensitive = v),
                title: Text(autoSensitive ? 'Gatunek rzadki / wrażliwy rozpoznany automatycznie' : 'Gatunek wrażliwy'),
                subtitle: Text(
                  autoSensitive
                      ? 'Aplikacja sama oznaczyła ten gatunek jako wrażliwy. Dokładną lokalizację można ukryć publicznie.'
                      : 'Zaznacz ręcznie np. przy rzadkich gatunkach albo gnieździe. Admin może ukryć lokalizację publicznie.',
                ),
              );
            },
          ),
          TextField(controller: place, decoration: const InputDecoration(labelText: 'Opis miejsca'), maxLines: 2),
          const SizedBox(height: 10),
          TextField(controller: behaviour, decoration: const InputDecoration(labelText: 'Zachowanie ptaka'), maxLines: 2),
          const SizedBox(height: 10),
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notatki'), maxLines: 3),
          const SizedBox(height: 16),
          _SectionTitle('Zdjęcia obserwacji'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final path in photoPaths)
                    _PhotoThumb(path: path, onRemove: () => setState(() => photoPaths.remove(path))),
                  _PhotoButton(icon: Icons.photo_camera, label: 'Aparat', onTap: () => _pickPhoto(ImageSource.camera)),
                  _PhotoButton(icon: Icons.photo_library, label: 'Galeria', onTap: () => _pickPhoto(ImageSource.gallery)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _SectionTitle('Lokalizacja obserwacji'),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SizedBox(
                  height: 230,
                  child: FlutterMap(
                    mapController: addMapController,
                    options: MapOptions(
                      initialCenter: LatLng(lat, lng),
                      initialZoom: 15,
                      onTap: (_, point) => _setLocation(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'pl.bartoszlawicki.ptasia_mapa_clean',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(lat, lng),
                            width: 62,
                            height: 62,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 54, shadows: [Shadow(color: Colors.black38, blurRadius: 8)]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    children: [
                      Text('Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _useGps(state),
                          icon: const Icon(Icons.my_location),
                          label: const Text('Użyj GPS'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('Możesz też dotknąć mapy, aby ręcznie wskazać miejsce obserwacji.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Zapisz obserwację')),
        ],
      ),
    );
  }
}

class ListPage extends StatelessWidget {
  const ListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final sites = state.searchedSites();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const StatsPanel(),
        NestBoxOccupancyStatsCard(state: state),
        SiteSearchCard(state: state, sites: sites),
        if (sites.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                state.loggedIn || state.isAdmin
                    ? (state.nestSiteSearchQuery.isNotEmpty
                        ? 'Brak budki o takiej nazwie. Wyczyść szukanie albo wpisz inną nazwę.'
                        : 'Brak Twoich obiektów do wyświetlenia. Dodaj pierwszy obiekt z mapy lub GPS.')
                    : (state.nestSiteSearchQuery.isNotEmpty
                        ? 'Brak budki o takiej nazwie. Wyczyść szukanie albo wpisz inną nazwę.'
                        : 'Brak obiektów do wyświetlenia. Dodawanie wymaga zalogowania.'),
              ),
            ),
          ),
        for (final s in sites)
          Card(
            child: ListTile(
              leading: ObjectMarker(site: s),
              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${s.type}\n${s.technicalStatus} • ${s.ownerEmail}'),
              isThreeLine: true,
              trailing: s.deleteRequested ? const Icon(Icons.report, color: Colors.red) : null,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SiteDetailsPage(site: s))),
            ),
          ),
      ],
    );
  }
}


class NestBoxOccupancyStatsCard extends StatelessWidget {
  const NestBoxOccupancyStatsCard({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final top = state.mostCommonNestBoxBirds(limit: 8);
    final occupiedTotal = top.fold<int>(0, (sum, item) => sum + item.value);
    final totalBoxes = state.visibleSites().where((s) => s.type.toLowerCase().contains('bud')).length;

    return Card(
      color: const Color(0xFFF4F8F1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.home_work_outlined, color: AppTheme.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ptaki najczęściej zajmujące budki',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Liczone tylko z budek/obiektów, gdzie zaznaczono zajęcie i wpisano gatunek.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const SizedBox(height: 10),
            if (top.isEmpty)
              const Text(
                'Brak danych. Przy kontroli budki zaznacz „ptaki obecne/zajęta” i wpisz gatunek.',
                style: TextStyle(fontWeight: FontWeight.w700),
              )
            else ...[
              for (var i = 0; i < top.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          '${i + 1}.',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              birdSpeciesPolishName(top[i].key),
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            if (birdSpeciesLatinName(top[i].key).isNotEmpty)
                              Text(
                                birdSpeciesLatinName(top[i].key),
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppTheme.green.withOpacity(0.35)),
                        ),
                        child: Text(
                          '${top[i].value} bud.',
                          style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.green),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Razem zajętych wpisów: $occupiedTotal. Budki w bazie: $totalBoxes.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class StatsPanel extends StatelessWidget {
  const StatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final birds = state.commonBirds();
    final latest = state.latestSites();
    final latestBirds = state.latestBirdObservations(limit: 5);

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                const Icon(Icons.account_circle, color: AppTheme.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Jesteś zalogowany jako: ${state.roleLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (state.loggedIn)
                  TextButton.icon(
                    onPressed: state.signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Wyloguj'),
                  ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ostatnio dodane budki / obiekty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (latest.isEmpty)
                  const Text('Brak ostatnio dodanych obiektów.')
                else
                  for (final s in latest)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ObjectMarker(site: s),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${s.type} • ${DateFormat('dd.MM.yyyy').format(s.createdAt)}'),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SiteDetailsPage(site: s))),
                    ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ostatnie obserwacje ptaków', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (latestBirds.isEmpty)
                  const Text('Brak niezależnych obserwacji ptaków.')
                else
                  for (final o in latestBirds)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.flutter_dash, color: AppTheme.green),
                      title: Text(o.shortSpecies, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${DateFormat('dd.MM.yyyy HH:mm').format(o.observedAt)} • ${o.count} os.'),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BirdObservationDetailsPage(observation: o))),
                    ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Jakich ptaków jest najwięcej', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (birds.isEmpty)
                  const Text('Brak wpisanych obserwacji ptaków.')
                else
                  for (final e in birds.entries.take(8))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.flutter_dash, color: AppTheme.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700))),
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: const Color(0xFFDDEFD8),
                            child: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.green)),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


class SiteDetailsPage extends StatelessWidget {
  const SiteDetailsPage({super.key, required this.site});

  final NestSite site;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final canEdit = state.canEdit(site);

    return Scaffold(
      appBar: AppBar(title: Text(site.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        children: [
          Card(
            child: ListTile(
              leading: ObjectMarker(site: site),
              title: Text(site.type),
              subtitle: Text('Lat ${site.latitude.toStringAsFixed(5)}, Lng ${site.longitude.toStringAsFixed(5)}\nStatus: ${site.technicalStatus}'),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Nawiguj',
                icon: const Icon(Icons.navigation),
                onPressed: () => _openGoogleMapsTo(site),
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Opis: ${site.placeDescription.isEmpty ? '—' : site.placeDescription}'),
                  Text('Uszkodzenie: ${site.damageDescription.isEmpty ? '—' : site.damageDescription}'),
                  Text('Notatki: ${site.notes.isEmpty ? '—' : site.notes}'),
                  Text('Właściciel: ${site.ownerEmail}'),
                  if (site.hiddenFromUsers) const Text('Ukryty dla użytkowników', style: TextStyle(color: Colors.grey)),
                  if (site.deleteRequested) Text('Prośba o usunięcie: ${site.deleteReason}', style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Zdjęcia obiektu', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 10),
                  if (site.photoPaths.isEmpty)
                    const Text('Brak zdjęć.')
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final p in site.photoPaths)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(p),
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 96,
                                height: 96,
                                color: const Color(0xFFEFF7EA),
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (canEdit) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _addPhotoToExistingSite(context, site, ImageSource.camera),
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Dodaj z aparatu'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _addPhotoToExistingSite(context, site, ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Dodaj z galerii'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (canEdit)
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddSitePage(editSite: site))),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edytuj'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    await state.deleteSite(site);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Usuń'),
                ),
                if (state.isAdmin)
                  FilledButton.icon(
                    onPressed: () async {
                      site.hiddenFromUsers = !site.hiddenFromUsers;
                      await state.updateSite(site);
                    },
                    icon: Icon(site.hiddenFromUsers ? Icons.visibility : Icons.visibility_off),
                    label: Text(site.hiddenFromUsers ? 'Pokaż użytkownikom' : 'Ukryj'),
                  ),
              ],
            )
          else if (state.loggedIn)
            FilledButton.icon(
              onPressed: () => _showDeleteRequestDialog(context, site),
              icon: const Icon(Icons.report),
              label: const Text('Zgłoś prośbę o usunięcie'),
            )
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('Tryb Gość: możesz oglądać obiekt, ale dodawanie, edycja, zdjęcia i kontrole wymagają logowania.'),
              ),
            ),
          const SizedBox(height: 16),
          if (state.canAddInspections)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddInspectionPage(site: site))),
              icon: const Icon(Icons.fact_check),
              label: const Text('Dodaj kontrolę'),
            ),
          const SizedBox(height: 12),
          const Text('Kontrole i stwierdzenia ptaków', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          for (final i in site.inspections)
            Card(
              child: ListTile(
                leading: Icon(i.birdsPresent ? Icons.flutter_dash : Icons.check_circle_outline),
                title: Text(DateFormat('dd.MM.yyyy').format(i.date)),
                subtitle: Text(
                  'Kontrolujący: ${i.inspector.isEmpty ? '—' : i.inspector}\n'
                  'Czyszczona: ${i.cleaned ? 'tak' : 'nie'}'
                  '${i.birdsPresent ? '\nPtaki: ${i.birdSpecies}, jaja ${i.eggsCount}, pisklęta ${i.chicksCount}, dorosłe ${i.adultsCount}' : '\nPtaki: nie'}'
                  '${i.notes.isNotEmpty ? '\n${i.notes}' : ''}',
                ),
                isThreeLine: true,
              ),
            ),
        ],
      ),
    );
  }
}

class AddInspectionPage extends StatefulWidget {
  const AddInspectionPage({super.key, required this.site});

  final NestSite site;

  @override
  State<AddInspectionPage> createState() => _AddInspectionPageState();
}

class _AddInspectionPageState extends State<AddInspectionPage> {
  final inspector = TextEditingController();
  final cleanedBy = TextEditingController();
  final notes = TextEditingController();
  final eggs = TextEditingController(text: '0');
  final chicks = TextEditingController(text: '0');
  final adults = TextEditingController(text: '0');

  DateTime date = DateTime.now();
  bool cleaned = false;
  bool birds = false;
  String species = birdSpecies.first;
  String condition = 'Dobry';

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    if (!state.canAddInspections) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dodaj kontrolę')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Wymagane logowanie', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text('Gość może oglądać obiekty na mapie, ale dodawanie kontroli i czyszczenia wymaga logowania.'),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => _showAccountDialog(context),
                      icon: const Icon(Icons.login),
                      label: const Text('Zaloguj się'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dodaj kontrolę')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(DateFormat('dd.MM.yyyy').format(date)),
            subtitle: const Text('Data kontroli'),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: date,
              );
              if (picked != null) setState(() => date = picked);
            },
          ),
          TextField(controller: inspector, decoration: const InputDecoration(labelText: 'Kontrolujący')),
          Card(
            color: _isCleaningPeriod(DateTime.now()) ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _cleaningCounterText(DateTime.now()),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          SwitchListTile(
            value: cleaned,
            onChanged: (v) => setState(() => cleaned = v),
            title: const Text('Budka czyszczona'),
            subtitle: const Text('Czyszczenie wpisuj tylko wtedy, gdy faktycznie zostało wykonane.'),
          ),
          if (cleaned) TextField(controller: cleanedBy, decoration: const InputDecoration(labelText: 'Kto czyścił')),
          DropdownButtonFormField<String>(
            value: condition,
            decoration: const InputDecoration(labelText: 'Stan'),
            items: technicalStatuses.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => condition = v ?? condition),
          ),
          SwitchListTile(
            value: birds,
            onChanged: (v) => setState(() => birds = v),
            title: const Text('Czy są ptaki?'),
          ),
          if (birds) ...[
            Autocomplete<String>(
              initialValue: TextEditingValue(text: species),
              optionsBuilder: (value) {
                final q = value.text.toLowerCase();
                return birdSpecies.where((s) => s.toLowerCase().contains(q)).take(25);
              },
              onSelected: (v) => species = v,
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                controller.text = species;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'Gatunek ptaka'),
                  onChanged: (v) => species = v,
                );
              },
            ),
            Row(
              children: [
                Expanded(child: TextField(controller: eggs, decoration: const InputDecoration(labelText: 'Jaja'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: chicks, decoration: const InputDecoration(labelText: 'Pisklęta'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: adults, decoration: const InputDecoration(labelText: 'Dorosłe'), keyboardType: TextInputType.number)),
              ],
            ),
          ],
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notatki'), maxLines: 3),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () async {
              widget.site.inspections.add(Inspection(
                id: const Uuid().v4(),
                date: date,
                inspector: inspector.text,
                cleaned: cleaned,
                cleanedBy: cleanedBy.text,
                condition: condition,
                birdsPresent: birds,
                birdSpecies: birds ? species : '',
                eggsCount: int.tryParse(eggs.text) ?? 0,
                chicksCount: int.tryParse(chicks.text) ?? 0,
                adultsCount: int.tryParse(adults.text) ?? 0,
                notes: notes.text,
                locallyChanged: true,
              ));
              await state.updateSite(widget.site);
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.save),
            label: const Text('Zapisz kontrolę'),
          ),
        ],
      ),
    );
  }
}

class NearbyPage extends StatefulWidget {
  const NearbyPage({super.key});

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  final distances = const [10, 30, 50, 100, 250, 500];
  int radiusMeters = 50;
  LatLng? current;
  bool loading = false;
  String? error;
  bool autoStartedNearby = false;

  Future<void> _refresh(AppState state) async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      if (!state.syncing) {
        await state.sync(silent: true);
      }

      if (!mounted) return;
      final p = await _getLocationWithPrompt(context, state);
      if (p != null && mounted) {
        setState(() => current = p);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<NearbySite> _nearby(AppState state) {
    final p = current;
    if (p == null) return <NearbySite>[];

    final distance = const Distance();
    final result = <NearbySite>[];

    for (final site in state.visibleSites()) {
      if (site.deleted || site.hiddenFromUsers) continue;
      final meters = distance.as(LengthUnit.Meter, p, LatLng(site.latitude, site.longitude));
      if (meters <= radiusMeters) {
        result.add(NearbySite(site: site, distanceMeters: meters));
      }
    }

    result.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return result;
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!autoStartedNearby) {
      autoStartedNearby = true;
      Future.microtask(() => _refresh(AppStateScope.of(context)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final items = _nearby(state);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Budki w pobliżu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Wybierz promień i pobierz GPS. Lista pokaże najbliższe budki z odległością od Ciebie.'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in distances)
                      ChoiceChip(
                        label: Text('$d m'),
                        selected: radiusMeters == d,
                        onSelected: (_) => setState(() => radiusMeters = d),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: loading ? null : () => _refresh(state),
                    icon: loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                    label: Text(loading ? 'Pobieram GPS...' : 'Pobierz GPS i pokaż budki'),
                  ),
                ),
                if (current != null) ...[
                  const SizedBox(height: 8),
                  Text('Twoja pozycja: ${current!.latitude.toStringAsFixed(6)}, ${current!.longitude.toStringAsFixed(6)}'),
                ],
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
                ],
              ],
            ),
          ),
        ),
        if (current == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Kliknij GPS, żeby pokazać budki w pobliżu.'),
            ),
          )
        else if (items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text('Brak budek w promieniu $radiusMeters m.'),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Znaleziono: ${items.length}', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        for (final item in items)
          Card(
            child: ListTile(
              leading: ObjectMarker(site: item.site),
              title: Text(item.site.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('${item.site.type}\nOdległość: ${item.distanceText} • Stan: ${item.site.technicalStatus}'),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Nawiguj',
                icon: const Icon(Icons.navigation),
                onPressed: () => _openGoogleMapsTo(item.site),
              ),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SiteDetailsPage(site: item.site))),
            ),
          ),
      ],
    );
  }
}


class RepairPage extends StatelessWidget {
  const RepairPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final repairs = state.repairSites();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        Card(
          color: const Color(0xFFFFF3E0),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.build_circle, color: Colors.red, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Budki / obiekty zgłoszone do naprawy: ${repairs.length}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (repairs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Brak obiektów oznaczonych jako uszkodzone lub wymagające naprawy.'),
            ),
          ),
        for (final s in repairs)
          Card(
            child: ListTile(
              leading: ObjectMarker(site: s),
              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text([
                s.type,
                'Stan: ${s.technicalStatus}',
                if (s.damageDescription.trim().isNotEmpty) 'Opis: ${s.damageDescription}',
                if (s.notes.trim().isNotEmpty) 'Notatki: ${s.notes}',
                'Aktualizacja: ${DateFormat('dd.MM.yyyy').format(s.updatedAt)}',
              ].join('\n')),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SiteDetailsPage(site: s))),
            ),
          ),
      ],
    );
  }
}

class CleaningPage extends StatelessWidget {
  const CleaningPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final now = DateTime.now();
    final inPeriod = _isCleaningPeriod(now);
    final start = _cleaningSeasonStart(now);
    final endVisible = _cleaningSeasonEndExclusive(start).subtract(const Duration(days: 1));
    final toClean = state.toCleanSites();
    final cleaned = state.cleanedSites();
    final format = DateFormat('dd.MM.yyyy');

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        Card(
          color: inPeriod ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(inPeriod ? Icons.cleaning_services : Icons.event, color: AppTheme.green, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_cleaningCounterText(now)}\nOkres czyszczenia: 16.10 – koniec lutego.',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: AppTheme.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Aktualny sezon: ${format.format(start)} – ${format.format(endVisible)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!state.loggedIn && !state.isAdmin)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('Tryb Gość: listę można oglądać, ale wpisanie czyszczenia wymaga logowania.'),
            ),
          ),
        _CleaningSectionHeader(
          title: 'Do wyczyszczenia',
          count: toClean.length,
          icon: Icons.cleaning_services,
        ),
        if (toClean.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Wszystkie widoczne budki mają wpisane czyszczenie w tym sezonie.'),
            ),
          )
        else
          for (final s in toClean)
            _CleaningSiteCard(
              site: s,
              subtitle: [
                s.type,
                if (_latestCleanedInspection(s) != null) 'Ostatnio czyszczona: ${format.format(_latestCleanedInspection(s)!.date)}',
                if (_latestCleanedInspection(s) == null) 'Brak wpisu o czyszczeniu',
              ].join('\n'),
              actionLabel: state.canAddInspections ? 'Wpisz czyszczenie' : 'Tylko podgląd',
              actionIcon: state.canAddInspections ? Icons.edit_note : Icons.visibility,
              onAction: state.canAddInspections
                  ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddInspectionPage(site: s)))
                  : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SiteDetailsPage(site: s))),
            ),
        const SizedBox(height: 10),
        _CleaningSectionHeader(
          title: 'Wyczyszczone',
          count: cleaned.length,
          icon: Icons.check_circle,
        ),
        if (cleaned.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Brak wpisów o czyszczeniu.'),
            ),
          )
        else
          for (final s in cleaned)
            _CleaningSiteCard(
              site: s,
              subtitle: 'Czyszczona: ${format.format(_latestCleanedInspection(s)!.date)}'
                  '${_latestCleanedInspection(s)!.cleanedBy.trim().isNotEmpty ? '\nPrzez: ${_latestCleanedInspection(s)!.cleanedBy}' : ''}',
              actionLabel: 'Szczegóły',
              actionIcon: Icons.chevron_right,
              onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SiteDetailsPage(site: s))),
            ),
      ],
    );
  }
}


class _CleaningSectionHeader extends StatelessWidget {
  const _CleaningSectionHeader({
    required this.title,
    required this.count,
    required this.icon,
  });

  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$title: $count',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CleaningSiteCard extends StatelessWidget {
  const _CleaningSiteCard({
    required this.site,
    required this.subtitle,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  final NestSite site;
  final String subtitle;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SiteDetailsPage(site: site))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 48, height: 48, child: ObjectMarker(site: site)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(site.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                        const SizedBox(height: 4),
                        Text(subtitle, style: const TextStyle(height: 1.25)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String exportText = '';
  final importController = TextEditingController();
  final emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(onPressed: () => setState(() => exportText = state.exportCsv()), child: const Text('CSV')),
                FilledButton(onPressed: () => setState(() => exportText = state.exportKml()), child: const Text('KML')),
                FilledButton(onPressed: () => setState(() => exportText = state.exportGpx()), child: const Text('GPX')),
                FilledButton.icon(
                  onPressed: exportText.isEmpty ? null : () => Clipboard.setData(ClipboardData(text: exportText)),
                  icon: const Icon(Icons.copy),
                  label: const Text('Kopiuj'),
                ),
              ],
            ),
          ),
        ),
        if (exportText.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(exportText, maxLines: 12),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: importController,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Wklej GPX/KML do importu'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => state.importSimpleGpxKml(importController.text),
                  icon: const Icon(Icons.upload),
                  label: const Text('Importuj wklejony tekst'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: state.importingGpx ? null : () => state.importNestSitesFromGpxFile(),
                  icon: const Icon(Icons.upload_file),
                  label: Text(state.importingGpx ? 'Wczytuję GPX...' : 'Wczytaj budki z pliku GPX'),
                ),
              ],
            ),
          ),
        ),
        if (state.isSuperAdmin)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  const Text('Nadawanie uprawnień administratora', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email użytkownika')),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => state.grantAdmin(emailController.text),
                    child: const Text('Nadaj admina'),
                  ),
                ],
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prośby o usunięcie', style: TextStyle(fontWeight: FontWeight.bold)),
                for (final s in state.sites.where((s) => s.deleteRequested && !s.deleted))
                  ListTile(
                    title: Text(s.name),
                    subtitle: Text(s.deleteReason),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => state.deleteSite(s),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void _showDeleteRequestDialog(BuildContext context, NestSite site) {
  final controller = TextEditingController();
  final state = AppStateScope.of(context);
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Prośba o usunięcie'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: 'Dlaczego obiekt ma być usunięty?'),
        maxLines: 4,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
        FilledButton(
          onPressed: () async {
            await state.requestDelete(site, controller.text);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Wyślij'),
        ),
      ],
    ),
  );
}

void _showInfoDialog(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: 'Ptasie Obserwacje',
    applicationVersion: appVersionName,
    children: const [
      Text('© Bartosz Ławicki. Wszystkie prawa zastrzeżone.'),
      SizedBox(height: 8),
      Text('Kontakt: bartoszlawicki@gmail.com'),
    ],
  );
}

void _showUpdateDialog(BuildContext context, UpdateInfo info) {
  final state = AppStateScope.of(context);
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Dostępna aktualizacja'),
      content: SingleChildScrollView(
        child: Text(
          'Nowa wersja: ${info.versionName} (${info.versionCode})\n'
          'Obecna wersja: $appVersionName ($appVersionCode)\n\n'
          '${info.notes.isEmpty ? 'Kliknij Pobierz, aby otworzyć GitHub Release z plikiem APK.' : info.notes}\n\n'
          'Po pobraniu Android poprosi o potwierdzenie instalacji aktualizacji.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Później')),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            state.openUpdateDownload();
          },
          icon: const Icon(Icons.download),
          label: const Text('Pobierz'),
        ),
      ],
    ),
  );
}

void _showAdminPasswordDialog(BuildContext context) {
  final controller = TextEditingController();
  final state = AppStateScope.of(context);
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Hasło administratora'),
      content: TextField(
        controller: controller,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Hasło'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
        FilledButton(
          onPressed: () {
            state.enableAdminWithPassword(controller.text);
            Navigator.pop(context);
          },
          child: const Text('Włącz'),
        ),
      ],
    ),
  );
}

void _showAccountDialog(BuildContext context) {
  final state = AppStateScope.of(context);
  final email = TextEditingController(text: state.currentUser?.email ?? '');
  final pass = TextEditingController();
  bool rodo = false;
  bool technicalContact = false;
  bool registerMode = false;
  bool hidePassword = true;
  bool busy = false;

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        if (state.loggedIn) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Konto'),
            content: Text('Zalogowano jako:\n${state.currentUser?.email}\nRola: ${state.userRole}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zamknij')),
              FilledButton.icon(
                onPressed: () async {
                  await state.signOut();
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Wyloguj się'),
              ),
            ],
          );
        }

        final media = MediaQuery.of(context);
        final keyboard = media.viewInsets.bottom;
        final maxHeight = (media.size.height - keyboard - 48).clamp(320.0, 720.0).toDouble();

        Future<void> runAuth(Future<void> Function() action, {bool closeWhenLoggedIn = true}) async {
          if (busy) return;
          setState(() => busy = true);
          await action();
          if (context.mounted) {
            setState(() => busy = false);
            if (closeWhenLoggedIn && state.loggedIn) {
              Navigator.pop(context);
            }
          }
        }

        return Dialog(
          insetPadding: EdgeInsets.fromLTRB(14, 18, 14, keyboard > 0 ? 12 : 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: const Color(0xFFF4F8F1),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 540),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_circle, color: AppTheme.green, size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Logowanie / rejestracja',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF132015),
                                ),
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 30)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _AuthSegmentButton(
                            label: 'Zaloguj',
                            selected: !registerMode,
                            onTap: () => setState(() => registerMode = false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AuthSegmentButton(
                            label: 'Rejestruj',
                            selected: registerMode,
                            onTap: () => setState(() => registerMode = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pass,
                      obscureText: hidePassword,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Hasło',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => hidePassword = !hidePassword),
                          icon: Icon(hidePassword ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                    ),
                    if (registerMode) ...[
                      const SizedBox(height: 10),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF7EA),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFDDE8D4)),
                        ),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              dense: true,
                              value: rodo,
                              onChanged: (v) => setState(() => rodo = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                'Akceptuję przetwarzanie danych w celu obsługi konta i zgłoszeń.',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                              ),
                            ),
                            CheckboxListTile(
                              dense: true,
                              value: technicalContact,
                              onChanged: (v) => setState(() => technicalContact = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                'Zgoda dobrowolna: kontakt techniczny w sprawie aplikacji.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!rodo)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Do rejestracji wymagana jest pierwsza zgoda.',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ),
                    ] else ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: busy
                              ? null
                              : () => runAuth(
                                    () => state.sendPasswordReset(email.text),
                                    closeWhenLoggedIn: false,
                                  ),
                          child: const Text('Nie pamiętasz hasła?'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () {
                                if (registerMode && !rodo) {
                                  state.showError('Do rejestracji wymagana jest pierwsza zgoda.');
                                  return;
                                }
                                runAuth(
                                  () => registerMode
                                      ? state.register(email.text, pass.text)
                                      : state.signIn(email.text, pass.text),
                                );
                              },
                        icon: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(registerMode ? Icons.person_add_alt_1 : Icons.login),
                        label: Text(registerMode ? 'Zarejestruj' : 'Zaloguj'),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: busy
                            ? null
                            : () => runAuth(
                                  () => state.diagnoseAuth(),
                                  closeWhenLoggedIn: false,
                                ),
                        icon: const Icon(Icons.health_and_safety_outlined),
                        label: const Text('Sprawdź połączenie z Supabase'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade400)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('albo'),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade400)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => runAuth(
                                  () => state.signInWithGoogle(),
                                  closeWhenLoggedIn: false,
                                ),
                        icon: const Icon(Icons.g_mobiledata, size: 34),
                        label: const Text('Kontynuuj z Google'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: busy ? null : () => setState(() => registerMode = !registerMode),
                      child: Text(registerMode ? 'Masz już konto? Zaloguj się' : 'Nie masz konta? Zarejestruj się'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _AuthSegmentButton extends StatelessWidget {
  const _AuthSegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? Colors.white : const Color(0xFFD9DED6),
          foregroundColor: selected ? AppTheme.green : Colors.grey.shade600,
          side: BorderSide(
            color: selected ? const Color(0xFFB6DEB7) : Colors.transparent,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        child: Text(label),
      ),
    );
  }
}

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final password = TextEditingController();
  bool hidePassword = true;
  bool busy = false;

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final pass = password.text.trim();
    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasło powinno mieć minimum 6 znaków.')),
      );
      return;
    }

    setState(() => busy = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: pass),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasło zostało zmienione.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się zmienić hasła: $e')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nowe hasło')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Wpisz nowe hasło do konta Ptasiej Mapy.'),
            const SizedBox(height: 16),
            TextField(
              controller: password,
              obscureText: hidePassword,
              decoration: InputDecoration(
                labelText: 'Nowe hasło',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => hidePassword = !hidePassword),
                  icon: Icon(hidePassword ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : save,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: const Text('Zapisz nowe hasło'),
            ),
          ],
        ),
      ),
    );
  }
}
