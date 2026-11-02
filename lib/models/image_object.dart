import 'dart:math' as math;

import '../core/utils/validation_utils.dart';
import '../math/bounds2d.dart';
import '../math/vec2.dart';
import 'fill_style.dart';
import 'stroke_style.dart';
import 'vector_object.dart';

/// Placed raster image object referencing an embedded [ImageAsset] by [assetId].
///
/// Supports moving, resizing (aspect-ratio-preserving by default), rotating,
/// opacity, optional border stroke, visibility, locking, grouping, and persistence.
class ImageObject extends VectorObject {
  final String assetId;
  final double x;
  final double y;
  final double width;
  final double height;
  final int naturalWidth;
  final int naturalHeight;
  final bool preserveAspectRatio;

  const ImageObject({
    required super.id,
    required super.name,
    required super.layerId,
    required this.assetId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.naturalWidth,
    required this.naturalHeight,
    this.preserveAspectRatio = true,
    super.fill = FillStyle.none,
    super.stroke = StrokeStyle.none,
    super.opacity = 1.0,
    super.visible = true,
    super.locked = false,
    super.rotation = 0.0,
  }) : super(type: VectorObjectType.image);

  double get naturalAspectRatio =>
      naturalHeight > 0 ? naturalWidth / naturalHeight : 1.0;

  @override
  Bounds2D get localBounds => Bounds2D.fromLTWH(x, y, width, height);

  ImageObject copyWith({
    String? id,
    String? name,
    String? layerId,
    String? assetId,
    double? x,
    double? y,
    double? width,
    double? height,
    int? naturalWidth,
    int? naturalHeight,
    bool? preserveAspectRatio,
    FillStyle? fill,
    StrokeStyle? stroke,
    double? opacity,
    bool? visible,
    bool? locked,
    double? rotation,
  }) {
    return ImageObject(
      id: id ?? this.id,
      name: name ?? this.name,
      layerId: layerId ?? this.layerId,
      assetId: assetId ?? this.assetId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: math.max(1.0, width ?? this.width),
      height: math.max(1.0, height ?? this.height),
      naturalWidth: naturalWidth ?? this.naturalWidth,
      naturalHeight: naturalHeight ?? this.naturalHeight,
      preserveAspectRatio: preserveAspectRatio ?? this.preserveAspectRatio,
      fill: fill ?? this.fill,
      stroke: stroke ?? this.stroke,
      opacity: (opacity ?? this.opacity).clamp(0.0, 1.0),
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  ImageObject translate(Vec2 delta) => copyWith(
        x: x + delta.x,
        y: y + delta.y,
      );

  @override
  ImageObject resizeLocalBounds(Bounds2D newBounds) {
    return copyWith(
      x: newBounds.left,
      y: newBounds.top,
      width: math.max(1.0, newBounds.width),
      height: math.max(1.0, newBounds.height),
    );
  }

  @override
  ImageObject withRotation(double newRotationRadians) =>
      copyWith(rotation: newRotationRadians);

  @override
  ImageObject withFill(FillStyle newFill) => copyWith(fill: newFill);

  @override
  ImageObject withStroke(StrokeStyle newStroke) => copyWith(stroke: newStroke);

  @override
  ImageObject withOpacity(double newOpacity) => copyWith(opacity: newOpacity);

  @override
  ImageObject withName(String newName) => copyWith(name: newName);

  @override
  ImageObject withVisibility(bool isVisible) => copyWith(visible: isVisible);

  @override
  ImageObject withLocked(bool isLocked) => copyWith(locked: isLocked);

  @override
  ImageObject withLayerId(String newLayerId) => copyWith(layerId: newLayerId);

  @override
  ImageObject duplicateWithNewId({
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
        ...baseFieldsToJson(),
        'assetId': assetId,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'naturalWidth': naturalWidth,
        'naturalHeight': naturalHeight,
        'preserveAspectRatio': preserveAspectRatio,
      };

  factory ImageObject.fromJson(Map<String, dynamic> json) {
    final assetId = (json['assetId'] as String?)?.trim() ?? '';
    if (assetId.isEmpty) {
      throw const FormatException('ImageObject requires a non-empty assetId.');
    }
    return ImageObject(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Image',
      layerId: (json['layerId'] as String?) ?? '',
      assetId: assetId,
      x: ValidationUtils.requireFiniteDouble(json['x'], 'x'),
      y: ValidationUtils.requireFiniteDouble(json['y'], 'y'),
      width: ValidationUtils.requireFiniteDouble(json['width'], 'width', min: 1.0),
      height: ValidationUtils.requireFiniteDouble(
        json['height'],
        'height',
        min: 1.0,
      ),
      naturalWidth: ValidationUtils.requireInt(
        json['naturalWidth'] ?? 100,
        'naturalWidth',
        min: 1,
        max: 32768,
      ),
      naturalHeight: ValidationUtils.requireInt(
        json['naturalHeight'] ?? 100,
        'naturalHeight',
        min: 1,
        max: 32768,
      ),
      preserveAspectRatio: json['preserveAspectRatio'] is bool
          ? json['preserveAspectRatio'] as bool
          : true,
      fill: FillStyle.fromJson(
        json['fill'] as Map<String, dynamic>?,
        fallback: FillStyle.none,
      ),
      stroke: StrokeStyle.fromJson(
        json['stroke'] as Map<String, dynamic>?,
        fallback: StrokeStyle.none,
      ),
      opacity: ValidationUtils.optionalDouble(json['opacity'], 1.0).clamp(
        0.0,
        1.0,
      ),
      visible: json['visible'] is bool ? json['visible'] as bool : true,
      locked: json['locked'] is bool ? json['locked'] as bool : false,
      rotation: ValidationUtils.optionalDouble(json['rotation'], 0.0),
    );
  }
}
