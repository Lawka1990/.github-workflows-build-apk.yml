import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const appVersionLabel = 'V4 — prawdziwe wyszukiwania i organizer ofert';
const _offersStorageKey = 'offers_v4';
const _criteriaStorageKey = 'criteria_v4';
const _legacyOffersStorageKey = 'offers_v3';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.bg,
      systemNavigationBarColor: AppColors.bg,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const LowcaApp());
}

class LowcaApp extends StatelessWidget {
  const LowcaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Łowca Mieszkań',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.blue,
          secondary: AppColors.green,
          surface: AppColors.card,
          error: AppColors.red,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.field,
          labelStyle: const TextStyle(color: AppColors.muted),
          hintStyle: const TextStyle(color: AppColors.muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.card,
          contentTextStyle: TextStyle(color: AppColors.text),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppColors {
  static const bg = Color(0xFF061321);
  static const bg2 = Color(0xFF081C2E);
  static const card = Color(0xFF11263D);
  static const card2 = Color(0xFF0B1D30);
  static const field = Color(0xFF071A2A);
  static const border = Color(0xFF1C3B5B);
  static const blue = Color(0xFF1683FF);
  static const green = Color(0xFF24C86B);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF59E0B);
  static const purple = Color(0xFF9B7BFF);
  static const text = Color(0xFFF4F8FF);
  static const muted = Color(0xFFA7B5C6);
}

const priceFromOptions = <int>[
  0,
  200000,
  300000,
  400000,
  500000,
  600000,
  700000,
];

const priceToOptions = <int>[
  400000,
  500000,
  600000,
  700000,
  800000,
  900000,
  1000000,
  1200000,
  1500000,
];

const areaFromOptions = <int>[20, 25, 30, 35, 40, 45, 50, 60];
const areaToOptions = <int>[35, 45, 55, 65, 75, 85, 100, 120, 150];
const roomOptions = <String>['Dowolnie', '1', '2', '2 - 3', '3', '4+'];

const ownershipOptions = <String>[
  'Spółdzielcze własnościowe',
  'Własnościowe — dowolna forma',
  'Pełna / odrębna własność',
  'Bez księgi wieczystej',
  'Brak wyboru / wszystkie',
];

class SearchCriteria {
  String location;
  int priceFrom;
  int priceTo;
  int areaFrom;
  int areaTo;
  String rooms;
  String ownership;
  String keywords;
  String excludedKeywords;
  bool secondaryOnly;

  SearchCriteria({
    this.location = 'Gdańsk',
    this.priceFrom = 0,
    this.priceTo = 700000,
    this.areaFrom = 35,
    this.areaTo = 65,
    this.rooms = '2 - 3',
    this.ownership = 'Spółdzielcze własnościowe',
    this.keywords = '',
    this.excludedKeywords = 'TBS, udział, lokatorskie',
    this.secondaryOnly = true,
  });

  String get short {
    final price = priceFrom > 0
        ? '${money(priceFrom)}–${money(priceTo)}'
        : 'do ${money(priceTo)}';
    final roomText = rooms == 'Dowolnie' ? 'dowolne pokoje' : '$rooms pok.';
    return '$location · $price · $areaFrom–$areaTo m² · $roomText';
  }

  Map<String, dynamic> toJson() => {
        'location': location,
        'priceFrom': priceFrom,
        'priceTo': priceTo,
        'areaFrom': areaFrom,
        'areaTo': areaTo,
        'rooms': rooms,
        'ownership': ownership,
        'keywords': keywords,
        'excludedKeywords': excludedKeywords,
        'secondaryOnly': secondaryOnly,
      };

  factory SearchCriteria.fromJson(Map<String, dynamic> json) {
    final location = '${json['location'] ?? 'Gdańsk'}';
    final rooms = '${json['rooms'] ?? '2 - 3'}';
    final ownership = '${json['ownership'] ?? 'Spółdzielcze własnościowe'}';
    final priceFrom = _safeInt(json['priceFrom'], priceFromOptions, 0);
    final priceTo = _safeInt(json['priceTo'], priceToOptions, 700000);
    final areaFrom = _safeInt(json['areaFrom'], areaFromOptions, 35);
    final areaTo = _safeInt(json['areaTo'], areaToOptions, 65);
    return SearchCriteria(
      location: cityMap.containsKey(location) ? location : 'Gdańsk',
      priceFrom: priceFrom,
      priceTo: priceTo,
      areaFrom: areaFrom,
      areaTo: areaTo,
      rooms: roomOptions.contains(rooms) ? rooms : '2 - 3',
      ownership: ownershipOptions.contains(ownership)
          ? ownership
          : 'Spółdzielcze własnościowe',
      keywords: '${json['keywords'] ?? ''}',
      excludedKeywords: '${json['excludedKeywords'] ?? ''}',
      secondaryOnly: json['secondaryOnly'] != false,
    );
  }
}

int _safeInt(dynamic value, List<int> allowed, int fallback) {
  final parsed = int.tryParse('$value');
  return parsed != null && allowed.contains(parsed) ? parsed : fallback;
}

class CityData {
  final String name;
  final String olx;
  final String otodom;
  final String morizon;
  final String gratka;
  final String adresowo;

  const CityData(
    this.name,
    this.olx,
    this.otodom,
    this.morizon,
    this.gratka,
    this.adresowo,
  );
}

const cityMap = <String, CityData>{
  'Gdańsk': CityData('Gdańsk', 'gdansk', 'gdansk', 'gdansk', 'gdansk', 'gdansk'),
  'Gdynia': CityData('Gdynia', 'gdynia', 'gdynia', 'gdynia', 'gdynia', 'gdynia'),
  'Sopot': CityData('Sopot', 'sopot', 'sopot', 'sopot', 'sopot', 'sopot'),
  'Pruszcz Gdański': CityData(
    'Pruszcz Gdański',
    'pruszcz-gdanski',
    'pruszcz-gdanski',
    'pruszcz-gdanski',
    'pruszcz-gdanski',
    'pruszcz-gdanski',
  ),
  'Kowale': CityData('Kowale', 'kowale', 'kowale', 'kowale', 'kowale', 'kowale'),
  'Rumia': CityData('Rumia', 'rumia', 'rumia', 'rumia', 'rumia', 'rumia'),
  'Reda': CityData('Reda', 'reda', 'reda', 'reda', 'reda', 'reda'),
  'Wejherowo': CityData(
    'Wejherowo',
    'wejherowo',
    'wejherowo',
    'wejherowo',
    'wejherowo',
    'wejherowo',
  ),
};

class PortalLink {
  final String name;
  final String logo;
  final String domain;
  final Color color;
  final String directUrl;
  final String preciseUrl;
  final String note;

  const PortalLink({
    required this.name,
    required this.logo,
    required this.domain,
    required this.color,
    required this.directUrl,
    required this.preciseUrl,
    required this.note,
  });
}

const statusLabels = <String, String>{
  'NOWA': 'Nowa',
  'CIEKAWA': 'Ciekawa',
  'KONTAKT': 'Do kontaktu',
  'UMOWIONA': 'Umówiona',
  'OBEJRZANA': 'Obejrzana',
  'ODRZUCONA': 'Odrzucona',
};

class Offer {
  final String id;
  final String title;
  final String portal;
  final String city;
  final String district;
  final String ownership;
  final String description;
  final String image;
  final String url;
  final String status;
  final int price;
  final double area;
  final int rooms;
  final bool favorite;
  final String phone;
  final String notes;
  final String addedAt;
  final String updatedAt;

  const Offer({
    required this.id,
    required this.title,
    required this.portal,
    required this.city,
    required this.district,
    required this.ownership,
    required this.description,
    required this.image,
    required this.url,
    required this.status,
    required this.price,
    required this.area,
    required this.rooms,
    required this.favorite,
    required this.phone,
    required this.notes,
    required this.addedAt,
    required this.updatedAt,
  });

  int get score => analyzeOffer('$title $ownership $description $notes').score;

  double get pricePerMeter => price > 0 && area > 0 ? price / area : 0;

  DateTime get addedDate =>
      DateTime.tryParse(addedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);

