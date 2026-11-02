import 'dart:math' as math;

import 'bounds2d.dart';
import 'geometry_math.dart';
import 'vec2.dart';

/// Represents a cubic Bézier curve defined by start [p0], control points [p1], [p2], and end [p3].
class CubicSegment {
  final Vec2 p0;
  final Vec2 p1;
  final Vec2 p2;
  final Vec2 p3;

  const CubicSegment(this.p0, this.p1, this.p2, this.p3);

  bool get isLinear =>
      p1.closeTo(p0, 1e-6) && p2.closeTo(p3, 1e-6);
}

/// Pair of left and right cubic segments produced by De Casteljau subdivision.
class CubicSplitResult {
  final CubicSegment left;
  final CubicSegment right;

  const CubicSplitResult({required this.left, required this.right});
}

/// Mathematical operations for cubic Bézier curves.
class BezierMath {
  BezierMath._();

  /// Evaluates cubic Bézier `B(t)` at parameter `t` in `[0, 1]`.
  static Vec2 evaluateCubic(
    Vec2 p0,
    Vec2 p1,
    Vec2 p2,
    Vec2 p3,
    double t,
  ) {
    final u = 1.0 - t;
    final tt = t * t;
    final uu = u * u;
    final uuu = uu * u;
    final ttt = tt * t;

    final x = uuu * p0.x +
        3.0 * uu * t * p1.x +
        3.0 * u * tt * p2.x +
        ttt * p3.x;
    final y = uuu * p0.y +
        3.0 * uu * t * p1.y +
        3.0 * u * tt * p2.y +
        ttt * p3.y;
    return Vec2(x, y);
  }

  /// Evaluates the first derivative `B'(t)` (tangent vector) at parameter `t`.
  static Vec2 cubicTangent(
    Vec2 p0,
    Vec2 p1,
    Vec2 p2,
    Vec2 p3,
    double t,
  ) {
    final u = 1.0 - t;
    final d0 = p1 - p0;
    final d1 = p2 - p1;
    final d2 = p3 - p2;

    return (d0 * (3.0 * u * u)) +
        (d1 * (6.0 * u * t)) +
        (d2 * (3.0 * t * t));
  }

  /// Evaluates the unit tangent vector along the cubic Bézier at `t`.
  static Vec2 cubicUnitTangent(
    Vec2 p0,
    Vec2 p1,
    Vec2 p2,
    Vec2 p3,
    double t,
  ) {
    return cubicTangent(p0, p1, p2, p3, t).normalized;
  }

  /// Samples [steps] + 1 points evenly in parameter `t` from `0.0` to `1.0`.
  static List<Vec2> sampleCubic(
    Vec2 p0,
    Vec2 p1,
    Vec2 p2,
    Vec2 p3, {
    int steps = 24,
  }) {
    final count = math.max(2, steps);
    final points = <Vec2>[];
    for (var i = 0; i <= count; i++) {
      final t = i / count;
      points.add(evaluateCubic(p0, p1, p2, p3, t));
    }
    return points;
  }

  /// Estimates the arc length of a cubic Bézier curve using polyline chord summation.
  static double estimateLength(
    Vec2 p0,
    Vec2 p1,
    Vec2 p2,
    Vec2 p3, {
    int steps = 32,
  }) {
    final samples = sampleCubic(p0, p1, p2, p3, steps: steps);
    var total = 0.0;
    for (var i = 1; i < samples.length; i++) {
      total += samples[i - 1].distanceTo(samples[i]);
    }
    return total;
  }

