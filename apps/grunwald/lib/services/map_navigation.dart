import 'dart:math' as math;
import 'dart:ui';

class MapNavigationRoute {
  const MapNavigationRoute({
    required this.points,
    required this.estimatedMeters,
  });

  final List<Offset> points;
  final int estimatedMeters;
}

/// Orientacyjne prowadzenie po głównych drogach widocznych na planie obozu.
///
/// Mapa jest ilustracją, a nie ortofotomapą. Końce trasy są więc łączone z
/// najbliższą drogą, a odległość jest celowo zaokrąglana do 10 metrów.
class MapNavigation {
  const MapNavigation._();

  static const double _mapWidthMeters = 1080;
  static const double _mapHeightMeters = 1080;

  static const List<Offset> _nodes = <Offset>[
    Offset(0.025, 0.953), // 0: droga południowa — zachód
    Offset(0.285, 0.953), // 1: wejście na Drogę Jagiełły
    Offset(0.590, 0.953), // 2: wejście na Drogę von Jungingena
    Offset(0.705, 0.953), // 3: wejście na drogę wschodnią
    Offset(0.975, 0.953), // 4: droga południowa — wschód
    Offset(0.335, 0.830), // 5
    Offset(0.385, 0.710), // 6
    Offset(0.425, 0.575), // 7
    Offset(0.455, 0.455), // 8
    Offset(0.460, 0.360), // 9: północne rozwidlenie
    Offset(0.410, 0.235), // 10: łucznictwo
    Offset(0.355, 0.145), // 11: pole bitwy
    Offset(0.555, 0.435), // 12: skrzyżowanie centralne
    Offset(0.575, 0.565), // 13
    Offset(0.595, 0.755), // 14
    Offset(0.700, 0.445), // 15: skrzyżowanie przy Justycji
    Offset(0.705, 0.690), // 16
    Offset(0.820, 0.355), // 17: parking od Stębarka
  ];

  static const List<(int, int)> _edges = <(int, int)>[
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (1, 5),
    (5, 6),
    (6, 7),
    (7, 8),
    (8, 9),
    (9, 10),
    (10, 11),
    (9, 12),
    (2, 14),
    (14, 13),
    (13, 12),
    (3, 16),
    (16, 15),
    (15, 12),
    (15, 17),
    (6, 14),
    (7, 13),
    (13, 16),
  ];

  static MapNavigationRoute routeBetween(Offset start, Offset destination) {
    if (_metersBetween(start, destination) < 4) {
      return MapNavigationRoute(
        points: <Offset>[start, destination],
        estimatedMeters: _roundedMeters(_metersBetween(start, destination)),
      );
    }

    final startSnap = _nearestEdge(start);
    final destinationSnap = _nearestEdge(destination);
    final nodes = <Offset>[
      ..._nodes,
      startSnap.point,
      destinationSnap.point,
    ];
    final startIndex = _nodes.length;
    final destinationIndex = startIndex + 1;
    final adjacency = List<List<_Neighbor>>.generate(
      nodes.length,
      (_) => <_Neighbor>[],
    );

    for (final edge in _edges) {
      _connect(adjacency, nodes, edge.$1, edge.$2);
    }
    _connect(adjacency, nodes, startIndex, startSnap.edge.$1);
    _connect(adjacency, nodes, startIndex, startSnap.edge.$2);
    _connect(adjacency, nodes, destinationIndex, destinationSnap.edge.$1);
    _connect(adjacency, nodes, destinationIndex, destinationSnap.edge.$2);
    if (startSnap.edge == destinationSnap.edge) {
      _connect(adjacency, nodes, startIndex, destinationIndex);
    }

    final previous = _shortestPath(
      adjacency,
      startIndex,
      destinationIndex,
    );
    final indices = <int>[];
    var current = destinationIndex;
    indices.add(current);
    while (current != startIndex && previous[current] != -1) {
      current = previous[current];
      indices.add(current);
    }
    final points = <Offset>[start];
    for (final index in indices.reversed) {
      _addDistinct(points, nodes[index]);
    }
    _addDistinct(points, destination);

    var distance = 0.0;
    for (var index = 1; index < points.length; index++) {
      distance += _metersBetween(points[index - 1], points[index]);
    }
    return MapNavigationRoute(
      points: List<Offset>.unmodifiable(points),
      estimatedMeters: _roundedMeters(distance),
    );
  }

  static List<int> _shortestPath(
    List<List<_Neighbor>> adjacency,
    int start,
    int destination,
  ) {
    final distances = List<double>.filled(adjacency.length, double.infinity);
    final previous = List<int>.filled(adjacency.length, -1);
    final visited = List<bool>.filled(adjacency.length, false);
    distances[start] = 0;

    for (var step = 0; step < adjacency.length; step++) {
      var current = -1;
      var best = double.infinity;
      for (var index = 0; index < adjacency.length; index++) {
        if (!visited[index] && distances[index] < best) {
          current = index;
          best = distances[index];
        }
      }
      if (current == -1 || current == destination) break;
      visited[current] = true;
      for (final neighbor in adjacency[current]) {
        final candidate = distances[current] + neighbor.distance;
        if (candidate < distances[neighbor.index]) {
          distances[neighbor.index] = candidate;
          previous[neighbor.index] = current;
        }
      }
    }
    return previous;
  }

  static _EdgeSnap _nearestEdge(Offset point) {
    var best = _EdgeSnap(
      edge: _edges.first,
      point: _projectOnSegment(
        point,
        _nodes[_edges.first.$1],
        _nodes[_edges.first.$2],
      ),
      distance: double.infinity,
    );
    for (final edge in _edges) {
      final projected = _projectOnSegment(
        point,
        _nodes[edge.$1],
        _nodes[edge.$2],
      );
      final distance = _metersBetween(point, projected);
      if (distance < best.distance) {
        best = _EdgeSnap(edge: edge, point: projected, distance: distance);
      }
    }
    return best;
  }

  static Offset _projectOnSegment(Offset point, Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return start;
    final t = (((point.dx - start.dx) * dx +
                (point.dy - start.dy) * dy) /
            lengthSquared)
        .clamp(0.0, 1.0)
        .toDouble();
    return Offset(start.dx + dx * t, start.dy + dy * t);
  }

  static void _connect(
    List<List<_Neighbor>> adjacency,
    List<Offset> nodes,
    int first,
    int second,
  ) {
    final distance = _metersBetween(nodes[first], nodes[second]);
    adjacency[first].add(_Neighbor(second, distance));
    adjacency[second].add(_Neighbor(first, distance));
  }

  static void _addDistinct(List<Offset> points, Offset point) {
    if (points.isEmpty || _metersBetween(points.last, point) >= 1) {
      points.add(point);
    }
  }

  static double _metersBetween(Offset first, Offset second) {
    final east = (first.dx - second.dx) * _mapWidthMeters;
    final north = (first.dy - second.dy) * _mapHeightMeters;
    return math.sqrt(east * east + north * north);
  }

  static int _roundedMeters(double distance) {
    final rounded = (distance / 10).round() * 10;
    return rounded < 10 ? 10 : rounded;
  }
}

class _Neighbor {
  const _Neighbor(this.index, this.distance);

  final int index;
  final double distance;
}

class _EdgeSnap {
  const _EdgeSnap({
    required this.edge,
    required this.point,
    required this.distance,
  });

  final (int, int) edge;
  final Offset point;
  final double distance;
}
