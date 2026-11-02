import 'dart:math' as math;

import '../core/utils/validation_utils.dart';
import '../math/bounds2d.dart';
import '../math/vec2.dart';
import 'fill_style.dart';
import 'shape_object.dart';
import 'stroke_style.dart';
import 'vector_object.dart';

/// Editable rectangle vector object with optional uniform corner radius.
class RectangleObject extends BoundedShapeObject {
  final double cornerRadius;

  const RectangleObject({
    required super.id,
    required super.name,
    required super.layerId,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.fill,
    required super.stroke,
    this.cornerRadius = 0.0,
    super.opacity,
    super.visible,
    super.locked,
    super.rotation,
  }) : super(type: VectorObjectType.rectangle);

  double get effectiveCornerRadius => cornerRadius.clamp(
        0.0,
        math.min(width.abs(), height.abs()) * 0.5,
      );

  RectangleObject copyWith({
    String? id,
    String? name,
    String? layerId,
    double? x,
    double? y,
    double? width,
    double? height,
    FillStyle? fill,
    StrokeStyle? stroke,
    double? cornerRadius,
    double? opacity,
    bool? visible,
    bool? locked,
    double? rotation,
  }) {
    return RectangleObject(
      id: id ?? this.id,
      name: name ?? this.name,
      layerId: layerId ?? this.layerId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: math.max(1.0, width ?? this.width),
      height: math.max(1.0, height ?? this.height),
      fill: fill ?? this.fill,
      stroke: stroke ?? this.stroke,
      cornerRadius: math.max(0.0, cornerRadius ?? this.cornerRadius),
      opacity: ValidationUtils.clampDouble(opacity ?? this.opacity, 0.0, 1.0),
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  RectangleObject resizeLocalBounds(Bounds2D newBounds) {
    return copyWith(
      x: newBounds.left,
      y: newBounds.top,
      width: math.max(1.0, newBounds.width),
      height: math.max(1.0, newBounds.height),
    );
  }

  @override
  RectangleObject withRotation(double newRotationRadians) =>
      copyWith(rotation: newRotationRadians);

  @override
  RectangleObject withFill(FillStyle newFill) => copyWith(fill: newFill);

  @override
  RectangleObject withStroke(StrokeStyle newStroke) =>
      copyWith(stroke: newStroke);

  @override
  RectangleObject withOpacity(double newOpacity) =>
      copyWith(opacity: newOpacity);

  @override
  RectangleObject withName(String newName) => copyWith(name: newName);

  @override
  RectangleObject withVisibility(bool isVisible) =>
      copyWith(visible: isVisible);

  @override
  RectangleObject withLocked(bool isLocked) => copyWith(locked: isLocked);

  @override
  RectangleObject withLayerId(String newLayerId) =>
      copyWith(layerId: newLayerId);

  @override
  RectangleObject duplicateWithNewId({
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
        'cornerRadius': cornerRadius,
      };

  factory RectangleObject.fromJson(Map<String, dynamic> json) {
    return RectangleObject(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Rectangle',
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
      cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 0.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      visible: json['visible'] is bool ? json['visible'] as bool : true,
      locked: json['locked'] is bool ? json['locked'] as bool : false,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