  Offer copyWith({
    String? title,
    String? portal,
    String? city,
    String? district,
    String? ownership,
    String? description,
    String? image,
    String? url,
    String? status,
    int? price,
    double? area,
    int? rooms,
    bool? favorite,
    String? phone,
    String? notes,
    String? addedAt,
    String? updatedAt,
  }) {
    return Offer(
      id: id,
      title: title ?? this.title,
      portal: portal ?? this.portal,
      city: city ?? this.city,
      district: district ?? this.district,
      ownership: ownership ?? this.ownership,
      description: description ?? this.description,
      image: image ?? this.image,
      url: url ?? this.url,
      status: status ?? this.status,
      price: price ?? this.price,
      area: area ?? this.area,
      rooms: rooms ?? this.rooms,
      favorite: favorite ?? this.favorite,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'portal': portal,
        'city': city,
        'district': district,
        'ownership': ownership,
        'description': description,
        'image': image,
        'url': url,
        'status': status,
        'price': price,
        'area': area,
        'rooms': rooms,
        'favorite': favorite,
        'phone': phone,
        'notes': notes,
        'addedAt': addedAt,
        'updatedAt': updatedAt,
      };

  factory Offer.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toIso8601String();
    final portal = '${json['portal'] ?? 'portal'}';
    return Offer(
      id: '${json['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      title: '${json['title'] ?? 'Oferta mieszkania'}',
      portal: portal,
      city: '${json['city'] ?? 'Gdańsk'}',
      district: '${json['district'] ?? ''}',
      ownership: '${json['ownership'] ?? 'Do sprawdzenia'}',
      description: '${json['description'] ?? ''}',
      image: '${json['image'] ?? portalImage(portal)}',
      url: normalizeOfferUrl('${json['url'] ?? ''}'),
      status: normalizeStatus('${json['status'] ?? 'NOWA'}'),
      price: int.tryParse('${json['price'] ?? 0}') ?? 0,
      area: double.tryParse('${json['area'] ?? 0}'.replaceAll(',', '.')) ?? 0,
      rooms: int.tryParse('${json['rooms'] ?? 0}') ?? 0,
      favorite: json['favorite'] == true,
      phone: '${json['phone'] ?? ''}',
      notes: '${json['notes'] ?? ''}',
      addedAt: _legacyDateToIso(json['addedAt'] ?? json['added'], now),
      updatedAt: '${json['updatedAt'] ?? now}',
    );
  }
}

String _legacyDateToIso(dynamic value, String fallback) {
  final text = '$value';
  return DateTime.tryParse(text)?.toIso8601String() ?? fallback;
}

String normalizeStatus(String status) {
  final upper = foldPolish(status).toUpperCase();
  const legacy = {
    'NOWE': 'NOWA',
    'CIEKAWE': 'CIEKAWA',
    'OBEJRZANE': 'OBEJRZANA',
    'ODRZUCONE': 'ODRZUCONA',
    'ZADZWONIC': 'KONTAKT',
  };
  final normalized = legacy[upper] ?? upper;
  return statusLabels.containsKey(normalized) ? normalized : 'NOWA';
}

class OfferAnalysis {
  final int score;
  final String classification;
  final List<String> signals;
  final List<String> warnings;

  const OfferAnalysis({
    required this.score,
    required this.classification,
    required this.signals,
    required this.warnings,
  });
}

OfferAnalysis analyzeOffer(String text) {
  final value = foldPolish(text).toLowerCase();
  final signals = <String>[];
  final warnings = <String>[];
  var score = 22;
  var classification = 'Forma własności do sprawdzenia';

  final cooperativeRight = value.contains('spoldzielcze wlasnosciowe prawo') ||
      value.contains('spoldzielczo-wlasnosciowe prawo') ||
      value.contains('spoldzielczo wlasnosciowe prawo');
  final cooperative = cooperativeRight ||
      value.contains('spoldzielcze wlasnosciowe') ||
      value.contains('spoldzielczo-wlasnosciowe') ||
      value.contains('spoldzielczo wlasnosciowe');
  final fullOwnership = value.contains('pelna wlasnosc') ||
      value.contains('odrebna wlasnosc') ||
      value.contains('lokal stanowi odrebna nieruchomosc');
  final disqualifying = value.contains('tbs') ||
      value.contains('prawo lokatorskie') ||
      value.contains('spoldzielcze lokatorskie') ||
      value.contains('sprzedaz udzialu') ||
      value.contains('cesja partycypacji');

  if (cooperativeRight) {
    score = 96;
    classification = 'Spółdzielcze własnościowe prawo do lokalu';
    signals.add('jednoznaczna forma własności');
  } else if (cooperative) {
    score = 86;
    classification = 'Prawdopodobnie spółdzielcze własnościowe';
    signals.add('spółdzielcze własnościowe');
  } else if (fullOwnership) {
    score = 42;
    classification = 'Pełna / odrębna własność';
    signals.add('pełna lub odrębna własność');
  }

  if (value.contains('bez kw') ||
      value.contains('bez ksiegi wieczystej') ||
      value.contains('brak ksiegi wieczystej')) {
    score += cooperative ? 3 : 18;
    signals.add('bez księgi wieczystej');
  }
  if (value.contains('zaswiadczenie ze spoldzielni') ||
      value.contains('zaswiadczenie spoldzielni')) {
    score += 6;
    signals.add('zaświadczenie ze spółdzielni');
  }
  if (value.contains('mozliwosc zalozenia kw') ||
      value.contains('mozna zalozyc ksiege')) {
    score += 3;
    signals.add('możliwość założenia KW');
  }
  if (value.contains('grunt uregulowany')) {
    score += 3;
    signals.add('uregulowany grunt');
  }
  if (value.contains('grunt nieuregulowany') ||
      value.contains('nieuregulowany stan prawny')) {
    score -= 22;
    warnings.add('nieuregulowany stan prawny lub grunt');
  }
  if (value.contains('brak mozliwosci zalozenia kw')) {
    warnings.add('brak możliwości założenia KW');
  }
  if (value.contains('zadluzen')) warnings.add('wzmianka o zadłużeniu');
  if (value.contains('komornik') || value.contains('licytac')) {
    warnings.add('licytacja lub postępowanie komornicze');
  }
  if (disqualifying) {
    score = 2;
    classification = 'To nie jest własność spółdzielcza własnościowa';
    warnings.add('TBS, udział, cesja albo prawo lokatorskie');
  }

  return OfferAnalysis(
    score: score.clamp(0, 100),
    classification: classification,
    signals: signals.toSet().toList(),
    warnings: warnings.toSet().toList(),
  );
}

class NativeBridge {
  static const _channel = MethodChannel('pl.lawicki.lowca_mieszkan/share');

