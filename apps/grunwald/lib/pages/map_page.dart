import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/place.dart';
import '../services/map_navigation.dart';
import '../state/app_controller.dart';
import '../theme/medieval_theme.dart';
import '../utils/category_catalog.dart';
import '../utils/icon_catalog.dart';
import '../widgets/field_calibration_dialog.dart';
import '../widgets/parchment_panel.dart';
import '../widgets/place_details_sheet.dart';
import '../widgets/place_editor_dialog.dart';
import '../widgets/place_marker.dart';

class MapPage extends StatefulWidget {
  const MapPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // Oryginalny plik ma 1536 × 1024 px. Zachowanie tych proporcji usuwa
  // wcześniejsze pionowe ściśnięcie mapy.
  static const double _mapWidth = 1536;
  static const double _mapHeight = 1024;
  static const Offset _mainCampCenter = Offset(0.57, 0.58);

  final TransformationController _transformation = TransformationController();
  Size _viewport = Size.zero;
  bool _initialViewApplied = false;
  int _handledFocusSerial = -1;
  Place? _selectedPlace;
  Place? _navigationTarget;
  final Set<String> _hiddenCategories = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.locateUser();
    });
  }

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        _scheduleFocusIfNeeded();
        return LayoutBuilder(
          builder: (context, constraints) {
            final viewport = Size(constraints.maxWidth, constraints.maxHeight);
            if (_viewport != viewport) {
              _viewport = viewport;
              _initialViewApplied = false;
            }
            _scheduleInitialView();
            final containScale = _containScale(viewport);
            final selectedPlace = _selectedPlace == null
                ? null
                : controller.placeById(_selectedPlace!.id);
            final navigationTarget = _navigationTarget == null
                ? null
                : controller.placeById(_navigationTarget!.id);
            final route = !controller.editMode &&
                    navigationTarget != null &&
                    controller.userMapPosition != null
                ? MapNavigation.routeBetween(
                    controller.userMapPosition!,
                    Offset(navigationTarget.x, navigationTarget.y),
                  )
                : null;

            return Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: MedievalColors.black,
                    child: ClipRect(
                      child: InteractiveViewer(
                        transformationController: _transformation,
                        constrained: false,
                        panEnabled: !controller.editMode,
                        scaleEnabled: !controller.editMode,
                        minScale: containScale * 0.92,
                        maxScale: 5.5,
                        boundaryMargin: const EdgeInsets.all(420),
                        child: SizedBox(
                          width: _mapWidth,
                          height: _mapHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: GestureDetector(
                                  onLongPressStart: controller.editMode
                                      ? (details) => _addAt(details.localPosition)
                                      : null,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: MedievalColors.gold,
                                        width: 6,
                                      ),
                                      boxShadow: const <BoxShadow>[
                                        BoxShadow(
                                          color: Colors.black87,
                                          blurRadius: 20,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      'assets/images/mapa_grunwald_2026.png',
                                      width: _mapWidth,
                                      height: _mapHeight,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                      gaplessPlayback: true,
                                    ),
                                  ),
                                ),
                              ),
                              if (route != null)
                                AnimatedBuilder(
                                  animation: _transformation,
                                  builder: (context, _) {
                                    return IgnorePointer(
                                      child: CustomPaint(
                                        size: const Size(
                                          _mapWidth,
                                          _mapHeight,
                                        ),
                                        painter: _MapRoutePainter(
                                          route: route,
                                          strokeWidth: 8 / _currentScale,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              for (final place in controller.places)
                                if (_isPlaceVisible(place))
                                  _positionedPlace(place),
                              if (controller.userMapPosition != null)
                                Positioned(
                                  left: controller.userMapPosition!.dx *
                                          _mapWidth -
                                      27,
                                  top: controller.userMapPosition!.dy *
                                          _mapHeight -
                                      27,
                                  child: AnimatedBuilder(
                                    animation: _transformation,
                                    builder: (context, child) {
                                      final scale = _currentScale;
                                      return Transform.scale(
                                        scale: 1 / scale,
                                        child: child,
                                      );
                                    },
                                    child: const UserLocationMarker(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (controller.editMode)
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: ParchmentPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.edit_location_alt,
                            color: MedievalColors.red,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'EDYCJA: przeciągaj punkty. Przytrzymaj mapę, aby dodać nowy.',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Zakończ edycję',
                            onPressed: () => controller.setEditMode(false),
                            icon: const Icon(
                              Icons.close,
                              color: MedievalColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (route != null && navigationTarget != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: _NavigationBanner(
                      target: navigationTarget,
                      estimatedMeters: route.estimatedMeters,
                      onFitRoute: () => _fitRoute(route),
                      onStop: () => setState(() => _navigationTarget = null),
                    ),
                  ),
                if (controller.lastGpsPosition != null)
                  Positioned(
                    top: controller.editMode
                        ? 76
                        : route != null
                            ? 82
                            : 10,
                    right: 10,
                    child: _GpsBadge(
                      accuracy: controller.lastGpsPosition!.accuracy,
                      calibrationCount:
                          controller.fieldCalibrationAnchors.length,
                    ),
                  ),
                Positioned(
                  right: 12,
                  bottom: 16,
                  child: Column(
                    children: [
                      _MapActionButton(
                        tooltip: 'Moja pozycja',
                        icon: controller.locating
                            ? Icons.hourglass_top
                            : Icons.my_location,
                        onTap: _locateUser,
                      ),
                      const SizedBox(height: 9),
                      _MapActionButton(
                        tooltip: 'Główne obozowisko',
                        icon: Icons.center_focus_strong,
                        onTap: _showMainCamp,
                      ),
                      const SizedBox(height: 9),
                      _MapActionButton(
                        tooltip: 'Pokaż całą mapę',
                        icon: Icons.fullscreen,
                        onTap: _fitWholeMap,
                      ),
                      const SizedBox(height: 9),
                      _MapActionButton(
                        tooltip: 'Filtruj punkty mapy',
                        icon: _hiddenCategories.isEmpty
                            ? Icons.filter_alt_outlined
                            : Icons.filter_alt,
                        active: _hiddenCategories.isNotEmpty,
                        onTap: _showMarkerFilters,
                      ),
                      if (controller.adminUnlocked) ...[
                        const SizedBox(height: 9),
                        _MapActionButton(
                          tooltip: 'Kalibracja terenowa GPS',
                          icon: Icons.gps_fixed,
                          onTap: _openFieldCalibration,
                        ),
                      ],
                    ],
                  ),
                ),
                if (selectedPlace != null)
                  Positioned(
                    left: 12,
                    right: 70,
                    bottom: 14,
                    child: _SelectedPlaceCard(
                      place: selectedPlace,
                      adminUnlocked: controller.adminUnlocked,
                      navigating: navigationTarget?.id == selectedPlace.id,
                      onDetails: () => showPlaceDetailsSheet(
                        context,
                        controller,
                        selectedPlace,
                      ),
                      onNavigate: () =>
                          _startOrStopNavigation(selectedPlace),
                      onEdit: _editSelectedPlace,
                      onDelete: selectedPlace.custom
                          ? _deleteSelectedPlace
                          : null,
                      onClose: () {
                        controller.clearMapFocus();
                        setState(() => _selectedPlace = null);
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _positionedPlace(Place place) {
    final selected = _selectedPlace?.id == place.id ||
        widget.controller.focusedPlaceId == place.id ||
        _navigationTarget?.id == place.id;
    return Positioned(
      left: place.x * _mapWidth - (selected ? 24 : 20),
      top: place.y * _mapHeight - (selected ? 24 : 20),
      child: AnimatedBuilder(
        animation: _transformation,
        builder: (context, child) {
          return Transform.scale(scale: 1 / _currentScale, child: child);
        },
        child: PlaceMarker(
          place: place,
          selected: selected,
          editing: widget.controller.editMode,
          onTap: () {
            widget.controller.clearMapFocus();
            setState(() => _selectedPlace = place);
            _focusNormalized(Offset(place.x, place.y), zoomFactor: 1.75);
          },
          onDrag: (delta) {
            final scale = _currentScale;
            widget.controller.movePlace(
              place.id,
              place.x + delta.dx / scale / _mapWidth,
              place.y + delta.dy / scale / _mapHeight,
            );
          },
        ),
      ),
    );
  }

  bool _isPlaceVisible(Place place) {
    return !_hiddenCategories.contains(place.category) ||
        _selectedPlace?.id == place.id ||
        _navigationTarget?.id == place.id ||
        widget.controller.focusedPlaceId == place.id;
  }

  double get _currentScale {
    final value = _transformation.value.getMaxScaleOnAxis();
    return value <= 0 ? 1 : value;
  }

  void _scheduleInitialView() {
    if (_initialViewApplied || _viewport.isEmpty) return;
    _initialViewApplied = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showMainCamp();
    });
  }

  void _scheduleFocusIfNeeded() {
    final controller = widget.controller;
    if (_handledFocusSerial == controller.focusSerial) return;
    _handledFocusSerial = controller.focusSerial;
    final id = controller.focusedPlaceId;
    if (id == null) return;
    final place = controller.placeById(id);
    if (place == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedPlace = place);
      _focusNormalized(Offset(place.x, place.y), zoomFactor: 1.9);
    });
  }

  double _containScale(Size viewport) {
    if (viewport.isEmpty) return 0.2;
    return math.min(
      viewport.width / _mapWidth,
      viewport.height / _mapHeight,
    );
  }

  double _coverScale(Size viewport) {
    if (viewport.isEmpty) return 0.4;
    return math.max(
      viewport.width / _mapWidth,
      viewport.height / _mapHeight,
    );
  }

  void _fitWholeMap() {
    if (_viewport.isEmpty) return;
    final scale = _containScale(_viewport);
    final dx = (_viewport.width - _mapWidth * scale) / 2;
    final dy = (_viewport.height - _mapHeight * scale) / 2;
    _transformation.value = _matrix(scale: scale, dx: dx, dy: dy);
  }

  void _fitRoute(MapNavigationRoute route) {
    if (_viewport.isEmpty || route.points.isEmpty) return;
    var minX = route.points.first.dx;
    var maxX = route.points.first.dx;
    var minY = route.points.first.dy;
    var maxY = route.points.first.dy;
    for (final point in route.points.skip(1)) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }
    final routeWidth = math.max((maxX - minX) * _mapWidth, 90);
    final routeHeight = math.max((maxY - minY) * _mapHeight, 90);
    final availableWidth = math.max(_viewport.width - 96, 120);
    final availableHeight = math.max(_viewport.height - 190, 150);
    final scale = math
        .min(availableWidth / routeWidth, availableHeight / routeHeight)
        .clamp(_containScale(_viewport), 5.5)
        .toDouble();
    _setCentered(
      Offset((minX + maxX) / 2, (minY + maxY) / 2),
      scale,
    );
  }

  void _showMainCamp() {
    if (_viewport.isEmpty) return;
    final scale = _coverScale(_viewport) * 1.03;
    _setCentered(_mainCampCenter, scale);
  }

  void _focusNormalized(
    Offset point, {
    double zoomFactor = 1.8,
  }) {
    if (_viewport.isEmpty) return;
    final base = _coverScale(_viewport);
    final scale = (base * zoomFactor)
        .clamp(_containScale(_viewport), 5.5)
        .toDouble();
    _setCentered(point, scale);
  }

  void _setCentered(Offset point, double scale) {
    final dx = _viewport.width / 2 - point.dx * _mapWidth * scale;
    final dy = _viewport.height / 2 - point.dy * _mapHeight * scale;
    _transformation.value = _matrix(scale: scale, dx: dx, dy: dy);
  }

  Matrix4 _matrix({
    required double scale,
    required double dx,
    required double dy,
  }) {
    final matrix = Matrix4.identity();
    matrix[0] = scale;
    matrix[5] = scale;
    matrix[12] = dx;
    matrix[13] = dy;
    return matrix;
  }

  Future<void> _editSelectedPlace() async {
    final selected = _selectedPlace;
    if (selected == null) return;
    final current = widget.controller.placeById(selected.id);
    if (current == null) return;
    final updated = await showPlaceEditorDialog(context, place: current);
    if (updated == null) return;
    await widget.controller.updatePlace(updated);
    if (mounted) {
      setState(() {
        _selectedPlace = updated;
        if (_navigationTarget?.id == updated.id) {
          _navigationTarget = updated;
        }
      });
    }
  }

  Future<void> _deleteSelectedPlace() async {
    final selected = _selectedPlace;
    if (selected == null) return;
    final current = widget.controller.placeById(selected.id);
    if (current == null || !current.custom) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MedievalColors.charcoal,
        title: const Text('Usunąć punkt?'),
        content: Text(current.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.deletePlace(current.id);
    if (mounted) {
      setState(() {
        _selectedPlace = null;
        if (_navigationTarget?.id == current.id) {
          _navigationTarget = null;
        }
      });
    }
  }

  Future<void> _startOrStopNavigation(Place target) async {
    if (_navigationTarget?.id == target.id) {
      setState(() => _navigationTarget = null);
      return;
    }
    widget.controller.setEditMode(false);
    var position = widget.controller.userMapPosition;
    position ??= await widget.controller.locateUser();
    if (!mounted) return;
    if (position == null) {
      _showLocationError();
      return;
    }
    final route = MapNavigation.routeBetween(
      position,
      Offset(target.x, target.y),
    );
    setState(() => _navigationTarget = target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitRoute(route);
    });
  }

  Future<void> _locateUser() async {
    final position = await widget.controller.locateUser();
    if (!mounted) return;
    if (position == null) {
      _showLocationError();
      return;
    }
    _focusNormalized(position, zoomFactor: 2.15);
  }

  Future<void> _openFieldCalibration() async {
    await showFieldCalibrationDialog(context, widget.controller);
  }

  Future<void> _showMarkerFilters() async {
    final counts = <String, int>{};
    for (final place in widget.controller.places) {
      counts.update(place.category, (value) => value + 1, ifAbsent: () => 1);
    }
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MarkerFilterSheet(
        categoryCounts: counts,
        hiddenCategories: _hiddenCategories,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _hiddenCategories
        ..clear()
        ..addAll(result);
    });
  }

  void _showLocationError() {
    final message = widget.controller.locationError ??
        'Nie udało się ustalić pozycji.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'USTAWIENIA',
          onPressed: () {
            widget.controller.openLocationSettings();
          },
        ),
      ),
    );
  }

  Future<void> _addAt(Offset localPosition) async {
    final normalized = Offset(
      (localPosition.dx / _mapWidth).clamp(0.0, 1.0).toDouble(),
      (localPosition.dy / _mapHeight).clamp(0.0, 1.0).toDouble(),
    );
    final place = await showPlaceEditorDialog(
      context,
      initialX: normalized.dx,
      initialY: normalized.dy,
    );
    if (place != null) await widget.controller.addPlace(place);
  }
}

class _MapRoutePainter extends CustomPainter {
  const _MapRoutePainter({required this.route, required this.strokeWidth});

  final MapNavigationRoute route;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (route.points.length < 2) return;
    final path = Path();
    final first = _scaled(route.points.first, size);
    path.moveTo(first.dx, first.dy);
    for (final point in route.points.skip(1)) {
      final scaled = _scaled(point, size);
      path.lineTo(scaled.dx, scaled.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = strokeWidth * 1.85,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = MedievalColors.goldBright
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = strokeWidth,
    );
    final destination = _scaled(route.points.last, size);
    canvas.drawCircle(
      destination,
      strokeWidth * 1.45,
      Paint()..color = MedievalColors.red,
    );
    canvas.drawCircle(
      destination,
      strokeWidth * 1.45,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.35,
    );
  }

  Offset _scaled(Offset point, Size size) =>
      Offset(point.dx * size.width, point.dy * size.height);

  @override
  bool shouldRepaint(covariant _MapRoutePainter oldDelegate) {
    return oldDelegate.route.points != route.points ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _NavigationBanner extends StatelessWidget {
  const _NavigationBanner({
    required this.target,
    required this.estimatedMeters,
    required this.onFitRoute,
    required this.onStop,
  });

  final Place target;
  final int estimatedMeters;
  final VoidCallback onFitRoute;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return ParchmentPanel(
      padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
      child: Row(
        children: [
          const Icon(Icons.alt_route, color: MedievalColors.red, size: 27),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MedievalColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Trasa orientacyjna • ok. $estimatedMeters m',
                  style: const TextStyle(
                    color: MedievalColors.inkSoft,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Pokaż całą trasę',
            onPressed: onFitRoute,
            icon: const Icon(Icons.zoom_out_map, color: MedievalColors.ink),
          ),
          IconButton(
            tooltip: 'Zakończ prowadzenie',
            onPressed: onStop,
            icon: const Icon(Icons.close, color: MedievalColors.red),
          ),
        ],
      ),
    );
  }
}

class _SelectedPlaceCard extends StatelessWidget {
  const _SelectedPlaceCard({
    required this.place,
    required this.adminUnlocked,
    required this.navigating,
    required this.onDetails,
    required this.onNavigate,
    required this.onEdit,
    required this.onClose,
    this.onDelete,
  });

  final Place place;
  final bool adminUnlocked;
  final bool navigating;
  final VoidCallback onDetails;
  final VoidCallback onNavigate;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ParchmentPanel(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: IconCatalog.markerColor(place.color),
                  border: Border.all(color: MedievalColors.ink, width: 2),
                ),
                child: Icon(
                  IconCatalog.placeIcon(place.icon),
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MedievalColors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    if (place.subtitle.isNotEmpty)
                      Text(
                        place.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MedievalColors.inkSoft,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Zamknij',
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(Icons.close, color: MedievalColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: MedievalColors.inkSoft,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onDetails,
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Szczegóły'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onNavigate,
                icon: Icon(
                  navigating ? Icons.stop_circle_outlined : Icons.alt_route,
                  size: 18,
                ),
                label: Text(navigating ? 'Zakończ' : 'Prowadź'),
              ),
              if (adminUnlocked)
                IconButton(
                  tooltip: 'Edytuj punkt',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, color: MedievalColors.ink),
                ),
              if (adminUnlocked && onDelete != null)
                IconButton(
                  tooltip: 'Usuń punkt',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: MedievalColors.red,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarkerFilterSheet extends StatefulWidget {
  const _MarkerFilterSheet({
    required this.categoryCounts,
    required this.hiddenCategories,
  });

  final Map<String, int> categoryCounts;
  final Set<String> hiddenCategories;

  @override
  State<_MarkerFilterSheet> createState() => _MarkerFilterSheetState();
}

class _MarkerFilterSheetState extends State<_MarkerFilterSheet> {
  late final Set<String> _hidden;

  @override
  void initState() {
    super.initState();
    _hidden = <String>{...widget.hiddenCategories};
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categoryCounts.keys.toList()
      ..sort(
        (first, second) => CategoryCatalog.placeLabel(first)
            .compareTo(CategoryCatalog.placeLabel(second)),
      );
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: MedievalColors.charcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: MedievalColors.gold, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: SizedBox(
              width: 44,
              child: Divider(
                color: MedievalColors.parchmentDark,
                thickness: 3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Punkty widoczne na mapie',
            style: TextStyle(
              color: MedievalColors.goldBright,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ukryj zbędne kategorie, aby mapa była czytelniejsza.',
            style: TextStyle(color: MedievalColors.parchmentDark),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final category in categories)
                  CheckboxListTile(
                    value: !_hidden.contains(category),
                    onChanged: (visible) {
                      setState(() {
                        if (visible ?? false) {
                          _hidden.remove(category);
                        } else {
                          _hidden.add(category);
                        }
                      });
                    },
                    activeColor: MedievalColors.goldBright,
                    checkColor: MedievalColors.black,
                    secondary: Icon(
                      CategoryCatalog.placeCategoryIcon(category),
                      color: MedievalColors.goldBright,
                    ),
                    title: Text(
                      CategoryCatalog.placeLabel(category),
                      style: const TextStyle(
                        color: MedievalColors.parchmentLight,
                      ),
                    ),
                    subtitle: Text(
                      '${widget.categoryCounts[category]} punktów',
                      style: const TextStyle(
                        color: MedievalColors.parchmentDark,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _hidden.clear()),
                  child: const Text('Pokaż wszystkie'),
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    Set<String>.of(_hidden),
                  ),
                  child: const Text('Zastosuj'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GpsBadge extends StatelessWidget {
  const _GpsBadge({
    required this.accuracy,
    required this.calibrationCount,
  });

  final double accuracy;
  final int calibrationCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MedievalColors.charcoal.withValues(alpha: 0.92),
        border: Border.all(color: MedievalColors.gold, width: 1.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Text(
          'GPS ±${accuracy.round()} m'
          '${calibrationCount > 0 ? '  •  kotwice: $calibrationCount' : ''}',
          style: const TextStyle(
            color: MedievalColors.parchmentLight,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? MedievalColors.red.withValues(alpha: 0.96)
            : MedievalColors.charcoal.withValues(alpha: 0.94),
        shape: CircleBorder(
          side: BorderSide(
            color: active
                ? MedievalColors.goldBright
                : MedievalColors.gold,
            width: 1.5,
          ),
        ),
        elevation: 5,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: MedievalColors.goldBright),
          ),
        ),
      ),
    );
  }
}
