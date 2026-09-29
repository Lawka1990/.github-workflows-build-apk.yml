import 'package:flutter_test/flutter_test.dart';
import 'package:grunwald_navigator/models/calibration_anchor.dart';
import 'package:grunwald_navigator/services/map_calibration.dart';

void main() {
  test('kotwica kompleksu pomnikowego trafia w mapę', () {
    final point = MapCalibration.gpsToMap(53.487082, 20.123504);
    expect(point, isNotNull);
    expect(point!.dx, closeTo(0.6510417, 0.0001));
    expect(point.dy, closeTo(0.0878906, 0.0001));
  });

  test('terenowa kotwica Gończej ma pierwszeństwo lokalne', () {
    const anchor = CalibrationAnchor(
      id: 'field_oboz_goncza',
      name: 'Chorągiew Gończa',
      latitude: 53.4852,
      longitude: 20.1281,
      mapX: 0.61,
      mapY: 0.69,
      fieldMeasured: true,
    );
    final point = MapCalibration.gpsToMap(
      anchor.latitude,
      anchor.longitude,
      fieldAnchors: const <CalibrationAnchor>[anchor],
    );
    expect(point, isNotNull);
    expect(point!.dx, closeTo(anchor.mapX, 0.0001));
    expect(point.dy, closeTo(anchor.mapY, 0.0001));
  });


  test('terenowy punkt sanitariatów trafia dokładnie w wejście na mapie', () {
    final point = MapCalibration.gpsToMap(53.4866200, 20.1251800);
    expect(point, isNotNull);
    expect(point!.dx, closeTo(0.7421875, 0.0001));
    expect(point.dy, closeTo(0.8740234, 0.0001));
  });

  test('punkt daleko od Grunwaldu jest odrzucany', () {
    expect(MapCalibration.gpsToMap(54.0, 21.0), isNull);
  });
}
