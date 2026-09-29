import 'dart:math' as math;
import 'dart:ui';

import '../models/calibration_anchor.dart';

/// Geodezyjne dopasowanie GPS do stylizowanego planu obozów.
///
/// Plan nie jest ortofotomapą i ma lokalne zniekształcenia. Dlatego stosujemy:
/// 1. globalną transformację afiniczną w lokalnym układzie metrycznym,
/// 2. lokalną korektę resztową ważoną odległością,
/// 3. dodatkowe kotwice terenowe zapisane przez użytkownika.
class MapCalibration {
  const MapCalibration._();

  static const List<CalibrationAnchor> defaultAnchors = <CalibrationAnchor>[
    CalibrationAnchor(
      id: 'pomnik',
      name: 'Kompleks pomnikowy',
      latitude: 53.487082,
      longitude: 20.123504,
      mapX: 0.6510417,
      mapY: 0.0878906,
    ),
    CalibrationAnchor(
      id: 'stare_muzeum',
      name: 'Stare muzeum',
      latitude: 53.4858556,
      longitude: 20.1250369,
      mapX: 0.5240885,
      mapY: 0.2636719,
    ),
    CalibrationAnchor(
      id: 'skrzyzowanie_justycja',
      name: 'Skrzyżowanie przy Justycji',
      latitude: 53.4860987,
      longitude: 20.1259698,
      mapX: 0.7578125,
      mapY: 0.4394531,
    ),
    CalibrationAnchor(
      id: 'parkur',
      name: 'Parkur',
      latitude: 53.4855012,
      longitude: 20.1275553,
      mapX: 0.4804688,
      mapY: 0.5898438,
    ),
    CalibrationAnchor(
      id: 'sanitariaty_locus_2026_07_17',
      name: 'Sanitariaty — punkt terenowy Locus',
      latitude: 53.4866200,
      longitude: 20.1251800,
      mapX: 0.7421875,
      mapY: 0.8740234,
      fieldMeasured: true,
    ),
    CalibrationAnchor(
      id: 'dolne_skrzyzowanie',
      name: 'Skrzyżowanie Jagiełły i von Raunungena',
      latitude: 53.4841735,
      longitude: 20.1285470,
      mapX: 0.6757813,
      mapY: 0.9375,
    ),
  ];

  static Offset? gpsToMap(
    double latitude,
    double longitude, {
    List<CalibrationAnchor> fieldAnchors = const <CalibrationAnchor>[],
  }) {
    if (latitude < 53.4815 || latitude > 53.4915 ||
        longitude < 20.1160 || longitude > 20.1325) {
      return null;
    }

    final anchors = <CalibrationAnchor>[
      ...defaultAnchors,
      ...fieldAnchors,
    ];
    if (anchors.length < 3) return null;

    // Stabilny model bazowy liczymy wyłącznie z kotwic stałych.
    // Punkty terenowe nie mogą przesunąć całej mapy — korygują ją lokalnie.
    final stableAnchors = anchors
        .where((anchor) => !anchor.fieldMeasured)
        .toList(growable: false);
    final fitAnchors =
        stableAnchors.length >= 3 ? stableAnchors : anchors;

    final projection = _LocalProjection.fromAnchors(anchors);
    final fittedX =
        _fitAffine(fitAnchors, projection, (anchor) => anchor.mapX);
    final fittedY =
        _fitAffine(fitAnchors, projection, (anchor) => anchor.mapY);
    if (fittedX == null || fittedY == null) return null;

    final point = projection.toMeters(latitude, longitude);
    var x = fittedX.evaluate(point.$1, point.$2);
    var y = fittedY.evaluate(point.$1, point.$2);

    final candidates = anchors
        .map((anchor) {
          final meters = projection.toMeters(anchor.latitude, anchor.longitude);
          final distance = math.sqrt(
            math.pow(point.$1 - meters.$1, 2) +
                math.pow(point.$2 - meters.$2, 2),
          );
          return (anchor: anchor, distance: distance, meters: meters);
        })
        .toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    final nearest = candidates.take(math.min(6, candidates.length));
    var weightSum = 0.0;
    var residualX = 0.0;
    var residualY = 0.0;

    for (final item in nearest) {
      if (item.distance <= 3.0) {
        return Offset(item.anchor.mapX, item.anchor.mapY);
      }
      if (item.anchor.fieldMeasured && item.distance > 350.0) {
        continue;
      }
      final baseWeight = item.anchor.fieldMeasured ? 32.0 : 1.0;
      final safeDistance = math.max(item.distance, 6.0);
      final weight = baseWeight / (safeDistance * safeDistance);
      final predictedAnchorX = fittedX.evaluate(item.meters.$1, item.meters.$2);
      final predictedAnchorY = fittedY.evaluate(item.meters.$1, item.meters.$2);
      residualX += weight * (item.anchor.mapX - predictedAnchorX);
      residualY += weight * (item.anchor.mapY - predictedAnchorY);
      weightSum += weight;
    }

    if (weightSum > 0) {
      x += residualX / weightSum;
      y += residualY / weightSum;
    }

    if (x < -0.12 || x > 1.12 || y < -0.12 || y > 1.12) return null;
    return Offset(
      x.clamp(0.0, 1.0).toDouble(),
      y.clamp(0.0, 1.0).toDouble(),
    );
  }

