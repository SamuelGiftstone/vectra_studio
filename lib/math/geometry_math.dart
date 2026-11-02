import 'dart:math' as math;

import 'bounds2d.dart';
import 'vec2.dart';

/// Pure analytic geometry functions independent of Flutter widgets.
class GeometryMath {
  GeometryMath._();

  static Vec2 add(Vec2 a, Vec2 b) => a + b;

  static Vec2 subtract(Vec2 a, Vec2 b) => a - b;

  static Vec2 scale(Vec2 v, double factor) => v * factor;

  static double dot(Vec2 a, Vec2 b) => a.dot(b);

  static double length(Vec2 v) => v.length;

  static double distance(Vec2 a, Vec2 b) => a.distanceTo(b);

  static Vec2 lerp(Vec2 a, Vec2 b, double t) => a.lerp(b, t);

  static Vec2 rotatePoint(Vec2 point, Vec2 pivot, double radians) =>
      point.rotateAround(pivot, radians);

  static double degreesToRadians(double degrees) => degrees * (math.pi / 180.0);

  static double radiansToDegrees(double radians) => radians * (180.0 / math.pi);

  /// Normalizes an angle in radians to `[-pi, pi]`.
  static double normalizeRadians(double radians) {
    var angle = radians % (2 * math.pi);
    if (angle > math.pi) {
      angle -= 2 * math.pi;
    } else if (angle < -math.pi) {
      angle += 2 * math.pi;
    }
    return angle;
  }

  /// Snaps an angle in radians to increments of [stepDegrees] (e.g., 15° or 45°).
  static double snapAngleRadians(double radians, {double stepDegrees = 15.0}) {
    final stepRad = degreesToRadians(stepDegrees);
    if (stepRad <= 1e-9) return radians;
    return (radians / stepRad).round() * stepRad;
  }

  /// Computes the axis-aligned bounding box of a rotated local [Bounds2D].
  static Bounds2D rotatedBounds(Bounds2D localBounds, double rotationRadians) {
    if (rotationRadians.abs() < 1e-9) {
      return localBounds;
    }
    final pivot = localBounds.center;
    final rotatedCorners = localBounds.corners
        .map((c) => c.rotateAround(pivot, rotationRadians))
        .toList();
    return Bounds2D.fromPoints(rotatedCorners);
  }

  /// Tests whether [point] lies inside an axis-aligned rectangle `[left, top, width, height]`.
  static bool isPointInRect(
    Vec2 point, {
    required double left,
    required double top,
    required double width,
    required double height,
    double cornerRadius = 0.0,
  }) {
    final bounds = Bounds2D.fromLTWH(left, top, width, height);
    if (!bounds.containsPoint(point)) {
      return false;
    }
    final r = cornerRadius.clamp(0.0, math.min(bounds.width, bounds.height) * 0.5);
    if (r <= 1e-6) {
      return true;
    }

    // Check rounded corner quadrants
    final innerMinX = bounds.minX + r;
    final innerMaxX = bounds.maxX - r;
    final innerMinY = bounds.minY + r;
    final innerMaxY = bounds.maxY - r;

    double? cx;
    double? cy;
    if (point.x < innerMinX && point.y < innerMinY) {
      cx = innerMinX;
      cy = innerMinY;
    } else if (point.x > innerMaxX && point.y < innerMinY) {
      cx = innerMaxX;
      cy = innerMinY;
    } else if (point.x > innerMaxX && point.y > innerMaxY) {
      cx = innerMaxX;
      cy = innerMaxY;
    } else if (point.x < innerMinX && point.y > innerMaxY) {
      cx = innerMinX;
      cy = innerMaxY;
    }

    if (cx != null && cy != null) {
      final dx = point.x - cx;
      final dy = point.y - cy;
      return (dx * dx + dy * dy) <= (r * r);
    }
    return true;
  }

  /// Tests whether [point] lies inside an axis-aligned ellipse centered at [center]
  /// with horizontal semi-axis [rx] and vertical semi-axis [ry].
  static bool isPointInEllipse(
    Vec2 point, {
    required Vec2 center,
    required double rx,
    required double ry,
  }) {
    if (rx <= 1e-9 || ry <= 1e-9) return false;
    final nx = (point.x - center.x) / rx;
    final ny = (point.y - center.y) / ry;
    return (nx * nx + ny * ny) <= 1.0;
  }

  /// Computes the closest point on line segment `[a, b]` to [point].
  static Vec2 closestPointOnSegment(Vec2 point, Vec2 a, Vec2 b) {
    final ab = b - a;
    final lenSq = ab.lengthSquared;
    if (lenSq < 1e-12) {
      return a;
    }
    final t = ((point - a).dot(ab) / lenSq).clamp(0.0, 1.0);
    return a + ab * t;
  }

  /// Shortest Euclidean distance from [point] to line segment `[a, b]`.
  static double distanceToSegment(Vec2 point, Vec2 a, Vec2 b) {
    return point.distanceTo(closestPointOnSegment(point, a, b));
  }

  /// Returns `true` when [point] is within [tolerance] of segment `[a, b]`.
  static bool hitTestSegment(
    Vec2 point,
    Vec2 a,
    Vec2 b, {
    required double tolerance,
  }) {
    return distanceToSegment(point, a, b) <= tolerance;
  }

  /// Validates that dimensions and coordinates are finite and usable.
  static bool isValidBounds(Bounds2D bounds) {
    return !bounds.minX.isNaN &&
        !bounds.minX.isInfinite &&
        !bounds.minY.isNaN &&
        !bounds.minY.isInfinite &&
        !bounds.maxX.isNaN &&
        !bounds.maxX.isInfinite &&
        !bounds.maxY.isNaN &&
        !bounds.maxY.isInfinite &&
        bounds.maxX >= bounds.minX &&
        bounds.maxY >= bounds.minY;
  }
}
