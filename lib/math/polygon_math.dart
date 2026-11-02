import 'dart:math' as math;

import 'bounds2d.dart';
import 'geometry_math.dart';
import 'vec2.dart';

/// Polygon and star vertex generation plus ray-casting hit-testing routines.
class PolygonMath {
  PolygonMath._();

  /// Generates vertices of a regular [sides]-gon inscribed within [bounds],
  /// starting with the top apex pointing upward (`-pi / 2`).
  static List<Vec2> generatePolygonVertices(Bounds2D bounds, int sides) {
    final clampedSides = sides.clamp(3, 64);
    final center = bounds.center;
    final rx = bounds.width * 0.5;
    final ry = bounds.height * 0.5;

    final vertices = <Vec2>[];
    final angleStep = (2.0 * math.pi) / clampedSides;
    const startAngle = -math.pi / 2.0;

    for (var i = 0; i < clampedSides; i++) {
      final angle = startAngle + i * angleStep;
      vertices.add(
        Vec2(
          center.x + rx * math.cos(angle),
          center.y + ry * math.sin(angle),
        ),
      );
    }
    return vertices;
  }

  /// Generates alternating outer/inner vertices of a [points]-pointed star
  /// inscribed within [bounds].
  static List<Vec2> generateStarVertices(
    Bounds2D bounds, {
    required int points,
    required double innerRadiusRatio,
  }) {
    final clampedPoints = points.clamp(3, 64);
    final clampedRatio = innerRadiusRatio.clamp(0.08, 0.95);
    final center = bounds.center;
    final outerRx = bounds.width * 0.5;
    final outerRy = bounds.height * 0.5;
    final innerRx = outerRx * clampedRatio;
    final innerRy = outerRy * clampedRatio;

    final totalVertices = clampedPoints * 2;
    final angleStep = math.pi / clampedPoints;
    const startAngle = -math.pi / 2.0;

    final vertices = <Vec2>[];
    for (var i = 0; i < totalVertices; i++) {
      final angle = startAngle + i * angleStep;
      final isOuter = i.isEven;
      final rx = isOuter ? outerRx : innerRx;
      final ry = isOuter ? outerRy : innerRy;
      vertices.add(
        Vec2(
          center.x + rx * math.cos(angle),
          center.y + ry * math.sin(angle),
        ),
      );
    }
    return vertices;
  }

  /// Even-odd ray-casting point-in-polygon test.
  static bool isPointInPolygon(Vec2 point, List<Vec2> polygon) {
    if (polygon.length < 3) return false;
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].x;
      final yi = polygon[i].y;
      final xj = polygon[j].x;
      final yj = polygon[j].y;

      final intersects = ((yi > point.y) != (yj > point.y)) &&
          (point.x <
              (xj - xi) * (point.y - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) +
                  xi);
      if (intersects) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Minimum distance from [point] to the edges of a polyline or closed polygon.
  static double distanceToPolyline(
    Vec2 point,
    List<Vec2> vertices, {
    required bool closed,
  }) {
    if (vertices.isEmpty) return double.infinity;
    if (vertices.length == 1) return point.distanceTo(vertices.first);

    var minDist = double.infinity;
    for (var i = 1; i < vertices.length; i++) {
      final d = GeometryMath.distanceToSegment(point, vertices[i - 1], vertices[i]);
      if (d < minDist) minDist = d;
    }
    if (closed && vertices.length >= 2) {
      final d = GeometryMath.distanceToSegment(point, vertices.last, vertices.first);
      if (d < minDist) minDist = d;
    }
    return minDist;
  }
}