  static void listenForSharedText(Future<void> Function(String text) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedText' && call.arguments is String) {
        await handler(call.arguments as String);
      }
    });
  }

  static Future<String?> initialSharedText() async {
    try {
      return await _channel.invokeMethod<String>('getInitialSharedText');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<void> shareText(String text, {String? subject}) async {
    try {
      await _channel.invokeMethod<void>('shareText', {
        'text': text,
        'subject': subject ?? 'Łowca Mieszkań',
      });
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: text));
    } on PlatformException {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  SearchCriteria criteria = SearchCriteria();
  List<Offer> offers = [];
  int page = 0;
  bool loading = true;
  String? _pendingSharedText;

  @override
  void initState() {
    super.initState();
    NativeBridge.listenForSharedText(_handleSharedText);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    var migrated = false;

    final criteriaRaw = prefs.getString(_criteriaStorageKey);
    if (criteriaRaw != null && criteriaRaw.isNotEmpty) {
      try {
        criteria = SearchCriteria.fromJson(
          Map<String, dynamic>.from(jsonDecode(criteriaRaw) as Map),
        );
      } on FormatException {
        criteria = SearchCriteria();
      } on TypeError {
        criteria = SearchCriteria();
      }
    }

    final currentRaw = prefs.getString(_offersStorageKey);
    final legacyRaw = prefs.getString(_legacyOffersStorageKey);
    final raw = currentRaw ?? legacyRaw;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        final list = decoded is Map ? decoded['offers'] : decoded;
        if (list is List) {
          offers = list
              .whereType<Map>()
              .map((item) => Offer.fromJson(Map<String, dynamic>.from(item)))
              .where((offer) => !offer.id.startsWith('demo'))
              .toList();
          migrated = currentRaw == null;
        }
      } on FormatException {
        offers = [];
      } on TypeError {
        offers = [];
      }
    }

    if (!mounted) return;
    setState(() => loading = false);
    if (migrated) await _saveOffers();

    final initial = await NativeBridge.initialSharedText();
    final shared = _pendingSharedText ?? initial;
    _pendingSharedText = null;
    if (shared != null && shared.trim().isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _beginAddFromText(shared);
      });
    }
  }

  Future<void> _handleSharedText(String text) async {
    if (loading) {
      _pendingSharedText = text;
      return;
    }
    await _beginAddFromText(text);
  }

  Future<void> _saveOffers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _offersStorageKey,
      jsonEncode(offers.map((offer) => offer.toJson()).toList()),
    );
  }

  Future<void> _saveCriteria() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_criteriaStorageKey, jsonEncode(criteria.toJson()));
  }

  Future<void> _beginAddFromText(String text) async {
    final url = extractOfferUrl(text);
    if (url == null) {
      if (mounted) showSnack(context, 'Nie znaleziono poprawnego linku http/https.');
      return;
    }

    final duplicate = offers.where((offer) => offer.url == url).firstOrNull;
    if (duplicate != null) {
      if (!mounted) return;
      setState(() => page = 1);
      showSnack(context, 'Ta oferta jest już zapisana: ${duplicate.title}');
      return;
    }
    await _openEditor(initialUrl: url);
  }

  Future<Offer?> _openEditor({Offer? offer, String initialUrl = ''}) async {
    final portal = detectPortal(initialUrl.isNotEmpty ? initialUrl : offer?.url ?? '');
    final now = DateTime.now().toIso8601String();
    final draft = offer ??
        Offer(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: portal == 'portal'
              ? 'Nowa oferta mieszkania'
              : 'Oferta z ${portalDisplayName(portal)}',
          portal: portal,
          city: criteria.location,
          district: '',
          ownership: criteria.ownership == 'Brak wyboru / wszystkie'
              ? 'Do sprawdzenia'
              : criteria.ownership,
          description: '',
          image: portalImage(portal),
          url: normalizeOfferUrl(initialUrl),
          status: 'NOWA',
          price: 0,
          area: 0,
          rooms: 0,
          favorite: false,
          phone: '',
          notes: '',
          addedAt: now,
          updatedAt: now,
        );

    if (!mounted) return null;
    final saved = await Navigator.of(context).push<Offer>(
      MaterialPageRoute(
        builder: (_) => OfferEditorPage(offer: draft, isNew: offer == null),
      ),
    );
    if (saved == null || !mounted) return null;

    final duplicate = offers.where(
      (item) => item.id != saved.id && item.url.isNotEmpty && item.url == saved.url,
    );
    if (duplicate.isNotEmpty) {
      showSnack(context, 'Nie zapisano — taki link już znajduje się na liście.');
      return null;
    }

    final index = offers.indexWhere((item) => item.id == saved.id);
    setState(() {
      if (index >= 0) {
        offers[index] = saved;
      } else {
        offers.insert(0, saved);
      }
      page = 1;
    });
    await _saveOffers();
    return saved;
  }

  void _quickUpdate(Offer updated) {
    final index = offers.indexWhere((item) => item.id == updated.id);
    if (index < 0) return;
    final value = updated.copyWith(updatedAt: DateTime.now().toIso8601String());
    setState(() => offers[index] = value);
    _saveOffers();
  }

  Future<void> _deleteOffer(Offer offer) async {
    setState(() => offers.removeWhere((item) => item.id == offer.id));
    await _saveOffers();
  }

  String _backupJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'Łowca Mieszkań',
      'version': 4,
      'exportedAt': DateTime.now().toIso8601String(),
      'criteria': criteria.toJson(),
      'offers': offers.map((offer) => offer.toJson()).toList(),
    });
  }

  Future<void> _shareBackup() async {
    final data = _backupJson();
    await Clipboard.setData(ClipboardData(text: data));
    await NativeBridge.shareText(data, subject: 'Kopia danych — Łowca Mieszkań');
    if (mounted) showSnack(context, 'Kopia została też skopiowana do schowka.');
  }

  Future<void> _shareCsv() async {
    final data = offersToCsv(offers);
    await Clipboard.setData(ClipboardData(text: data));
    await NativeBridge.shareText(data, subject: 'Oferty — Łowca Mieszkań CSV');
    if (mounted) showSnack(context, 'CSV został też skopiowany do schowka.');
  }

  Future<void> _importBackup() async {
    final input = await showLargeTextDialog(
      context,
      title: 'Wklej kopię danych',
      hint: '{ "version": 4, "offers": [...] }',
      actionLabel: 'Importuj',
    );
    if (input == null || input.trim().isEmpty || !mounted) return;

    try {
      final decoded = jsonDecode(input);
      final list = decoded is Map ? decoded['offers'] : decoded;
      if (list is! List) throw const FormatException('Brak listy ofert');
      final imported = list
          .whereType<Map>()
          .map((item) => Offer.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final byUrlOrId = <String, Offer>{};
      for (final item in [...offers, ...imported]) {
        final key = item.url.isNotEmpty ? item.url : item.id;
        byUrlOrId[key] = item;
      }
      if (decoded is Map && decoded['criteria'] is Map) {
        criteria = SearchCriteria.fromJson(
          Map<String, dynamic>.from(decoded['criteria'] as Map),
        );
        await _saveCriteria();
      }
      setState(() => offers = byUrlOrId.values.toList());
      await _saveOffers();
      if (mounted) showSnack(context, 'Zaimportowano ${imported.length} ofert.');
    } on FormatException {
      if (mounted) showSnack(context, 'Nieprawidłowa kopia danych.');
    } on TypeError {
      if (mounted) showSnack(context, 'Nieprawidłowy układ danych w kopii.');
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Usunąć wszystkie oferty?',
      message: 'Tej operacji nie można cofnąć bez zapisanej kopii danych.',
      confirmLabel: 'Usuń wszystko',
      destructive: true,
    );
    if (!confirmed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offersStorageKey);
    if (mounted) {
      setState(() => offers = []);
      showSnack(context, 'Lista ofert została wyczyszczona.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.green)),
      );
    }

    final pages = <Widget>[
      StartPage(
        criteria: criteria,
        offerCount: offers.length,
        favoriteCount: offers.where((offer) => offer.favorite).length,
        onPersistCriteria: _saveCriteria,
        onSearch: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PortalLinksPage(
              criteria: criteria,
              onImport: _beginAddFromText,
            ),
          ),
        ),
        onAdd: () => _openEditor(),
      ),
      OffersPage(
        offers: offers,
        onImport: _beginAddFromText,
        onNew: () => _openEditor(),
        onChanged: _quickUpdate,
        onEdit: (offer) => _openEditor(offer: offer),
        onDelete: _deleteOffer,
      ),
      OffersPage(
        title: 'Ulubione',
        offers: offers.where((offer) => offer.favorite).toList(),
        onImport: _beginAddFromText,
        onNew: () => _openEditor(),
        onChanged: _quickUpdate,
        onEdit: (offer) => _openEditor(offer: offer),
        onDelete: _deleteOffer,
      ),
      StatsPage(offers: offers),
      SettingsPage(
        offerCount: offers.length,
        onBackup: _shareBackup,
        onImport: _importBackup,
        onCsv: _shareCsv,
        onClear: _clearAll,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[page]),
      bottomNavigationBar: BottomNav(
        index: page,
        onChanged: (index) => setState(() => page = index),
      ),
    );
  }
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class StartPage extends StatefulWidget {
  final SearchCriteria criteria;
  final int offerCount;
  final int favoriteCount;
  final Future<void> Function() onPersistCriteria;
  final VoidCallback onSearch;
  final VoidCallback onAdd;

  const StartPage({
    super.key,
    required this.criteria,
    required this.offerCount,
    required this.favoriteCount,
    required this.onPersistCriteria,
    required this.onSearch,
    required this.onAdd,
  });

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  late final TextEditingController keywordsController;
  late final TextEditingController excludedController;

  @override
  void initState() {
    super.initState();
    keywordsController = TextEditingController(text: widget.criteria.keywords);
    excludedController =
        TextEditingController(text: widget.criteria.excludedKeywords);
  }

  @override
  void dispose() {
    keywordsController.dispose();
    excludedController.dispose();
    super.dispose();
  }

  void _changed(VoidCallback change) {
    setState(change);
    widget.onPersistCriteria();
  }

  @override
  Widget build(BuildContext context) {
    final links = buildPortalLinks(widget.criteria);
    return ScreenShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          HeaderHome(
            offerCount: widget.offerCount,
            favoriteCount: widget.favoriteCount,
          ),
          const SizedBox(height: 22),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ustaw kryteria',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Aplikacja przygotuje aktualne wyszukiwania na pięciu portalach.',
                  style: TextStyle(color: AppColors.muted, height: 1.3),
                ),
                const SizedBox(height: 18),
                SelectField<String>(
                  label: 'Lokalizacja',
                  value: widget.criteria.location,
                  items: cityMap.keys.toList(),
                  onChanged: (value) =>
                      _changed(() => widget.criteria.location = value),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectField<int>(
                        label: 'Cena od',
                        value: widget.criteria.priceFrom,
                        items: priceFromOptions,
                        labelBuilder: (value) =>
                            value == 0 ? 'bez minimum' : money(value),
                        onChanged: (value) =>
                            _changed(() => widget.criteria.priceFrom = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectField<int>(
                        label: 'Cena do',
                        value: widget.criteria.priceTo,
                        items: priceToOptions,
                        labelBuilder: money,
                        onChanged: (value) =>
                            _changed(() => widget.criteria.priceTo = value),
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectField<int>(
                        label: 'Metraż od',
                        value: widget.criteria.areaFrom,
                        items: areaFromOptions,
                        labelBuilder: meters,
                        onChanged: (value) =>
                            _changed(() => widget.criteria.areaFrom = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectField<int>(
                        label: 'Metraż do',
                        value: widget.criteria.areaTo,
                        items: areaToOptions,
                        labelBuilder: meters,
                        onChanged: (value) =>
                            _changed(() => widget.criteria.areaTo = value),
                      ),
                    ),
                  ],
                ),
                SelectField<String>(
                  label: 'Liczba pokoi',
                  value: widget.criteria.rooms,
                  items: roomOptions,
                  onChanged: (value) =>
                      _changed(() => widget.criteria.rooms = value),
                ),
                SelectField<String>(
                  label: 'Forma własności',
                  value: widget.criteria.ownership,
                  items: ownershipOptions,
                  onChanged: (value) =>
                      _changed(() => widget.criteria.ownership = value),
                ),
                TextField(
                  controller: keywordsController,
                  decoration: const InputDecoration(
                    labelText: 'Dodatkowe słowa (opcjonalnie)',
                    hintText: 'np. balkon, do remontu, bez pośredników',
                    prefixIcon: Icon(Icons.add_circle_outline),
                  ),
                  onChanged: (value) {
                    widget.criteria.keywords = value;
                    widget.onPersistCriteria();
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: excludedController,
                  decoration: const InputDecoration(
                    labelText: 'Słowa wykluczające',
                    hintText: 'np. TBS, udział, lokatorskie',
                    prefixIcon: Icon(Icons.remove_circle_outline),
                  ),
                  onChanged: (value) {
                    widget.criteria.excludedKeywords = value;
                    widget.onPersistCriteria();
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  value: widget.criteria.secondaryOnly,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.green,
                  title: const Text(
                    'Tylko rynek wtórny',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Ogranicza wyniki deweloperskie, gdy portal obsługuje ten filtr.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  onChanged: (value) =>
                      _changed(() => widget.criteria.secondaryOnly = value),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  icon: Icons.search_rounded,
                  text: 'Pokaż wyszukiwania',
                  onTap: widget.onSearch,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Szybki dostęp do portali'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 3 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.05,
                children: links.map((link) => PortalTile(link: link)).toList(),
              );
            },
          ),
          const SizedBox(height: 22),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bookmark_add_outlined, color: AppColors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Zapisuj prawdziwe ogłoszenia',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Na stronie ogłoszenia wybierz „Udostępnij” → „Łowca Mieszkań”. Możesz też wkleić link ręcznie i uzupełnić cenę, metraż, telefon oraz notatki.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                SecondaryButton(
                  icon: Icons.add_link_rounded,
                  text: 'Dodaj ofertę ręcznie',
                  onTap: widget.onAdd,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const VersionBadge(),
        ],
      ),
    );
  }
}

