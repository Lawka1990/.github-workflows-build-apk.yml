import 'package:flutter/material.dart';

import '../models/place.dart';
import '../state/app_controller.dart';
import '../theme/medieval_theme.dart';

Future<void> showFieldCalibrationDialog(
  BuildContext context,
  AppController controller,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _FieldCalibrationDialog(controller: controller),
  );
}

class _FieldCalibrationDialog extends StatefulWidget {
  const _FieldCalibrationDialog({required this.controller});

  final AppController controller;

  @override
  State<_FieldCalibrationDialog> createState() =>
      _FieldCalibrationDialogState();
}

class _FieldCalibrationDialogState extends State<_FieldCalibrationDialog> {
  String? _selectedPlaceId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final places = _calibrationPlaces;
    _selectedPlaceId = places.any((place) => place.id == 'oboz_goncza')
        ? 'oboz_goncza'
        : places.firstOrNull?.id;
  }

  List<Place> get _calibrationPlaces {
    final result = widget.controller.places
        .where((place) => place.verified && !place.custom)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.controller.lastGpsPosition;
    final places = _calibrationPlaces;
    return AlertDialog(
      backgroundColor: MedievalColors.charcoal,
      title: const Row(
        children: [
          Icon(Icons.gps_fixed, color: MedievalColors.goldBright),
          SizedBox(width: 10),
          Expanded(child: Text('Kalibracja terenowa GPS')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Stań dokładnie w znanym miejscu, wybierz je z listy i zapisz. '
                'Aplikacja połączy rzeczywisty GPS z właściwym punktem na rysunku.',
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MedievalColors.ink,
                  border: Border.all(color: MedievalColors.gold),
                ),
                child: position == null
                    ? const Text('Brak odczytu GPS. Najpierw naciśnij „Odśwież GPS”.')
                    : Text(
                        'GPS: ${position.latitude.toStringAsFixed(7)}, '
                        '${position.longitude.toStringAsFixed(7)}\n'
                        'Dokładność: ±${position.accuracy.round()} m',
                        style: const TextStyle(
                          color: MedievalColors.parchmentLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedPlaceId,
                isExpanded: true,
                dropdownColor: MedievalColors.parchmentLight,
                style: const TextStyle(color: MedievalColors.ink),
                decoration: const InputDecoration(
                  labelText: 'Miejsce, w którym teraz stoisz',
                  prefixIcon: Icon(Icons.place),
                ),
                items: [
                  for (final place in places)
                    DropdownMenuItem<String>(
                      value: place.id,
                      child: Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _selectedPlaceId = value),
              ),
              const SizedBox(height: 10),
              Text(
                'Zapisane kotwice terenowe: '
                '${widget.controller.fieldCalibrationAnchors.length}',
                style: const TextStyle(color: MedievalColors.parchmentDark),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _saving ? null : _refreshGps,
                icon: const Icon(Icons.my_location),
                label: const Text('Odśwież GPS'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _saving || _selectedPlaceId == null
                    ? null
                    : _saveAnchor,
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Jestem dokładnie w tym miejscu'),
              ),
              if (widget.controller.fieldCalibrationAnchors.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _saving ? null : _clearAnchors,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Usuń kotwice terenowe'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Zamknij'),
        ),
      ],
    );
  }

  Future<void> _refreshGps() async {
    setState(() => _saving = true);
    await widget.controller.locateUser();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveAnchor() async {
    final id = _selectedPlaceId;
    if (id == null) return;
    final place = widget.controller.placeById(id);
    if (place == null) return;
    setState(() => _saving = true);
    final message = await widget.controller.calibrateCurrentPositionToPlace(place);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _clearAnchors() async {
    setState(() => _saving = true);
    await widget.controller.clearFieldCalibration();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usunięto terenowe kotwice GPS.')),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
