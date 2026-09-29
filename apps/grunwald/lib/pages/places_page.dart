import 'package:flutter/material.dart';

import '../models/place.dart';
import '../state/app_controller.dart';
import '../theme/medieval_theme.dart';
import '../utils/category_catalog.dart';
import '../utils/icon_catalog.dart';
import '../utils/search_text.dart';
import '../widgets/parchment_panel.dart';
import '../widgets/place_details_sheet.dart';

class PlacesPage extends StatefulWidget {
  const PlacesPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _category;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final places = _filteredPlaces;
    final categories = widget.controller.places
        .map((place) => place.category)
        .toSet();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: ParchmentPanel(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Szukaj miejsca, obozu lub usługi…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Wyczyść wyszukiwanie',
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close),
                      ),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _CategoryChip(
                label: 'Wszystkie',
                icon: Icons.apps,
                selected: _category == null,
                onSelected: () => setState(() => _category = null),
              ),
              for (final entry in CategoryCatalog.placeCategories)
                if (categories.contains(entry.id))
                  _CategoryChip(
                    label: entry.label,
                    icon: entry.icon,
                    selected: _category == entry.id,
                    onSelected: () => setState(() => _category = entry.id),
                  ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 1, 16, 7),
          child: Row(
            children: [
              Text(
                'Znaleziono: ${places.length}',
                style: const TextStyle(
                  color: MedievalColors.parchmentDark,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (_query.isNotEmpty || _category != null)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Wyczyść filtry'),
                ),
            ],
          ),
        ),
        Expanded(
          child: places.isEmpty
              ? const _EmptyPlaces()
              : ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                  itemCount: places.length,
                  itemBuilder: (context, index) {
                    final place = places[index];
                    return _PlaceRow(
                      place: place,
                      onTap: () => showPlaceDetailsSheet(
                        context,
                        widget.controller,
                        place,
                      ),
                      onMapTap: () =>
                          widget.controller.showPlaceOnMap(place.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<Place> get _filteredPlaces {
    final normalizedQuery = SearchText.normalize(_query);
    return widget.controller.places.where((place) {
      if (_category != null && place.category != _category) return false;
      if (normalizedQuery.isEmpty) return true;
      final searchable = <String>[
        place.name,
        place.subtitle,
        place.description,
        CategoryCatalog.placeLabel(place.category),
      ].join(' ');
      final normalizedSearchable = SearchText.normalize(searchable);
      return normalizedSearchable.contains(normalizedQuery);
    }).toList(growable: false);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _category = null;
    });
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onSelected(),
        avatar: Icon(
          icon,
          size: 17,
          color: selected ? MedievalColors.black : MedievalColors.goldBright,
        ),
        label: Text(label),
        labelStyle: TextStyle(
          color: selected
              ? MedievalColors.black
              : MedievalColors.parchmentLight,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
        selectedColor: MedievalColors.goldBright,
        backgroundColor: MedievalColors.charcoal,
        side: const BorderSide(color: MedievalColors.inkSoft),
        showCheckmark: false,
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.place,
    required this.onTap,
    required this.onMapTap,
  });

  final Place place;
  final VoidCallback onTap;
  final VoidCallback onMapTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${place.name}, ${place.subtitle}',
      child: ParchmentPanel(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: IconCatalog.markerColor(place.color),
                border: Border.all(color: MedievalColors.ink, width: 1.8),
              ),
              child: Icon(
                IconCatalog.placeIcon(place.icon),
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          place.name,
                          style: const TextStyle(
                            color: MedievalColors.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (place.verified) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: 'Położenie sprawdzone',
                          child: Icon(
                            Icons.verified,
                            size: 15,
                            color: MedievalColors.green,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.subtitle.isEmpty
                        ? CategoryCatalog.placeLabel(place.category)
                        : place.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MedievalColors.inkSoft,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Pokaż na mapie',
              onPressed: onMapTap,
              icon: const Icon(
                Icons.map_outlined,
                color: MedievalColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlaces extends StatelessWidget {
  const _EmptyPlaces();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              color: MedievalColors.goldBright,
              size: 48,
            ),
            SizedBox(height: 10),
            Text(
              'Nie znaleziono takiego miejsca.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MedievalColors.parchmentLight,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
