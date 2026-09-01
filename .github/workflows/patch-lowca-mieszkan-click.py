from pathlib import Path

p = Path('lowca_mieszkan_build/lib/main.dart')
s = p.read_text(encoding='utf-8')

old = '''  void _generate() {\n    FocusScope.of(context).unfocus();\n    setState(() => _generated = _currentSpec());\n  }\n'''
new = '''  Future<void> _generate() async {\n    FocusScope.of(context).unfocus();\n    final spec = _currentSpec();\n    setState(() => _generated = spec);\n    await _openAllPortals(spec);\n  }\n'''
if old not in s:
    raise SystemExit('Nie znaleziono bloku _generate')
s = s.replace(old, new, 1)

marker = '''  String _portalSearchUrl(Portal portal, SearchSpec spec) {\n'''
insert = '''  String _allPortalsSearchUrl(SearchSpec spec) {\n    final locations = spec.location\n        .split(',')\n        .map((e) => e.trim())\n        .where((e) => e.isNotEmpty)\n        .toList();\n    final locationQuery = locations.isEmpty\n        ? ''\n        : locations.length == 1\n            ? '\"${locations.first}\"'\n            : '(${locations.map((e) => '\"$e\"').join(' OR ')})';\n\n    final siteQuery = '(${portals.map((p) => 'site:${p.domain}').join(' OR ')})';\n    final parts = <String>[\n      siteQuery,\n      locationQuery,\n      _ownershipQuery(spec.ownership),\n      if (spec.rooms.isNotEmpty) '\"${spec.rooms} pokoje\" OR \"${spec.rooms}-pokojowe\"',\n      if (spec.priceMin.isNotEmpty && spec.priceMax.isNotEmpty)\n        '${spec.priceMin}..${spec.priceMax} zł',\n      if (spec.areaMin.isNotEmpty && spec.areaMax.isNotEmpty)\n        '${spec.areaMin}..${spec.areaMax} m2',\n      if (spec.extraWords.isNotEmpty) spec.extraWords,\n    ];\n\n    final excluded = spec.excludeWords\n        .split(',')\n        .map((e) => e.trim())\n        .where((e) => e.isNotEmpty)\n        .map((e) => '-\"$e\"');\n    parts.addAll(excluded);\n\n    final query = parts.where((e) => e.trim().isNotEmpty).join(' ');\n    return Uri.https('www.google.com', '/search', {'q': query}).toString();\n  }\n\n'''
if marker not in s:
    raise SystemExit('Nie znaleziono _portalSearchUrl')
s = s.replace(marker, insert + marker, 1)

old = '''  Future<void> _openPortal(Portal portal, SearchSpec spec) async {\n    final url = _portalSearchUrl(portal, spec);\n    if (!mounted) return;\n    await Navigator.of(context).push(\n      MaterialPageRoute(\n        builder: (_) => BrowserScreen(\n          title: '${portal.name} • ${spec.location}',\n          initialUrl: url,\n          onFavorite: widget.onFavorite,\n        ),\n      ),\n    );\n  }\n'''
new = '''  Future<bool> _openExternalOrFallback({\n    required String url,\n    required String title,\n  }) async {\n    final uri = Uri.tryParse(url);\n    if (uri == null) return false;\n\n    try {\n      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);\n      if (opened) return true;\n    } catch (_) {\n      // Fallback do WebView poniżej.\n    }\n\n    if (!mounted) return false;\n    try {\n      await Navigator.of(context).push(\n        MaterialPageRoute(\n          builder: (_) => BrowserScreen(\n            title: title,\n            initialUrl: url,\n            onFavorite: widget.onFavorite,\n          ),\n        ),\n      );\n      return true;\n    } catch (_) {\n      if (mounted) {\n        ScaffoldMessenger.of(context).showSnackBar(\n          const SnackBar(\n            content: Text('Nie udało się otworzyć wyszukiwania. Sprawdź połączenie z internetem.'),\n          ),\n        );\n      }\n      return false;\n    }\n  }\n\n  Future<void> _openAllPortals(SearchSpec spec) async {\n    final url = _allPortalsSearchUrl(spec);\n    await _openExternalOrFallback(\n      url: url,\n      title: 'Wszystkie portale • ${spec.location}',\n    );\n  }\n\n  Future<void> _openPortal(Portal portal, SearchSpec spec) async {\n    final url = _portalSearchUrl(portal, spec);\n    await _openExternalOrFallback(\n      url: url,\n      title: '${portal.name} • ${spec.location}',\n    );\n  }\n'''
if old not in s:
    raise SystemExit('Nie znaleziono starego _openPortal')
s = s.replace(old, new, 1)

s = s.replace("child: Text('Przygotuj wyszukiwanie'),", "child: Text('Szukaj ofert'),", 1)
s = s.replace(
    "'Każde wyszukiwanie ma twarde ograniczenie site: do wybranego portalu. '",
    "'Główny przycisk przeszukuje wszystkie obsługiwane portale. Poniżej możesz też wybrać jeden konkretny portal. '",
    1,
)

p.write_text(s, encoding='utf-8')
print('Poprawiono obsługę wyszukiwania:', p)