  static _Affine? _fitAffine(
    List<CalibrationAnchor> anchors,
    _LocalProjection projection,
    double Function(CalibrationAnchor anchor) target,
  ) {
    final matrix = List<List<double>>.generate(
      3,
      (_) => List<double>.filled(3, 0),
    );
    final vector = List<double>.filled(3, 0);

    for (final anchor in anchors) {
      final meters = projection.toMeters(anchor.latitude, anchor.longitude);
      final row = <double>[1, meters.$1, meters.$2];
      final anchorWeight = 1.0;
      for (var i = 0; i < 3; i++) {
        vector[i] += anchorWeight * row[i] * target(anchor);
        for (var j = 0; j < 3; j++) {
          matrix[i][j] += anchorWeight * row[i] * row[j];
        }
      }
    }

    final result = _solve3x3(matrix, vector);
    return result == null ? null : _Affine(result[0], result[1], result[2]);
  }

  static List<double>? _solve3x3(
    List<List<double>> matrix,
    List<double> vector,
  ) {
    final augmented = List<List<double>>.generate(
      3,
      (row) => <double>[...matrix[row], vector[row]],
    );

    for (var column = 0; column < 3; column++) {
      var pivot = column;
      for (var row = column + 1; row < 3; row++) {
        if (augmented[row][column].abs() > augmented[pivot][column].abs()) {
          pivot = row;
        }
      }
      if (augmented[pivot][column].abs() < 1e-12) return null;
      final temporary = augmented[column];
      augmented[column] = augmented[pivot];
      augmented[pivot] = temporary;

      final divisor = augmented[column][column];
      for (var item = column; item < 4; item++) {
        augmented[column][item] /= divisor;
      }

      for (var row = 0; row < 3; row++) {
        if (row == column) continue;
        final factor = augmented[row][column];
        for (var item = column; item < 4; item++) {
          augmented[row][item] -= factor * augmented[column][item];
        }
      }
    }

    return <double>[
      augmented[0][3],
      augmented[1][3],
      augmented[2][3],
    ];
  }
}

class _Affine {
  const _Affine(this.offset, this.eastFactor, this.northFactor);

  final double offset;
  final double eastFactor;
  final double northFactor;

  double evaluate(double east, double north) =>
      offset + eastFactor * east + northFactor * north;
}

class _LocalProjection {
  const _LocalProjection(this.referenceLatitude, this.referenceLongitude);

  factory _LocalProjection.fromAnchors(List<CalibrationAnchor> anchors) {
    final latitude = anchors
            .map((anchor) => anchor.latitude)
            .reduce((a, b) => a + b) /
        anchors.length;
    final longitude = anchors
            .map((anchor) => anchor.longitude)
            .reduce((a, b) => a + b) /
        anchors.length;
    return _LocalProjection(latitude, longitude);
  }

  final double referenceLatitude;
  final double referenceLongitude;

  (double, double) toMeters(double latitude, double longitude) {
    final latitudeRadians = referenceLatitude * math.pi / 180;
    final east = (longitude - referenceLongitude) *
        111320.0 *
        math.cos(latitudeRadians);
    final north = (latitude - referenceLatitude) * 110540.0;
    return (east, north);
  }
}
