import 'package:flutter/material.dart';

import '../models/place.dart';
import '../theme/medieval_theme.dart';
import '../utils/category_catalog.dart';
import '../utils/icon_catalog.dart';

Future<Place?> showPlaceEditorDialog(
  BuildContext context, {
  Place? place,
  double initialX = 0.5,
  double initialY = 0.5,
}) async {
  final nameController = TextEditingController(
    text: place?.name ?? 'Nowy punkt',
  );
  final subtitleController = TextEditingController(
    text: place?.subtitle ?? 'Punkt administratora',
  );
  final descriptionController = TextEditingController(
    text: place?.description ?? '',
  );
  var selectedCategory = place?.category ?? 'własny';
  var selectedIcon = place?.icon ?? 'place';
  var selectedColor = place?.color ?? 'red';
  String? nameError;

  final result = await showDialog<Place>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setInnerState) {
          return AlertDialog(
            backgroundColor: MedievalColors.charcoal,
            title: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: IconCatalog.markerColor(selectedColor),
                    border: Border.all(color: MedievalColors.gold, width: 2),
                  ),
                  child: Icon(
                    IconCatalog.placeIcon(selectedIcon),
                    color: Colors.white,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(place == null ? 'Dodaj punkt' : 'Edytuj punkt'),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: place == null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Nazwa',
                        errorText: nameError,
                      ),
                      onChanged: (_) {
                        if (nameError != null) {
                          setInnerState(() => nameError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subtitleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Krótki opis',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Opis'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      isExpanded: true,
                      dropdownColor: MedievalColors.parchmentLight,
                      style: const TextStyle(color: MedievalColors.ink),
                      decoration: const InputDecoration(
                        labelText: 'Kategoria',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: [
                        for (final entry in CategoryCatalog.placeCategories)
                          DropdownMenuItem<String>(
                            value: entry.id,
                            child: Row(
                              children: [
                                Icon(
                                  entry.icon,
                                  size: 19,
                                  color: MedievalColors.ink,
                                ),
                                const SizedBox(width: 9),
                                Text(entry.label),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setInnerState(() {
                          selectedCategory = value;
                          if (place == null && selectedIcon == 'place') {
                            selectedIcon = _defaultIconForCategory(value);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ikona punktu',
                      style: TextStyle(
                        color: MedievalColors.parchmentLight,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final option in CategoryCatalog.markerIcons)
                          ChoiceChip(
                            selected: selectedIcon == option.id,
                            onSelected: (_) => setInnerState(
                              () => selectedIcon = option.id,
                            ),
                            showCheckmark: false,
                            avatar: Icon(
                              IconCatalog.placeIcon(option.id),
                              size: 18,
                              color: selectedIcon == option.id
                                  ? MedievalColors.black
                                  : MedievalColors.goldBright,
                            ),
                            label: Text(option.label),
                            labelStyle: TextStyle(
                              color: selectedIcon == option.id
                                  ? MedievalColors.black
                                  : MedievalColors.parchmentLight,
                            ),
                            selectedColor: MedievalColors.goldBright,
                            backgroundColor: MedievalColors.ink,
                            side: const BorderSide(
                              color: MedievalColors.inkSoft,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kolor znacznika',
                      style: TextStyle(
                        color: MedievalColors.parchmentLight,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in CategoryCatalog.markerColors)
                          Tooltip(
                            message: option.label,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => setInnerState(
                                () => selectedColor = option.id,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: option.color,
                                  border: Border.all(
                                    color: selectedColor == option.id
                                        ? MedievalColors.goldBright
                                        : Colors.white54,
                                    width: selectedColor == option.id ? 4 : 2,
                                  ),
                                ),
                                child: selectedColor == option.id
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Anuluj'),
              ),
              FilledButton.icon(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    setInnerState(() => nameError = 'Wpisz nazwę punktu');
                    return;
                  }
                  final identifier = place?.id ??
                      'custom_${DateTime.now().microsecondsSinceEpoch}';
                  Navigator.pop(
                    context,
                    Place(
                      id: identifier,
                      name: name,
                      subtitle: subtitleController.text.trim(),
                      description: descriptionController.text.trim(),
                      category: selectedCategory,
                      x: place?.x ?? initialX,
                      y: place?.y ?? initialY,
                      icon: selectedIcon,
                      color: selectedColor,
                      verified: place?.verified ?? false,
                      custom: place?.custom ?? true,
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Zapisz'),
              ),
            ],
          );
        },
      );
    },
  );
  nameController.dispose();
  subtitleController.dispose();
  descriptionController.dispose();
  return result;
}

String _defaultIconForCategory(String category) {
  return switch (category) {
    'oboz' => 'camp',
    'atrakcja' || 'pole' => 'swords',
    'uslugi' => 'wc',
    'pomnik' => 'monument',
    'muzeum' => 'museum',
    'kaplica' => 'cross',
    'scena' => 'music',
    'parking' => 'parking',
    _ => 'place',
  };
}