  /// Splits a cubic Bézier curve at parameter `t` (`0 <= t <= 1`) using De Casteljau's algorithm.
  static CubicSplitResult splitCubic(
    Vec2 p0,
    Vec2 p1,
    Vec2 p2,
    Vec2 p3,
    double t,
  ) {
    final clampedT = t.clamp(0.0, 1.0);
    final q0 = p0.lerp(p1, clampedT);
    final q1 = p1.lerp(p2, clampedT);
    final q2 = p2.lerp(p3, clampedT);

    final r0 = q0.lerp(q1, clampedT);
    final r1 = q1.lerp(q2, clampedT);

    final s = r0.lerp(r1, clampedT);

    return CubicSplitResult(
      left: CubicSegment(p0, q0, r0, s),
      right: CubicSegment(s, r1, q2, p3),
    );
  }

  /// Computes the exact analytical tight axis-aligned bounding box of a cubic Bézier curve
  /// by solving `B'(t) = 0` in both X and Y dimensions.
  static Bounds2D cubicBounds(
    Vec2 p0,
    Vec2 p1,
    Vec2 p2,
    Vec2 p3,
  ) {
    final candidatePoints = <Vec2>[p0, p3];

    for (final root in _derivativeRoots1D(p0.x, p1.x, p2.x, p3.x)) {
      if (root > 0.0 && root < 1.0) {
        candidatePoints.add(evaluateCubic(p0, p1, p2, p3, root));
      }
    }
    for (final root in _derivativeRoots1D(p0.y, p1.y, p2.y, p3.y)) {
      if (root > 0.0 && root < 1.0) {
        candidatePoints.add(evaluateCubic(p0, p1, p2, p3, root));
      }
    }

    return Bounds2D.fromPoints(candidatePoints);
  }

  /// Solves `3a t^2 + 2b t + c = 0` for a 1D cubic Bézier component.
  static List<double> _derivativeRoots1D(
    double v0,
    double v1,
    double v2,
    double v3,
  ) {
    final a = 3.0 * (-v0 + 3.0 * v1 - 3.0 * v2 + v3);
    final b = 6.0 * (v0 - 2.0 * v1 + v2);
    final c = 3.0 * (v1 - v0);

    final roots = <double>[];
    if (a.abs() < 1e-12) {
      if (b.abs() > 1e-12) {
        final t = -c / b;
        if (t > 0.0 && t < 1.0) roots.add(t);
      }
      return roots;
    }

    final discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0) {
      return roots;
    }
    if (discriminant.abs() < 1e-12) {
      final t = -b / (2.0 * a);
      if (t > 0.0 && t < 1.0) roots.add(t);
      return roots;
    }

    final sqrtD = math.sqrt(discriminant);
    final t1 = (-b + sqrtD) / (2.0 * a);
    final t2 = (-b - sqrtD) / (2.0 * a);
    if (t1 > 0.0 && t1 < 1.0) roots.add(t1);
    if (t2 > 0.0 && t2 < 1.0) roots.add(t2);
    return roots;
  }

  /// Computes approximate minimum distance from [point] to a cubic Bézier segment.
  static double distanceToCubic(
    Vec2 point,
    Vec2 p0,
    Vec2 p1,
    Vec2 p2,
    Vec2 p3, {
    int samples = 28,
  }) {
    final pts = sampleCubic(p0, p1, p2, p3, steps: samples);
    var minDistance = double.infinity;
    for (var i = 1; i < pts.length; i++) {
      final d = GeometryMath.distanceToSegment(point, pts[i - 1], pts[i]);
      if (d < minDistance) {
        minDistance = d;
      }
    }
    return minDistance;
  }

  /// Finds the approximate parameter `t` (`0..1`) closest to [point] along the cubic segment.
  static double closestParameterOnCubic(
    Vec2 point,
    Vec2 p0,
    Vec2 p1,
    Vec2 p2,
    Vec2 p3, {
    int samples = 40,
  }) {
    var bestT = 0.0;
    var bestDistSq = double.infinity;
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final candidate = evaluateCubic(p0, p1, p2, p3, t);
      final dSq = point.distanceSquaredTo(candidate);
      if (dSq < bestDistSq) {
        bestDistSq = dSq;
        bestT = t;
      }
    }
    return bestT;
  }
}
