import 'package:flutter_test/flutter_test.dart';
import 'package:grunwald_navigator/services/map_navigation.dart';

void main() {
  test('trasa zaczyna i kończy się w wybranych punktach', () {
    const start = Offset(0.08, 0.76);
    const destination = Offset(0.87, 0.45);

    final route = MapNavigation.routeBetween(start, destination);

    expect(route.points.first, start);
    expect(route.points.last, destination);
    expect(route.points.length, greaterThan(4));
    expect(route.estimatedMeters, greaterThan(0));
  });

  test('cała trasa pozostaje w granicach planu', () {
    final route = MapNavigation.routeBetween(
      const Offset(0.10, 0.52),
      const Offset(0.43, 0.10),
    );

    for (final point in route.points) {
      expect(point.dx, inInclusiveRange(0.0, 1.0));
      expect(point.dy, inInclusiveRange(0.0, 1.0));
    }
  });

  test('bardzo bliski cel daje krótką trasę', () {
    final route = MapNavigation.routeBetween(
      const Offset(0.50, 0.50),
      const Offset(0.501, 0.501),
    );

    expect(route.points, hasLength(2));
    expect(route.estimatedMeters, 10);
  });
}