class HeaderHome extends StatelessWidget {
  final int offerCount;
  final int favoriteCount;

  const HeaderHome({
    super.key,
    required this.offerCount,
    required this.favoriteCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 40),
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.blue, AppColors.green],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blue.withOpacity(.3),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.maps_home_work_outlined,
                size: 44,
                color: Colors.white,
              ),
            ),
            SizedBox(
              width: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.red,
                    size: 30,
                  ),
                  if (favoriteCount > 0)
                    Positioned(
                      right: -5,
                      top: -7,
                      child: CountBadge(value: favoriteCount),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Łowca Mieszkań',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Własnościowe i spółdzielcze własnościowe',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Text(
          offerCount == 0
              ? 'Nie masz jeszcze zapisanych ofert'
              : 'Zapisane oferty: $offerCount',
          style: const TextStyle(
            color: AppColors.green,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class PortalLinksPage extends StatelessWidget {
  final SearchCriteria criteria;
  final Future<void> Function(String text) onImport;

  const PortalLinksPage({
    super.key,
    required this.criteria,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final links = buildPortalLinks(criteria);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          children: [
            PageHeader(
              title: 'Wyszukiwania',
              subtitle: criteria.short,
              onBack: () => Navigator.pop(context),
            ),
            const SizedBox(height: 14),
            CardBox(
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tune_rounded, color: AppColors.blue, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '„Portal” otwiera jego własne filtry. „Dokładne” używa wyszukiwarki z frazami własnościowymi — wybierz tę opcję, gdy portal pominie część kryteriów.',
                      style: TextStyle(color: AppColors.muted, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...links.map((link) => PortalOpenCard(link: link)),
            const SizedBox(height: 4),
            ImportBox(onImport: onImport),
            const SizedBox(height: 14),
            const CardBox(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.green,
                    size: 30,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aplikacja nie omija CAPTCHA i nie pobiera danych bez zgody portalu. Ogłoszenia otwierają się w zwykłej przeglądarce telefonu.',
                      style: TextStyle(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PortalOpenCard extends StatelessWidget {
  final PortalLink link;

  const PortalOpenCard({super.key, required this.link});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: link.color.withOpacity(.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    link.logo,
                    style: TextStyle(
                      color: link.color,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      link.note,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.25,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  icon: Icons.public_rounded,
                  text: 'Portal',
                  onTap: () => openUrl(link.directUrl),
                  compact: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  icon: Icons.filter_alt_rounded,
                  text: 'Dokładne',
                  onTap: () => openUrl(link.preciseUrl),
                  compact: true,
                ),
              ),
              IconButton(
                tooltip: 'Kopiuj dokładny link',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link.preciseUrl));
                  if (context.mounted) {
                    showSnack(context, 'Skopiowano link ${link.name}.');
                  }
                },
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OffersPage extends StatefulWidget {
  final List<Offer> offers;
  final String title;
  final Future<void> Function(String text) onImport;
  final VoidCallback onNew;
  final void Function(Offer offer) onChanged;
  final Future<Offer?> Function(Offer offer) onEdit;
  final Future<void> Function(Offer offer) onDelete;

  const OffersPage({
    super.key,
    required this.offers,
    required this.onImport,
    required this.onNew,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
    this.title = 'Oferty',
  });

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  final searchController = TextEditingController();
  String statusFilter = 'WSZYSTKIE';
  String sort = 'Najnowsze';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Offer> get visibleOffers {
    final query = foldPolish(searchController.text.trim()).toLowerCase();
    final list = widget.offers.where((offer) {
      if (statusFilter != 'WSZYSTKIE' && offer.status != statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = foldPolish(
        '${offer.title} ${offer.city} ${offer.district} ${offer.ownership} '
        '${offer.description} ${offer.notes} ${offer.portal}',
      ).toLowerCase();
      return haystack.contains(query);
    }).toList();

    int nonZeroCompare(num a, num b) {
      if (a <= 0 && b <= 0) return 0;
      if (a <= 0) return 1;
      if (b <= 0) return -1;
      return a.compareTo(b);
    }

    switch (sort) {
      case 'Najlepiej dopasowane':
        list.sort((a, b) => b.score.compareTo(a.score));
        break;
      case 'Najtańsze':
        list.sort((a, b) => nonZeroCompare(a.price, b.price));
        break;
      case 'Najtańsze za m²':
        list.sort(
          (a, b) => nonZeroCompare(a.pricePerMeter, b.pricePerMeter),
        );
        break;
      default:
        list.sort((a, b) => b.addedDate.compareTo(a.addedDate));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = visibleOffers;
    return ScreenShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Wklej link',
                onPressed: () => showImportLinkDialog(context, widget.onImport),
                icon: const Icon(Icons.add_link_rounded),
              ),
              IconButton.filled(
                tooltip: 'Nowa oferta',
                onPressed: widget.onNew,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Szukaj w zapisanych ofertach',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChipButton(
                  text: 'Wszystkie',
                  selected: statusFilter == 'WSZYSTKIE',
                  onTap: () => setState(() => statusFilter = 'WSZYSTKIE'),
                ),
                ...statusLabels.entries.map(
                  (entry) => FilterChipButton(
                    text: entry.value,
                    selected: statusFilter == entry.key,
                    onTap: () => setState(() => statusFilter = entry.key),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${list.length} z ${widget.offers.length}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: sort,
                underline: const SizedBox.shrink(),
                dropdownColor: AppColors.card,
                items: const [
                  'Najnowsze',
                  'Najlepiej dopasowane',
                  'Najtańsze',
                  'Najtańsze za m²',
                ]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => sort = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            EmptyState(
              icon: widget.offers.isEmpty
                  ? Icons.bookmark_add_outlined
                  : Icons.search_off_rounded,
              title: widget.offers.isEmpty
                  ? 'Brak zapisanych ofert'
                  : 'Brak wyników',
              text: widget.offers.isEmpty
                  ? 'Dodaj link z portalu przez „Udostępnij” albo wklej go ręcznie.'
                  : 'Zmień filtr statusu lub wpisaną frazę.',
              buttonLabel: widget.offers.isEmpty ? 'Dodaj ofertę' : null,
              onButton: widget.offers.isEmpty ? widget.onNew : null,
            ),
          ...list.map(
            (offer) => OfferCard(
              offer: offer,
              onChanged: widget.onChanged,
              onEdit: widget.onEdit,
              onDelete: widget.onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class OfferCard extends StatelessWidget {
  final Offer offer;
  final void Function(Offer offer) onChanged;
  final Future<Offer?> Function(Offer offer) onEdit;
  final Future<void> Function(Offer offer) onDelete;

  const OfferCard({
    super.key,
    required this.offer,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final analysis = analyzeOffer(
      '${offer.title} ${offer.ownership} ${offer.description} ${offer.notes}',
    );
    final badgeColor = analysisColor(analysis.score);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OfferDetailsPage(
            offer: offer,
            onChanged: onChanged,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Image.asset(
                    offer.image,
                    width: 108,
                    height: 132,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 108,
                      height: 132,
                      color: AppColors.field,
                      child: const Icon(Icons.apartment_rounded, size: 42),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: ScoreBadge(score: analysis.score, color: badgeColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          formatMoney(offer.price),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: offer.favorite ? 'Usuń z ulubionych' : 'Ulubiona',
                        onPressed: () => onChanged(
                          offer.copyWith(favorite: !offer.favorite),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: Icon(
                          offer.favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: offer.favorite ? AppColors.red : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  if (offer.area > 0 || offer.rooms > 0)
                    Text(
                      offerFacts(offer),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  const SizedBox(height: 3),
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    locationLabel(offer),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      TinyTag(
                        text: statusLabels[offer.status] ?? offer.status,
                        color: statusColor(offer.status),
                      ),
                      TinyTag(
                        text: portalDisplayName(offer.portal),
                        color: portalColor(offer.portal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    addedLabel(offer.addedDate),
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfferDetailsPage extends StatefulWidget {
  final Offer offer;
  final void Function(Offer offer) onChanged;
  final Future<Offer?> Function(Offer offer) onEdit;
  final Future<void> Function(Offer offer) onDelete;

  const OfferDetailsPage({
    super.key,
    required this.offer,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<OfferDetailsPage> createState() => _OfferDetailsPageState();
}

class _OfferDetailsPageState extends State<OfferDetailsPage> {
  late Offer offer;

  @override
  void initState() {
    super.initState();
    offer = widget.offer;
  }

  void _update(Offer value) {
    setState(() => offer = value);
    widget.onChanged(value);
  }

  Future<void> _edit() async {
    final updated = await widget.onEdit(offer);
    if (updated != null && mounted) setState(() => offer = updated);
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Usunąć ofertę?',
      message: 'Usuniesz link, dane i wszystkie notatki tej oferty.',
      confirmLabel: 'Usuń',
      destructive: true,
    );
    if (!confirmed) return;
    await widget.onDelete(offer);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final analysis = analyzeOffer(
      '${offer.title} ${offer.ownership} ${offer.description} ${offer.notes}',
    );
    final color = analysisColor(analysis.score);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Expanded(
                  child: Text(
                    'Szczegóły oferty',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Edytuj',
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') _delete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppColors.red),
                          SizedBox(width: 10),
                          Text('Usuń ofertę'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Image.asset(
                    offer.image,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 220,
                      color: AppColors.card,
                      child: const Center(
                        child: Icon(Icons.apartment_rounded, size: 70),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: ScoreBadge(score: analysis.score, color: color),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: IconButton.filledTonal(
                      onPressed: () => _update(
                        offer.copyWith(favorite: !offer.favorite),
                      ),
                      icon: Icon(
                        offer.favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: offer.favorite ? AppColors.red : AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatMoney(offer.price),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (offer.pricePerMeter > 0)
                        Text(
                          '${money(offer.pricePerMeter.round())}/m²',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                    ],
                  ),
                ),
                TinyTag(
                  text: portalDisplayName(offer.portal),
                  color: portalColor(offer.portal),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              offer.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            if (offer.area > 0 || offer.rooms > 0) ...[
              const SizedBox(height: 8),
              Text(
                offerFacts(offer),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 7),
            Text(
              locationLabel(offer),
              style: const TextStyle(color: AppColors.muted, fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              offer.ownership.isEmpty ? 'Forma własności do sprawdzenia' : offer.ownership,
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Etap oferty',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: statusLabels.entries
                    .map(
                      (entry) => FilterChipButton(
                        text: entry.value,
                        selected: offer.status == entry.key,
                        onTap: () => _update(offer.copyWith(status: entry.key)),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 18),
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          analysis.classification,
                          style: TextStyle(
                            color: color,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${analysis.score}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ocena jest podpowiedzią na podstawie opisu — potwierdź stan prawny w dokumentach.',
                    style: TextStyle(color: AppColors.muted, height: 1.35),
                  ),
                  if (analysis.signals.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: analysis.signals
                          .map((text) => TinyTag(text: text, color: AppColors.green))
                          .toList(),
                    ),
                  ],
                  if (analysis.warnings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...analysis.warnings.map(
                      (warning) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(warning)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (offer.description.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              DetailSection(title: 'Opis', text: offer.description),
            ],
            if (offer.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              DetailSection(title: 'Moje notatki', text: offer.notes),
            ],
            if (offer.phone.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              DetailSection(title: 'Telefon', text: offer.phone),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    icon: Icons.ios_share_rounded,
                    text: 'Udostępnij',
                    onTap: () => NativeBridge.shareText(
                      '${offer.title}\n${offer.url}',
                      subject: offer.title,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SecondaryButton(
                    icon: Icons.phone_rounded,
                    text: 'Zadzwoń',
                    onTap: () {
                      final phone = offer.phone.replaceAll(RegExp(r'[^0-9+]'), '');
                      if (phone.isEmpty) {
                        showSnack(context, 'Najpierw uzupełnij numer telefonu.');
                      } else {
                        openUrl('tel:$phone');
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              icon: Icons.open_in_new_rounded,
              text: offer.url.isEmpty ? 'Brak linku — edytuj ofertę' : 'Otwórz ogłoszenie',
              onTap: offer.url.isEmpty
                  ? _edit
                  : () {
                      _update(offer.copyWith(status: offer.status == 'NOWA' ? 'CIEKAWA' : offer.status));
                      openUrl(offer.url);
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class DetailSection extends StatelessWidget {
  final String title;
  final String text;

  const DetailSection({super.key, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          SelectableText(text, style: const TextStyle(height: 1.4)),
        ],
      ),
    );
  }
}

class OfferEditorPage extends StatefulWidget {
  final Offer offer;
  final bool isNew;

  const OfferEditorPage({
    super.key,
    required this.offer,
    required this.isNew,
  });

  @override
  State<OfferEditorPage> createState() => _OfferEditorPageState();
}

class _OfferEditorPageState extends State<OfferEditorPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController urlController;
  late final TextEditingController districtController;
  late final TextEditingController priceController;
  late final TextEditingController areaController;
  late final TextEditingController roomsController;
  late final TextEditingController phoneController;
  late final TextEditingController descriptionController;
  late final TextEditingController notesController;
  late String city;
  late String ownership;
  late String status;

  @override
  void initState() {
    super.initState();
    final offer = widget.offer;
    titleController = TextEditingController(text: offer.title);
    urlController = TextEditingController(text: offer.url);
    districtController = TextEditingController(text: offer.district);
    priceController =
        TextEditingController(text: offer.price > 0 ? '${offer.price}' : '');
    areaController = TextEditingController(
      text: offer.area > 0 ? trimDouble(offer.area) : '',
    );
    roomsController =
        TextEditingController(text: offer.rooms > 0 ? '${offer.rooms}' : '');
    phoneController = TextEditingController(text: offer.phone);
    descriptionController = TextEditingController(text: offer.description);
    notesController = TextEditingController(text: offer.notes);
    city = cityMap.containsKey(offer.city) ? offer.city : 'Gdańsk';
    ownership = editableOwnershipOptions.contains(offer.ownership)
        ? offer.ownership
        : 'Do sprawdzenia';
    status = normalizeStatus(offer.status);
  }

  @override
  void dispose() {
    titleController.dispose();
    urlController.dispose();
    districtController.dispose();
    priceController.dispose();
    areaController.dispose();
    roomsController.dispose();
    phoneController.dispose();
    descriptionController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final now = DateTime.now().toIso8601String();
    final url = normalizeOfferUrl(urlController.text);
    final portal = detectPortal(url);
    final updated = widget.offer.copyWith(
      title: titleController.text.trim(),
      portal: portal,
      city: city,
      district: districtController.text.trim(),
      ownership: ownership,
      description: descriptionController.text.trim(),
      image: portalImage(portal),
      url: url,
      status: status,
      price: int.tryParse(priceController.text.replaceAll(RegExp(r'\s'), '')) ?? 0,
      area: double.tryParse(areaController.text.replaceAll(',', '.')) ?? 0,
      rooms: int.tryParse(roomsController.text) ?? 0,
      phone: phoneController.text.trim(),
      notes: notesController.text.trim(),
      updatedAt: now,
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final analysis = analyzeOffer(
      '${titleController.text} $ownership ${descriptionController.text} ${notesController.text}',
    );
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(widget.isNew ? 'Dodaj ofertę' : 'Edytuj ofertę'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'ZAPISZ',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            TextFormField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Link do ogłoszenia',
                hintText: 'https://...',
                prefixIcon: const Icon(Icons.link_rounded),
                suffixIcon: urlController.text.isEmpty
                    ? IconButton(
                        tooltip: 'Wklej',
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            urlController.text = extractOfferUrl(data!.text!) ?? data.text!;
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.content_paste_rounded),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final normalized = normalizeOfferUrl(value);
                final uri = Uri.tryParse(normalized);
                if (uri == null ||
                    !uri.hasScheme ||
                    !const ['http', 'https'].contains(uri.scheme) ||
                    uri.host.isEmpty) {
                  return 'Wklej poprawny link http/https';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Tytuł *',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Wpisz tytuł oferty'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: city,
              decoration: const InputDecoration(
                labelText: 'Miasto',
                prefixIcon: Icon(Icons.location_city_rounded),
              ),
              items: cityMap.keys
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => city = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: districtController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Dzielnica / ulica',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Cena (zł)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: areaController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                    ],
                    decoration: const InputDecoration(labelText: 'm²'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: roomsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Pokoje'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: ownership,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Forma własności',
                prefixIcon: Icon(Icons.gavel_rounded),
              ),
              items: editableOwnershipOptions
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => ownership = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: status,
              decoration: const InputDecoration(
                labelText: 'Etap oferty',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: statusLabels.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => status = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon do ogłoszeniodawcy',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descriptionController,
              minLines: 5,
              maxLines: 12,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Opis ogłoszenia',
                alignLabelWithHint: true,
                hintText: 'Wklej opis — aplikacja oceni formę własności.',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: notesController,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Moje notatki',
                alignLabelWithHint: true,
                hintText: 'Np. zadzwonić jutro, zapytać o KW i czynsz.',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: analysisColor(analysis.score).withOpacity(.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: analysisColor(analysis.score)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.fact_check_outlined,
                    color: analysisColor(analysis.score),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          analysis.classification,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Dopasowanie: ${analysis.score}%',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              icon: Icons.save_rounded,
              text: 'Zapisz ofertę',
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}

const editableOwnershipOptions = <String>[
  'Do sprawdzenia',
  'Spółdzielcze własnościowe prawo do lokalu',
  'Spółdzielcze własnościowe — bez KW',
  'Spółdzielcze własnościowe — z KW',
  'Pełna / odrębna własność',
  'Inna forma',
];

class StatsPage extends StatelessWidget {
  final List<Offer> offers;

  const StatsPage({super.key, required this.offers});

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) {
      return ScreenShell(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: const [
            Text(
              'Statystyki',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 18),
            EmptyState(
              icon: Icons.bar_chart_rounded,
              title: 'Brak danych',
              text: 'Statystyki pojawią się po zapisaniu pierwszych ofert.',
            ),
          ],
        ),
      );
    }

    final knownPrices = offers.where((offer) => offer.price > 0).toList();
    final averagePrice = knownPrices.isEmpty
        ? 0
        : knownPrices.fold<int>(0, (sum, offer) => sum + offer.price) ~/
            knownPrices.length;
    final knownPpm = offers
        .map((offer) => offer.pricePerMeter)
        .where((value) => value > 0)
        .toList()
      ..sort();
    final medianPpm = median(knownPpm);
    final promising = offers.where((offer) => offer.score >= 75).length;

    return ScreenShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          const Text(
            'Statystyki',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              StatCard(
                label: 'Wszystkie oferty',
                value: '${offers.length}',
                color: AppColors.blue,
              ),
              StatCard(
                label: 'Ulubione',
                value: '${offers.where((offer) => offer.favorite).length}',
                color: AppColors.red,
              ),
              StatCard(
                label: 'Mocne dopasowanie',
                value: '$promising',
                color: AppColors.green,
              ),
              StatCard(
                label: 'Średnia cena',
                value: averagePrice == 0 ? '—' : shortMoney(averagePrice),
                color: AppColors.orange,
              ),
              StatCard(
                label: 'Mediana zł/m²',
                value: medianPpm == 0 ? '—' : shortMoney(medianPpm.round()),
                color: AppColors.purple,
              ),
              StatCard(
                label: 'Do kontaktu / umówione',
                value:
                    '${offers.where((offer) => offer.status == 'KONTAKT' || offer.status == 'UMOWIONA').length}',
                color: AppColors.green,
              ),
            ],
          ),
          const SizedBox(height: 18),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rozkład cen',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                PriceBars(offers: offers),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Etapy ofert',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                ...statusLabels.entries.map((entry) {
                  final count =
                      offers.where((offer) => offer.status == entry.key).length;
                  return StatusProgress(
                    label: entry.value,
                    value: count,
                    total: offers.length,
                    color: statusColor(entry.key),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Najczęstsze słowa',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                TopWords(offers: offers),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final int offerCount;
  final VoidCallback onBackup;
  final VoidCallback onImport;
  final VoidCallback onCsv;
  final VoidCallback onClear;

  const SettingsPage({
    super.key,
    required this.offerCount,
    required this.onBackup,
    required this.onImport,
    required this.onCsv,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ScreenShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          const Text(
            'Ustawienia',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Twoje dane',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  '$offerCount zapisanych ofert. Dane pozostają lokalnie w telefonie.',
                  style: const TextStyle(color: AppColors.muted, height: 1.35),
                ),
                const SizedBox(height: 16),
                SettingsAction(
                  icon: Icons.backup_outlined,
                  title: 'Udostępnij kopię danych',
                  subtitle: 'Pełna kopia ofert, notatek i kryteriów w JSON',
                  onTap: onBackup,
                ),
                SettingsAction(
                  icon: Icons.restore_rounded,
                  title: 'Wczytaj kopię danych',
                  subtitle: 'Łączy zapisane i importowane oferty bez duplikatów',
                  onTap: onImport,
                ),
                SettingsAction(
                  icon: Icons.table_view_outlined,
                  title: 'Eksportuj CSV',
                  subtitle: 'Do Excela lub Arkuszy Google',
                  onTap: onCsv,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security_rounded, color: AppColors.green),
                    SizedBox(width: 10),
                    Text(
                      'Prywatność',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'Aplikacja nie wymaga konta, nie wysyła listy ofert na serwer i nie zbiera danych osobowych. Portale otwierają się w zewnętrznej przeglądarce.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Usuwanie danych',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Przed wyczyszczeniem listy warto utworzyć kopię.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                SecondaryButton(
                  icon: Icons.delete_forever_outlined,
                  text: 'Usuń wszystkie oferty',
                  onTap: onClear,
                  color: AppColors.red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const VersionBadge(),
        ],
      ),
    );
  }
}

class SettingsAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SettingsAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: AppColors.blue.withOpacity(.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppColors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class PriceBars extends StatelessWidget {
  final List<Offer> offers;

  const PriceBars({super.key, required this.offers});

  @override
  Widget build(BuildContext context) {
    final counts = [0, 0, 0, 0, 0];
    for (final offer in offers) {
      if (offer.price <= 0) continue;
      if (offer.price < 500000) {
        counts[0]++;
      } else if (offer.price < 600000) {
        counts[1]++;
      } else if (offer.price < 700000) {
        counts[2]++;
      } else if (offer.price < 900000) {
        counts[3]++;
      } else {
        counts[4]++;
      }
    }
    final maxValue = counts.fold<int>(1, (max, value) => value > max ? value : max);
    const labels = ['<500', '500–600', '600–700', '700–900', '900+'];
    return SizedBox(
      height: 168,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(counts.length, (index) {
          final height = 18 + 95 * counts[index] / maxValue;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${counts[index]}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Container(
                  width: 35,
                  height: height,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [AppColors.blue, AppColors.green],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  labels[index],
                  style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class StatusProgress extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const StatusProgress({
    super.key,
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: total == 0 ? 0 : value / total,
            minHeight: 7,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: AppColors.field,
            color: color,
          ),
        ],
      ),
    );
  }
}

class TopWords extends StatelessWidget {
  final List<Offer> offers;

  const TopWords({super.key, required this.offers});

  @override
  Widget build(BuildContext context) {
    final words = mostCommonWords(offers, limit: 12);
    if (words.isEmpty) {
      return const Text(
        'Dodaj opisy ofert, aby zobaczyć najczęstsze słowa.',
        style: TextStyle(color: AppColors.muted),
      );
    }
    const colors = [
      AppColors.blue,
      AppColors.green,
      AppColors.orange,
      AppColors.purple,
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(words.length, (index) {
        final entry = words[index];
        final size = (19 - index * .45).clamp(13, 19).toDouble();
        return Text(
          '${entry.key} · ${entry.value}',
          style: TextStyle(
            color: colors[index % colors.length],
            fontSize: size,
            fontWeight: FontWeight.w900,
          ),
        );
      }),
    );
  }
}

class ScreenShell extends StatelessWidget {
  final Widget child;

  const ScreenShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bg2, AppColors.bg],
        ),
      ),
      child: child,
    );
  }
}

class CardBox extends StatelessWidget {
  final Widget child;

  const CardBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.16),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SelectField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T)? labelBuilder;
  final void Function(T value) onChanged;

  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                dropdownColor: AppColors.card,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.muted,
                ),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
                items: items
                    .map(
                      (item) => DropdownMenuItem<T>(
                        value: item,
                        child: Text(
                          labelBuilder?.call(item) ?? '$item',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (newValue) {
                  if (newValue != null) onChanged(newValue);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool compact;

  const PrimaryButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: compact ? 48 : 56,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: compact ? 19 : 22),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: compact ? 14 : 16,
            ),
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool compact;
  final Color color;

  const SecondaryButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.compact = false,
    this.color = AppColors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: compact ? 48 : 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: compact ? 19 : 22),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: compact ? 14 : 15,
            ),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class FilterChipButton extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const FilterChipButton({
    super.key,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.green : AppColors.card,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? AppColors.green : AppColors.border,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class TinyTag extends StatelessWidget {
  final String text;
  final Color color;

  const TinyTag({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(.45)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
      ),
    );
  }
}

class ScoreBadge extends StatelessWidget {
  final int score;
  final Color color;

  const ScoreBadge({super.key, required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 8),
        ],
      ),
      child: Text(
        '$score%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class PortalTile extends StatelessWidget {
  final PortalLink link;

  const PortalTile({super.key, required this.link});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => openUrl(link.directUrl),
      child: Container(
        decoration: BoxDecoration(
          color: link.color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: link.color.withOpacity(.2),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(9),
        child: FittedBox(
          child: Text(
            link.logo,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
    );
  }
}

class VersionBadge extends StatelessWidget {
  const VersionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.blue.withOpacity(.13),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.blue.withOpacity(.65)),
        ),
        child: const Text(
          appVersionLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.blue,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  final int value;

  const CountBadge({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.bg, width: 2),
      ),
      child: Text(
        '$value',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String? buttonLabel;
  final VoidCallback? onButton;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.buttonLabel,
    this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(
        children: [
          Icon(icon, size: 54, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.35),
          ),
          if (buttonLabel != null && onButton != null) ...[
            const SizedBox(height: 16),
            PrimaryButton(
              icon: Icons.add_rounded,
              text: buttonLabel!,
              onTap: onButton!,
            ),
          ],
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 29),
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ImportBox extends StatelessWidget {
  final Future<void> Function(String text) onImport;

  const ImportBox({super.key, required this.onImport});

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dodaj znalezioną ofertę',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          const Text(
            'Skopiuj link ogłoszenia z przeglądarki i wklej go tutaj.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 13),
          SecondaryButton(
            icon: Icons.content_paste_rounded,
            text: 'Wklej link oferty',
            onTap: () => showImportLinkDialog(context, onImport),
          ),
        ],
      ),
    );
  }
}

class BottomNav extends StatelessWidget {
  final int index;
  final void Function(int index) onChanged;

  const BottomNav({
    super.key,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const items = <(IconData, String)>[
      (Icons.home_outlined, 'Start'),
      (Icons.article_outlined, 'Oferty'),
      (Icons.favorite_border_rounded, 'Ulubione'),
      (Icons.bar_chart_rounded, 'Statystyki'),
      (Icons.settings_outlined, 'Ustawienia'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card2,
        border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (itemIndex) {
            final selected = itemIndex == index;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(itemIndex),
              child: SizedBox(
                width: 69,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[itemIndex].$1,
                      color: selected ? AppColors.blue : AppColors.muted,
                      size: 26,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[itemIndex].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? AppColors.blue : AppColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

List<PortalLink> buildPortalLinks(SearchCriteria criteria) {
  final city = cityMap[criteria.location] ?? cityMap['Gdańsk']!;
  final phrase = portalSearchPhrase(criteria);
  final phraseSlug = slug(phrase);
  final rooms = roomRange(criteria.rooms);

  final olxParams = <String, String>{
    if (criteria.priceFrom > 0)
      'search[filter_float_price:from]': '${criteria.priceFrom}',
    'search[filter_float_price:to]': '${criteria.priceTo}',
    'search[filter_float_m:from]': '${criteria.areaFrom}',
    'search[filter_float_m:to]': '${criteria.areaTo}',
    if (criteria.secondaryOnly) 'search[filter_enum_market][0]': 'secondary',
  };
  final olxBase =
      'https://www.olx.pl/nieruchomosci/mieszkania/sprzedaz/${city.olx}/q-$phraseSlug/';
  final olx = appendQuery(olxBase, olxParams) + olxRooms(criteria.rooms);

  final otodomBase =
      'https://www.otodom.pl/pl/oferty/sprzedaz/${otodomPathForRooms(criteria.rooms)}/${city.otodom}';
  final otodom = appendQuery(otodomBase, {
    if (criteria.priceFrom > 0) 'priceMin': '${criteria.priceFrom}',
    'priceMax': '${criteria.priceTo}',
    'areaMin': '${criteria.areaFrom}',
    'areaMax': '${criteria.areaTo}',
    'description': phrase,
    if (criteria.secondaryOnly) 'market': 'SECONDARY',
  });

  final morizon = appendQuery(
    'https://www.morizon.pl/mieszkania/${city.morizon}/',
    {
      if (criteria.priceFrom > 0) 'ps[price_from]': '${criteria.priceFrom}',
      'ps[price_to]': '${criteria.priceTo}',
      'ps[living_area_from]': '${criteria.areaFrom}',
      'ps[living_area_to]': '${criteria.areaTo}',
      if (rooms.$1 != null) 'ps[number_of_rooms_from]': '${rooms.$1}',
      if (rooms.$2 != null) 'ps[number_of_rooms_to]': '${rooms.$2}',
      'q': phrase,
    },
  );

  final gratka = appendQuery(
    'https://gratka.pl/nieruchomosci/mieszkania/${city.gratka}',
    {
      if (criteria.priceFrom > 0)
        'cena-calkowita:min': '${criteria.priceFrom}',
      'cena-calkowita:max': '${criteria.priceTo}',
      'powierzchnia-w-m2:min': '${criteria.areaFrom}',
      'powierzchnia-w-m2:max': '${criteria.areaTo}',
      if (rooms.$1 != null) 'liczba-pokoi:min': '${rooms.$1}',
      if (rooms.$2 != null) 'liczba-pokoi:max': '${rooms.$2}',
      'q': phrase,
    },
  );

  final adresowo = appendQuery(
    'https://adresowo.pl/mieszkania/${city.adresowo}/',
    {'q': phrase},
  );

  String note(String portal) {
    if (portal == 'Adresowo') {
      return 'Oferty bezpośrednie i agencyjne; dokładne kryteria są w drugim przycisku.';
    }
    return 'Cena, metraż i pokoje ustawione; drugi przycisk wzmacnia frazy własnościowe.';
  }

  return [
    PortalLink(
      name: 'OLX',
      logo: 'olx',
      domain: 'olx.pl',
      color: const Color(0xFF00A885),
      directUrl: olx,
      preciseUrl: googleSiteQuery(criteria, 'olx.pl'),
      note: note('OLX'),
    ),
    PortalLink(
      name: 'Otodom',
      logo: 'otodom',
      domain: 'otodom.pl',
      color: const Color(0xFFE87100),
      directUrl: otodom,
      preciseUrl: googleSiteQuery(criteria, 'otodom.pl'),
      note: note('Otodom'),
    ),
    PortalLink(
      name: 'Morizon',
      logo: 'morizon',
      domain: 'morizon.pl',
      color: const Color(0xFF2E8BE6),
      directUrl: morizon,
      preciseUrl: googleSiteQuery(criteria, 'morizon.pl'),
      note: note('Morizon'),
    ),
    PortalLink(
      name: 'Gratka',
      logo: 'gratka',
      domain: 'gratka.pl',
      color: const Color(0xFFC91859),
      directUrl: gratka,
      preciseUrl: googleSiteQuery(criteria, 'gratka.pl'),
      note: note('Gratka'),
    ),
    PortalLink(
      name: 'Adresowo',
      logo: 'adresowo.pl',
      domain: 'adresowo.pl',
      color: const Color(0xFF64748B),
      directUrl: adresowo,
      preciseUrl: googleSiteQuery(criteria, 'adresowo.pl'),
      note: note('Adresowo'),
    ),
  ];
}

String appendQuery(String base, Map<String, String> parameters) {
  final uri = Uri.parse(base);
  final merged = <String, String>{
    ...uri.queryParameters,
    ...parameters,
  };
  return uri.replace(queryParameters: merged).toString();
}

String portalSearchPhrase(SearchCriteria criteria) {
  String base;
  switch (criteria.ownership) {
    case 'Spółdzielcze własnościowe':
      base = 'spółdzielcze własnościowe';
      break;
    case 'Własnościowe — dowolna forma':
      base = 'mieszkanie własnościowe';
      break;
    case 'Pełna / odrębna własność':
      base = 'pełna własność';
      break;
    case 'Bez księgi wieczystej':
      base = 'mieszkanie bez księgi wieczystej';
      break;
    default:
      base = 'mieszkanie na sprzedaż';
  }
  final extra = criteria.keywords.trim();
  return extra.isEmpty ? base : '$base $extra';
}

String googleSiteQuery(SearchCriteria criteria, String domain) {
  String ownership;
  switch (criteria.ownership) {
    case 'Spółdzielcze własnościowe':
      ownership =
          '("spółdzielcze własnościowe" OR "spółdzielczo-własnościowe" OR "prawo do lokalu")';
      break;
    case 'Własnościowe — dowolna forma':
      ownership =
          '("spółdzielcze własnościowe" OR "pełna własność" OR "odrębna własność")';
      break;
    case 'Pełna / odrębna własność':
      ownership = '("pełna własność" OR "odrębna własność")';
      break;
    case 'Bez księgi wieczystej':
      ownership = '("bez KW" OR "bez księgi wieczystej")';
      break;
    default:
      ownership = 'mieszkanie sprzedaż';
  }

  final extra = splitKeywords(criteria.keywords).join(' ');
  final excluded = splitKeywords(criteria.excludedKeywords)
      .map((word) => '-"$word"')
      .join(' ');
  final roomText = criteria.rooms == 'Dowolnie'
      ? ''
      : criteria.rooms == '4+'
          ? '4 pokoje'
          : '${criteria.rooms} pokoje';
  final secondary = criteria.secondaryOnly ? '-deweloper -"rynek pierwotny"' : '';
  final query = [
    ownership,
    '"${criteria.location}"',
    roomText,
    '${criteria.areaFrom}-${criteria.areaTo} m2',
    criteria.priceFrom > 0
        ? '${criteria.priceFrom}-${criteria.priceTo} zł'
        : 'do ${criteria.priceTo} zł',
    extra,
    excluded,
    secondary,
    'site:$domain',
  ].where((part) => part.trim().isNotEmpty).join(' ');
  return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(query)}';
}

String otodomPathForRooms(String rooms) {
  switch (rooms) {
    case '1':
      return 'mieszkanie,1-pokoj';
    case '2':
      return 'mieszkanie,2-pokoje';
    case '3':
      return 'mieszkanie,3-pokoje';
    case '2 - 3':
      return 'mieszkanie,2-pokoje,3-pokoje';
    case '4+':
      return 'mieszkanie,4-pokoje';
    default:
      return 'mieszkanie';
  }
}

(int?, int?) roomRange(String rooms) {
  switch (rooms) {
    case '1':
      return (1, 1);
    case '2':
      return (2, 2);
    case '3':
      return (3, 3);
    case '2 - 3':
      return (2, 3);
    case '4+':
      return (4, null);
    default:
      return (null, null);
  }
}

String olxRooms(String roomsValue) {
  final rooms = <String>[];
  if (roomsValue == '1') rooms.add('one');
  if (roomsValue == '2') rooms.add('two');
  if (roomsValue == '3') rooms.add('three');
  if (roomsValue == '2 - 3') rooms.addAll(['two', 'three']);
  if (roomsValue == '4+') rooms.add('four');
  if (rooms.isEmpty) return '';
  return List.generate(
    rooms.length,
    (index) =>
        '&search%5Bfilter_enum_rooms%5D%5B$index%5D=${rooms[index]}',
  ).join();
}

String slug(String value) {
  var result = foldPolish(value).toLowerCase();
  result = result
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return result.isEmpty ? 'mieszkanie' : result;
}

String foldPolish(String value) {
  var result = value;
  const replacements = {
    'ą': 'a',
    'ć': 'c',
    'ę': 'e',
    'ł': 'l',
    'ń': 'n',
    'ó': 'o',
    'ś': 's',
    'ż': 'z',
    'ź': 'z',
    'Ą': 'A',
    'Ć': 'C',
    'Ę': 'E',
    'Ł': 'L',
    'Ń': 'N',
    'Ó': 'O',
    'Ś': 'S',
    'Ż': 'Z',
    'Ź': 'Z',
  };
  replacements.forEach((from, to) => result = result.replaceAll(from, to));
  return result;
}

List<String> splitKeywords(String value) {
  return value
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String? extractOfferUrl(String text) {
  final match = RegExp(r'https?://\S+', caseSensitive: false).firstMatch(text);
  if (match == null) return null;
  final normalized = normalizeOfferUrl(match.group(0) ?? '');
  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.host.isEmpty) return null;
  return normalized;
}

String normalizeOfferUrl(String input) {
  var value = input.trim();
  final embedded = RegExp(r'https?://\S+', caseSensitive: false).firstMatch(value);
  if (embedded != null) value = embedded.group(0) ?? value;
  while (value.isNotEmpty && '.,;:)]}>'.contains(value[value.length - 1])) {
    value = value.substring(0, value.length - 1);
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !const ['http', 'https'].contains(uri.scheme.toLowerCase()) ||
      uri.host.isEmpty) {
    return value;
  }
  final cleanQuery = <String, String>{};
  for (final entry in uri.queryParameters.entries) {
    final key = entry.key.toLowerCase();
    if (key.startsWith('utm_') ||
        key == 'fbclid' ||
        key == 'gclid' ||
        key == 'srsltid') {
      continue;
    }
    cleanQuery[entry.key] = entry.value;
  }
  return uri
      .replace(
        fragment: '',
        queryParameters: cleanQuery,
      )
      .toString();
}

String detectPortal(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? url.toLowerCase();
  if (host.contains('olx.')) return 'olx';
  if (host.contains('otodom.')) return 'otodom';
  if (host.contains('morizon.')) return 'morizon';
  if (host.contains('gratka.')) return 'gratka';
  if (host.contains('adresowo.')) return 'adresowo';
  return 'portal';
}

String portalDisplayName(String portal) {
  switch (portal.toLowerCase()) {
    case 'olx':
      return 'OLX';
    case 'otodom':
      return 'Otodom';
    case 'morizon':
      return 'Morizon';
    case 'gratka':
      return 'Gratka';
    case 'adresowo':
    case 'adresowo.pl':
      return 'Adresowo';
    default:
      return 'Inny portal';
  }
}

Color portalColor(String portal) {
  switch (portal.toLowerCase()) {
    case 'olx':
      return const Color(0xFF00A885);
    case 'otodom':
      return const Color(0xFFFF7A00);
    case 'morizon':
      return const Color(0xFF3399FF);
    case 'gratka':
      return const Color(0xFFE91E63);
    case 'adresowo':
    case 'adresowo.pl':
      return const Color(0xFF94A3B8);
    default:
      return AppColors.blue;
  }
}

String portalImage(String portal) {
  switch (portal.toLowerCase()) {
    case 'olx':
    case 'adresowo':
      return 'assets/images/apartment2.png';
    case 'otodom':
    case 'gratka':
      return 'assets/images/apartment1.png';
    default:
      return 'assets/images/apartment3.png';
  }
}

Color analysisColor(int score) {
  if (score >= 75) return AppColors.green;
  if (score >= 40) return AppColors.orange;
  return AppColors.blue;
}

Color statusColor(String status) {
  switch (status) {
    case 'NOWA':
      return AppColors.blue;
    case 'CIEKAWA':
      return AppColors.green;
    case 'KONTAKT':
      return AppColors.orange;
    case 'UMOWIONA':
      return AppColors.purple;
    case 'OBEJRZANA':
      return const Color(0xFF22D3EE);
    case 'ODRZUCONA':
      return AppColors.red;
    default:
      return AppColors.muted;
  }
}

Future<void> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened) await Clipboard.setData(ClipboardData(text: url));
}

String money(int value) => '${spaceNumber(value)} zł';

String meters(int value) => '$value m²';

String formatMoney(int value) => value <= 0 ? 'Cena do uzupełnienia' : money(value);

String shortMoney(int value) {
  if (value >= 1000000) {
    final number = value / 1000000;
    return '${trimDouble(number)} mln zł';
  }
  if (value >= 1000) return '${(value / 1000).round()} tys. zł';
  return '$value zł';
}

String spaceNumber(int value) {
  return value.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (match) => '${match[1]} ',
      );
}

String trimDouble(double value) {
  if (value == value.roundToDouble()) return '${value.round()}';
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String offerFacts(Offer offer) {
  final facts = <String>[];
  if (offer.area > 0) facts.add('${trimDouble(offer.area)} m²');
  if (offer.rooms > 0) facts.add('${offer.rooms} pok.');
  if (offer.pricePerMeter > 0) {
    facts.add('${spaceNumber(offer.pricePerMeter.round())} zł/m²');
  }
  return facts.join(' · ');
}

String locationLabel(Offer offer) {
  return offer.district.trim().isEmpty ? offer.city : '${offer.city}, ${offer.district}';
}

String addedLabel(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return 'Data dodania nieznana';
  final difference = DateTime.now().difference(date);
  if (difference.inMinutes < 2) return 'Dodano przed chwilą';
  if (difference.inMinutes < 60) return 'Dodano ${difference.inMinutes} min temu';
  if (difference.inHours < 24) return 'Dodano ${difference.inHours} godz. temu';
  if (difference.inDays == 1) return 'Dodano wczoraj';
  if (difference.inDays < 30) return 'Dodano ${difference.inDays} dni temu';
  return 'Dodano ${twoDigits(date.day)}.${twoDigits(date.month)}.${date.year}';
}

String twoDigits(int value) => value.toString().padLeft(2, '0');

double median(List<double> values) {
  if (values.isEmpty) return 0;
  final middle = values.length ~/ 2;
  if (values.length.isOdd) return values[middle];
  return (values[middle - 1] + values[middle]) / 2;
}

List<MapEntry<String, int>> mostCommonWords(
  List<Offer> offers, {
  int limit = 12,
}) {
  const ignored = <String>{
    'oraz',
    'jest',
    'mieszkanie',
    'mieszkania',
    'oferta',
    'sprzedaz',
    'pokoje',
    'pokojowe',
    'znajduje',
    'sie',
    'przy',
    'dla',
    'ktore',
    'ktory',
    'bardzo',
    'lokal',
    'nieruchomosc',
    'powierzchni',
    'gdańsk',
    'gdansk',
    'cena',
    'wraz',
    'posiada',
    'blisko',
    'dwa',
    'trzy',
    'dostepne',
  };
  final counts = <String, int>{};
  for (final offer in offers) {
    final text = foldPolish('${offer.title} ${offer.description} ${offer.notes}')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.length < 4 || ignored.contains(word) || int.tryParse(word) != null) {
        continue;
      }
      counts[word] = (counts[word] ?? 0) + 1;
    }
  }
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final count = b.value.compareTo(a.value);
      return count != 0 ? count : a.key.compareTo(b.key);
    });
  return entries.take(limit).toList();
}

String offersToCsv(List<Offer> offers) {
  final rows = <List<String>>[
    [
      'Tytuł',
      'Portal',
      'Miasto',
      'Dzielnica',
      'Cena',
      'Metraż',
      'Pokoje',
      'Cena za m²',
      'Forma własności',
      'Dopasowanie',
      'Status',
      'Telefon',
      'Notatki',
      'Link',
      'Dodano',
    ],
    ...offers.map(
      (offer) => [
        offer.title,
        portalDisplayName(offer.portal),
        offer.city,
        offer.district,
        '${offer.price}',
        trimDouble(offer.area),
        '${offer.rooms}',
        offer.pricePerMeter > 0 ? '${offer.pricePerMeter.round()}' : '',
        offer.ownership,
        '${offer.score}%',
        statusLabels[offer.status] ?? offer.status,
        offer.phone,
        offer.notes,
        offer.url,
        offer.addedAt,
      ],
    ),
  ];
  return '\uFEFF${rows.map((row) => row.map(csvCell).join(';')).join('\n')}';
}

String csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

Future<void> showImportLinkDialog(
  BuildContext context,
  Future<void> Function(String text) onImport,
) async {
  final controller = TextEditingController();
  final clipboard = await Clipboard.getData('text/plain');
  if (clipboard?.text != null && extractOfferUrl(clipboard!.text!) != null) {
    controller.text = extractOfferUrl(clipboard.text!)!;
  }
  if (!context.mounted) {
    controller.dispose();
    return;
  }
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Dodaj link oferty'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: 'https://...',
          prefixIcon: Icon(Icons.link_rounded),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('Dalej'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result != null && result.trim().isNotEmpty) await onImport(result);
}

Future<String?> showLargeTextDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required String actionLabel,
}) async {
  final controller = TextEditingController();
  final clipboard = await Clipboard.getData('text/plain');
  if (clipboard?.text != null && clipboard!.text!.trim().startsWith('{')) {
    controller.text = clipboard.text!;
  }
  if (!context.mounted) {
    controller.dispose();
    return null;
  }
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: controller,
          minLines: 8,
          maxLines: 14,
          decoration: InputDecoration(hintText: hint),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.red)
              : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
