import 'dart:math' as math;

import '../math/bounds2d.dart';
import '../math/vec2.dart';
import 'vector_object.dart';

/// Shared base class for box-bounded geometric shapes (Rectangle, Ellipse, Polygon, Star).
abstract class BoundedShapeObject extends VectorObject {
  final double x;
  final double y;
  final double width;
  final double height;

  const BoundedShapeObject({
    required super.id,
    required super.name,
    required super.type,
    required super.layerId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required super.fill,
    required super.stroke,
    super.opacity,
    super.visible,
    super.locked,
    super.rotation,
  });

  @override
  Bounds2D get localBounds => Bounds2D(
        minX: x,
        minY: y,
        maxX: x + math.max(0.0, width),
        maxY: y + math.max(0.0, height),
      );

  Map<String, dynamic> boundedFieldsToJson() => <String, dynamic>{
        ...baseFieldsToJson(),
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  @override
  VectorObject translate(Vec2 delta) =>
      resizeLocalBounds(localBounds.translate(delta));
}
