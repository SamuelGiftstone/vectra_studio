import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Immutable 2D vector and point in document or viewport space.
class Vec2 {
  final double x;
  final double y;

  const Vec2(this.x, this.y);

  static const Vec2 zero = Vec2(0.0, 0.0);

  factory Vec2.fromOffset(Offset offset) => Vec2(offset.dx, offset.dy);

  factory Vec2.fromJson(Map<String, dynamic> json) {
    final rawX = json['x'];
    final rawY = json['y'];
    if (rawX is! num || rawY is! num) {
      throw const FormatException('Vec2 JSON requires numeric x and y.');
    }
    return Vec2(rawX.toDouble(), rawY.toDouble());
  }

  Map<String, dynamic> toJson() => <String, dynamic>{'x': x, 'y': y};

  Offset toOffset() => Offset(x, y);

  bool get isFinite => !x.isNaN && !x.isInfinite && !y.isNaN && !y.isInfinite;

  bool get isZero => x.abs() < 1e-9 && y.abs() < 1e-9;

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);

  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);

  Vec2 operator -() => Vec2(-x, -y);

  Vec2 operator *(double scalar) => Vec2(x * scalar, y * scalar);

  Vec2 operator /(double scalar) {
    if (scalar.abs() < 1e-12) return Vec2.zero;
    return Vec2(x / scalar, y / scalar);
  }

  double dot(Vec2 other) => x * other.x + y * other.y;

  double cross(Vec2 other) => x * other.y - y * other.x;

  double get lengthSquared => x * x + y * y;

  double get length => math.sqrt(lengthSquared);

  Vec2 get normalized {
    final len = length;
    if (len < 1e-12) return Vec2.zero;
    return Vec2(x / len, y / len);
  }

  double distanceTo(Vec2 other) => (this - other).length;

  double distanceSquaredTo(Vec2 other) => (this - other).lengthSquared;

  Vec2 lerp(Vec2 target, double t) =>
      Vec2(x + (target.x - x) * t, y + (target.y - y) * t);

  Vec2 rotate(double radians) {
    if (radians.abs() < 1e-12) return this;
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Vec2(x * c - y * s, x * s + y * c);
  }

  Vec2 rotateAround(Vec2 pivot, double radians) {
    if (radians.abs() < 1e-12) return this;
    return (this - pivot).rotate(radians) + pivot;
  }

  Vec2 scaleFrom(Vec2 origin, double sx, double sy) {
    return Vec2(
      origin.x + (x - origin.x) * sx,
      origin.y + (y - origin.y) * sy,
    );
  }

  bool closeTo(Vec2 other, [double epsilon = 1e-6]) =>
      (x - other.x).abs() <= epsilon && (y - other.y).abs() <= epsilon;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Vec2 && other.x == x && other.y == y);

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}
