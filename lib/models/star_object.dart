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

/// Editable star vector object with configurable [points] and [innerRadiusRatio].
class StarObject extends BoundedShapeObject {
  final int points;
  final double innerRadiusRatio;

  const StarObject({
    required super.id,
    required super.name,
    required super.layerId,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.fill,
    required super.stroke,
    this.points = EditorConstants.defaultStarPoints,
    this.innerRadiusRatio = EditorConstants.defaultStarInnerRatio,
    super.opacity,
    super.visible,
    super.locked,
    super.rotation,
  }) : super(type: VectorObjectType.star);

  List<Vec2> get localVertices => PolygonMath.generateStarVertices(
        localBounds,
        points: points,
        innerRadiusRatio: innerRadiusRatio,
      );

  StarObject copyWith({
    String? id,
    String? name,
    String? layerId,
    double? x,
    double? y,
    double? width,
    double? height,
    FillStyle? fill,
    StrokeStyle? stroke,
    int? points,
    double? innerRadiusRatio,
    double? opacity,
    bool? visible,
    bool? locked,
    double? rotation,
  }) {
    return StarObject(
      id: id ?? this.id,
      name: name ?? this.name,
      layerId: layerId ?? this.layerId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: math.max(1.0, width ?? this.width),
      height: math.max(1.0, height ?? this.height),
      fill: fill ?? this.fill,
      stroke: stroke ?? this.stroke,
      points: ValidationUtils.clampInt(
        points ?? this.points,
        EditorConstants.minStarPoints,
        EditorConstants.maxStarPoints,
      ),
      innerRadiusRatio: ValidationUtils.clampDouble(
        innerRadiusRatio ?? this.innerRadiusRatio,
        0.10,
        0.92,
      ),
      opacity: ValidationUtils.clampDouble(opacity ?? this.opacity, 0.0, 1.0),
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  StarObject resizeLocalBounds(Bounds2D newBounds) {
    return copyWith(
      x: newBounds.left,
      y: newBounds.top,
      width: math.max(1.0, newBounds.width),
      height: math.max(1.0, newBounds.height),
    );
  }

  @override
  StarObject withRotation(double newRotationRadians) =>
      copyWith(rotation: newRotationRadians);

  @override
  StarObject withFill(FillStyle newFill) => copyWith(fill: newFill);

  @override
  StarObject withStroke(StrokeStyle newStroke) => copyWith(stroke: newStroke);

  @override
  StarObject withOpacity(double newOpacity) => copyWith(opacity: newOpacity);

  @override
  StarObject withName(String newName) => copyWith(name: newName);

  @override
  StarObject withVisibility(bool isVisible) => copyWith(visible: isVisible);

  @override
  StarObject withLocked(bool isLocked) => copyWith(locked: isLocked);

  @override
  StarObject withLayerId(String newLayerId) => copyWith(layerId: newLayerId);

  @override
  StarObject duplicateWithNewId({
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
        'points': points,
        'innerRadiusRatio': innerRadiusRatio,
      };

  factory StarObject.fromJson(Map<String, dynamic> json) {
    return StarObject(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Star',
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
      points: ValidationUtils.clampInt(
        (json['points'] as num?)?.toInt() ?? EditorConstants.defaultStarPoints,
        EditorConstants.minStarPoints,
        EditorConstants.maxStarPoints,
      ),
      innerRadiusRatio: ValidationUtils.clampDouble(
        (json['innerRadiusRatio'] as num?)?.toDouble() ??
            EditorConstants.defaultStarInnerRatio,
        0.10,
        0.92,
      ),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      visible: json['visible'] is bool ? json['visible'] as bool : true,
      locked: json['locked'] is bool ? json['locked'] as bool : false,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
