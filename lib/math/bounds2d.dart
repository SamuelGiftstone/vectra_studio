import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'vec2.dart';

/// Immutable 2D axis-aligned bounding box in document or viewport coordinates.
class Bounds2D {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  const Bounds2D({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  static const Bounds2D zero = Bounds2D(
    minX: 0,
    minY: 0,
    maxX: 0,
    maxY: 0,
  );

  factory Bounds2D.fromLTWH(
    double left,
    double top,
    double width,
    double height,
  ) {
    final x2 = left + width;
    final y2 = top + height;
    return Bounds2D(
      minX: math.min(left, x2),
      minY: math.min(top, y2),
      maxX: math.max(left, x2),
      maxY: math.max(top, y2),
    );
  }

  factory Bounds2D.fromPoints(Iterable<Vec2> points) {
    final iterator = points.iterator;
    if (!iterator.moveNext()) {
      return Bounds2D.zero;
    }
    var minX = iterator.current.x;
    var minY = iterator.current.y;
    var maxX = minX;
    var maxY = minY;
    while (iterator.moveNext()) {
      final p = iterator.current;
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
    return Bounds2D(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }

  double get left => minX;
  double get top => minY;
  double get right => maxX;
  double get bottom => maxY;
  double get width => math.max(0.0, maxX - minX);
  double get height => math.max(0.0, maxY - minY);

  Vec2 get topLeft => Vec2(minX, minY);
  Vec2 get topRight => Vec2(maxX, minY);
  Vec2 get bottomLeft => Vec2(minX, maxY);
  Vec2 get bottomRight => Vec2(maxX, maxY);
  Vec2 get center => Vec2((minX + maxX) * 0.5, (minY + maxY) * 0.5);

  List<Vec2> get corners => <Vec2>[topLeft, topRight, bottomRight, bottomLeft];

  bool get isEmpty => width <= 1e-9 && height <= 1e-9;

  bool containsPoint(Vec2 p, {double tolerance = 0.0}) {
    return p.x >= minX - tolerance &&
        p.x <= maxX + tolerance &&
        p.y >= minY - tolerance &&
        p.y <= maxY + tolerance;
  }

  bool intersects(Bounds2D other) {
    return maxX >= other.minX &&
        minX <= other.maxX &&
        maxY >= other.minY &&
        minY <= other.maxY;
  }

  Bounds2D inflate(double delta) {
    return Bounds2D(
      minX: minX - delta,
      minY: minY - delta,
      maxX: maxX + delta,
      maxY: maxY + delta,
    );
  }

  Bounds2D translate(Vec2 delta) {
    return Bounds2D(
      minX: minX + delta.x,
      minY: minY + delta.y,
      maxX: maxX + delta.x,
      maxY: maxY + delta.y,
    );
  }

  Bounds2D union(Bounds2D other) {
    return Bounds2D(
      minX: math.min(minX, other.minX),
      minY: math.min(minY, other.minY),
      maxX: math.max(maxX, other.maxX),
      maxY: math.max(maxY, other.maxY),
    );
  }

  Rect toRect() => Rect.fromLTRB(minX, minY, maxX, maxY);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bounds2D &&
          other.minX == minX &&
          other.minY == minY &&
          other.maxX == maxX &&
          other.maxY == maxY);

  @override
  int get hashCode => Object.hash(minX, minY, maxX, maxY);

  @override
  String toString() =>
      'Bounds2D(${minX.toStringAsFixed(1)}, ${minY.toStringAsFixed(1)} -> ${maxX.toStringAsFixed(1)}, ${maxY.toStringAsFixed(1)})';
}
