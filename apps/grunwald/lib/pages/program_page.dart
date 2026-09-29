import 'package:flutter/material.dart';

import '../models/program_event.dart';
import '../state/app_controller.dart';
import '../theme/medieval_theme.dart';
import '../utils/category_catalog.dart';
import '../utils/icon_catalog.dart';
import '../utils/polish_date.dart';
import '../utils/search_text.dart';
import '../widgets/admin_pin_dialog.dart';
import '../widgets/event_details_sheet.dart';
import '../widgets/parchment_panel.dart';
import '../widgets/place_editor_dialog.dart';

class ProgramPage extends StatefulWidget {
  const ProgramPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<ProgramPage> createState() => _ProgramPageState();
}

class _ProgramPageState extends State<ProgramPage> {
  final TextEditingController _searchController = TextEditingController();
  int _dateIndex = 0;
  String _query = '';
  String? _category;
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _dateIndex = _initialDateIndex(widget.controller.programDates);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dates = widget.controller.programDates;
    if (dates.isEmpty) {
      return const Center(
        child: Text(
          'Brak programu.',
          style: TextStyle(color: MedievalColors.goldBright),
        ),
      );
    }
    final safeIndex = _dateIndex.clamp(0, dates.length - 1).toInt();
    final selectedDate = dates[safeIndex];
    final events = _filteredEvents(selectedDate);
    final availableCategories = widget.controller.events
        .map((event) => event.category)
        .toSet();

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        SizedBox(
          height: 62,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final selected = index == safeIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _dateIndex = index),
                  showCheckmark: false,
                  selectedColor: MedievalColors.goldBright,
                  backgroundColor: MedievalColors.charcoal,
                  side: BorderSide(
                    color: selected
                        ? MedievalColors.goldBright
                        : MedievalColors.inkSoft,
                  ),
                  label: SizedBox(
                    width: 48,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          PolishDate.weekdayShort(date),
                          style: TextStyle(
                            color: selected
                                ? MedievalColors.black
                                : MedievalColors.parchmentDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          PolishDate.short(date),
                          style: TextStyle(
                            color: selected
                                ? MedievalColors.black
                                : MedievalColors.parchmentLight,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        ParchmentPanel(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Szukaj wydarzenia…',
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
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'Ulubione',
                icon: _favoritesOnly ? Icons.star : Icons.star_border,
                selected: _favoritesOnly,
                onSelected: () =>
                    setState(() => _favoritesOnly = !_favoritesOnly),
              ),
              _FilterChip(
                label: 'Wszystkie',
                icon: Icons.apps,
                selected: _category == null,
                onSelected: () => setState(() => _category = null),
              ),
              for (final entry in CategoryCatalog.eventCategories)
                if (availableCategories.contains(entry.id))
                  _FilterChip(
                    label: entry.label,
                    icon: entry.icon,
                    selected: _category == entry.id,
                    onSelected: () => setState(() => _category = entry.id),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: Text(
                PolishDate.full(selectedDate),
                style: const TextStyle(
                  color: MedievalColors.goldBright,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${events.length} wydarzeń',
              style: const TextStyle(
                color: MedievalColors.parchmentDark,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const ParchmentPanel(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy,
                    color: MedievalColors.inkSoft,
                    size: 38,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Brak wydarzeń pasujących do filtrów.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MedievalColors.ink,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ParchmentPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < events.length; index++) ...[
                  _ProgramRow(
                    event: events[index],
                    placeName:
                        widget.controller.placeName(events[index].placeId),
                    favorite:
                        widget.controller.isFavoriteEvent(events[index].id),
                    onTap: () => showEventDetailsSheet(
                      context,
                      widget.controller,
                      events[index],
                    ),
                    onFavoriteTap: () => widget.controller
                        .toggleFavoriteEvent(events[index].id),
                  ),
                  if (index != events.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: MedievalColors.parchmentDark,
                    ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),
        _AdminPanel(controller: widget.controller),
      ],
    );
  }

  List<ProgramEvent> _filteredEvents(DateTime selectedDate) {
    final normalizedQuery = SearchText.normalize(_query);
    return widget.controller.eventsForDate(selectedDate).where((event) {
      if (_favoritesOnly && !widget.controller.isFavoriteEvent(event.id)) {
        return false;
      }
      if (_category != null && event.category != _category) return false;
      if (normalizedQuery.isEmpty) return true;
      final searchable = <String>[
        event.title,
        event.description,
        widget.controller.placeName(event.placeId),
        CategoryCatalog.eventLabel(event.category),
      ].join(' ');
      return SearchText.normalize(searchable).contains(normalizedQuery);
    }).toList(growable: false);
  }

  int _initialDateIndex(List<DateTime> dates) {
    if (dates.isEmpty) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var index = 0; index < dates.length; index++) {
      final date = DateTime(
        dates[index].year,
        dates[index].month,
        dates[index].day,
      );
      if (!date.isBefore(today)) return index;
    }
    return dates.length - 1;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
          size: 16,
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

class _ProgramRow extends StatelessWidget {
  const _ProgramRow({
    required this.event,
    required this.placeName,
    required this.favorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final ProgramEvent event;
  final String placeName;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 4, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 47,
              child: Text(
                event.start,
                style: const TextStyle(
                  color: MedievalColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(
              width: 34,
              child: Icon(
                IconCatalog.eventIcon(event.category),
                size: 21,
                color: MedievalColors.inkSoft,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            color: MedievalColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (event.isRehearsal)
                        const Padding(
                          padding: EdgeInsets.only(left: 5),
                          child: Tooltip(
                            message: 'Próba',
                            child: Icon(
                              Icons.build_outlined,
                              size: 15,
                              color: MedievalColors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 13,
                        color: MedievalColors.inkSoft,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MedievalColors.inkSoft,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: favorite ? 'Usuń z ulubionych' : 'Dodaj do ulubionych',
              onPressed: onFavoriteTap,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                favorite ? Icons.star : Icons.star_border,
                color: favorite
                    ? MedievalColors.red
                    : MedievalColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminPanel extends StatelessWidget {
  const _AdminPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: MedievalColors.charcoal.withValues(alpha: 0.96),
        border: Border.all(color: MedievalColors.inkSoft, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Divider(color: MedievalColors.gold)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    if (controller.adminUnlocked) ...[
                      const Icon(
                        Icons.circle,
                        size: 8,
                        color: MedievalColors.green,
                      ),
                      const SizedBox(width: 6),
                    ],
                    const Text(
                      'ADMINISTRACJA',
                      style: TextStyle(
                        color: MedievalColors.goldBright,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(child: Divider(color: MedievalColors.gold)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _addPoint(context),
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Dodaj punkt'),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: MedievalColors.parchmentLight,
                side: const BorderSide(color: MedievalColors.gold),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onPressed: () => _editPositions(context),
              icon: const Icon(Icons.edit_location_alt),
              label: Text(
                controller.editMode
                    ? 'Zakończ edycję punktów'
                    : 'Edytuj położenie punktów',
              ),
            ),
          ),
          if (controller.adminUnlocked) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _reset(context),
                    icon: const Icon(Icons.restore),
                    label: const Text('Przywróć mapę'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: controller.lockAdmin,
                    icon: const Icon(Icons.lock),
                    label: const Text('Wyłącz admina'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<bool> _ensureAdmin(BuildContext context) =>
      requestAdminAccess(context, controller);

  Future<void> _addPoint(BuildContext context) async {
    if (!await _ensureAdmin(context) || !context.mounted) return;
    final place = await showPlaceEditorDialog(context);
    if (place != null) {
      await controller.addPlace(place);
      controller.setEditMode(true);
    }
  }

  Future<void> _editPositions(BuildContext context) async {
    if (!await _ensureAdmin(context)) return;
    controller.setEditMode(!controller.editMode);
  }

  Future<void> _reset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MedievalColors.charcoal,
        title: const Text('Przywrócić mapę?'),
        content: const Text(
          'Usunięte zostaną własne punkty, przesunięcia i zmiany opisów miejsc. Kalibracja GPS pozostanie bez zmian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Przywróć'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.resetMapChanges();
  }
}
