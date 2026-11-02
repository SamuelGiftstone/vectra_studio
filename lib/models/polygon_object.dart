import 'dart:math' as math;

import '../core/constants/editor_constants.dart';
import '../core/utils/validation_utils.dart';
import '../math/bounds2d.dart';
import '../math/polygon_math.dart';
import '../math/vec2.dart';
import 'fill_style.dart';
import 'shape_object.dart';
import 'stroke_style.dart';
import 'vector_object.dart';

/// Editable regular polygon vector object with configurable [sides].
class PolygonObject extends BoundedShapeObject {
  final int sides;

  const PolygonObject({
    required super.id,
    required super.name,
    required super.layerId,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.fill,
    required super.stroke,
    this.sides = EditorConstants.defaultPolygonSides,
    super.opacity,
    super.visible,
    super.locked,
    super.rotation,
  }) : super(type: VectorObjectType.polygon);

  List<Vec2> get localVertices =>
      PolygonMath.generatePolygonVertices(localBounds, sides);

  PolygonObject copyWith({
    String? id,
    String? name,
    String? layerId,
    double? x,
    double? y,
    double? width,
    double? height,
    FillStyle? fill,
    StrokeStyle? stroke,
    int? sides,
    double? opacity,
    bool? visible,
    bool? locked,
    double? rotation,
  }) {
    return PolygonObject(
      id: id ?? this.id,
      name: name ?? this.name,
      layerId: layerId ?? this.layerId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: math.max(1.0, width ?? this.width),
      height: math.max(1.0, height ?? this.height),
      fill: fill ?? this.fill,
      stroke: stroke ?? this.stroke,
      sides: ValidationUtils.clampInt(
        sides ?? this.sides,
        EditorConstants.minPolygonSides,
        EditorConstants.maxPolygonSides,
      ),
      opacity: ValidationUtils.clampDouble(opacity ?? this.opacity, 0.0, 1.0),
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  PolygonObject resizeLocalBounds(Bounds2D newBounds) {
    return copyWith(
      x: newBounds.left,
      y: newBounds.top,
      width: math.max(1.0, newBounds.width),
      height: math.max(1.0, newBounds.height),
    );
  }

  @override
  PolygonObject withRotation(double newRotationRadians) =>
      copyWith(rotation: newRotationRadians);

  @override
  PolygonObject withFill(FillStyle newFill) => copyWith(fill: newFill);

  @override
  PolygonObject withStroke(StrokeStyle newStroke) => copyWith(stroke: newStroke);

  @override
  PolygonObject withOpacity(double newOpacity) => copyWith(opacity: newOpacity);

  @override
  PolygonObject withName(String newName) => copyWith(name: newName);

  @override
  PolygonObject withVisibility(bool isVisible) => copyWith(visible: isVisible);

  @override
  PolygonObject withLocked(bool isLocked) => copyWith(locked: isLocked);

  @override
  PolygonObject withLayerId(String newLayerId) => copyWith(layerId: newLayerId);

  @override
  PolygonObject duplicateWithNewId({
    required String newId,
    String? newLayerId,
    Vec2 offset = Vec2.zero,
  }) {
    return copyWith(
      id: newId,
      name: '$name Copy',
      layerId: newLayerId ?? layerId,
      x: x + offset.x,
      y: y + offset.y,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...boundedFieldsToJson(),
        'sides': sides,
      };

  factory PolygonObject.fromJson(Map<String, dynamic> json) {
    return PolygonObject(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Polygon',
      layerId: (json['layerId'] as String?) ?? '',
      x: ValidationUtils.requireFiniteDouble(json['x'], 'x'),
      y: ValidationUtils.requireFiniteDouble(json['y'], 'y'),
      width: ValidationUtils.requireFiniteDouble(json['width'], 'width', min: 1.0),
      height:
          ValidationUtils.requireFiniteDouble(json['height'], 'height', min: 1.0),
      fill: FillStyle.fromJson(
        (json['fill'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      stroke: StrokeStyle.fromJson(
        (json['stroke'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      sides: ValidationUtils.clampInt(
        (json['sides'] as num?)?.toInt() ?? EditorConstants.defaultPolygonSides,
        EditorConstants.minPolygonSides,
        EditorConstants.maxPolygonSides,
      ),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      visible: json['visible'] is bool ? json['visible'] as bool : true,
      locked: json['locked'] is bool ? json['locked'] as bool : false,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
