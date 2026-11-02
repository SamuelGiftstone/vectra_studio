import '../core/utils/validation_utils.dart';
import '../math/bounds2d.dart';
import '../math/vec2.dart';
import 'fill_style.dart';
import 'stroke_style.dart';
import 'vector_object.dart';

/// Editable straight line segment between [start] and [end].
class LineObject extends VectorObject {
  final Vec2 start;
  final Vec2 end;

  const LineObject({
    required super.id,
    required super.name,
    required super.layerId,
    required this.start,
    required this.end,
    required super.fill,
    required super.stroke,
    super.opacity,
    super.visible,
    super.locked,
    super.rotation,
  }) : super(type: VectorObjectType.line);

  @override
  Bounds2D get localBounds => Bounds2D.fromPoints(<Vec2>[start, end]);

  double get segmentLength => start.distanceTo(end);

  LineObject copyWith({
    String? id,
    String? name,
    String? layerId,
    Vec2? start,
    Vec2? end,
    FillStyle? fill,
    StrokeStyle? stroke,
    double? opacity,
    bool? visible,
    bool? locked,
    double? rotation,
  }) {
    return LineObject(
      id: id ?? this.id,
      name: name ?? this.name,
      layerId: layerId ?? this.layerId,
      start: start ?? this.start,
      end: end ?? this.end,
      fill: fill ?? this.fill,
      stroke: stroke ?? this.stroke,
      opacity: ValidationUtils.clampDouble(opacity ?? this.opacity, 0.0, 1.0),
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  LineObject translate(Vec2 delta) =>
      copyWith(start: start + delta, end: end + delta);

  @override
  LineObject resizeLocalBounds(Bounds2D newBounds) {
    final oldBounds = localBounds;
    final normStartX = oldBounds.width < 1e-6
        ? 0.0
        : (start.x - oldBounds.minX) / oldBounds.width;
    final normStartY = oldBounds.height < 1e-6
        ? 0.0
        : (start.y - oldBounds.minY) / oldBounds.height;
    final normEndX = oldBounds.width < 1e-6
        ? 1.0
        : (end.x - oldBounds.minX) / oldBounds.width;
    final normEndY = oldBounds.height < 1e-6
        ? 1.0
        : (end.y - oldBounds.minY) / oldBounds.height;

    return copyWith(
      start: Vec2(
        newBounds.minX + normStartX * newBounds.width,
        newBounds.minY + normStartY * newBounds.height,
      ),
      end: Vec2(
        newBounds.minX + normEndX * newBounds.width,
        newBounds.minY + normEndY * newBounds.height,
      ),
    );
  }

  @override
  LineObject withRotation(double newRotationRadians) =>
      copyWith(rotation: newRotationRadians);

  @override
  LineObject withFill(FillStyle newFill) => copyWith(fill: newFill);

  @override
  LineObject withStroke(StrokeStyle newStroke) => copyWith(stroke: newStroke);

  @override
  LineObject withOpacity(double newOpacity) => copyWith(opacity: newOpacity);

  @override
  LineObject withName(String newName) => copyWith(name: newName);

  @override
  LineObject withVisibility(bool isVisible) => copyWith(visible: isVisible);

  @override
  LineObject withLocked(bool isLocked) => copyWith(locked: isLocked);

  @override
  LineObject withLayerId(String newLayerId) => copyWith(layerId: newLayerId);

  @override
  LineObject duplicateWithNewId({
    required String newId,
    String? newLayerId,
    Vec2 offset = Vec2.zero,
  }) {
    return copyWith(
      id: newId,
      name: '$name Copy',
      layerId: newLayerId ?? layerId,
      start: start + offset,
      end: end + offset,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseFieldsToJson(),
        'start': start.toJson(),
        'end': end.toJson(),
      };

  factory LineObject.fromJson(Map<String, dynamic> json) {
    final startJson = json['start'];
    final endJson = json['end'];
    if (startJson is! Map<String, dynamic> || endJson is! Map<String, dynamic>) {
      throw const FormatException('LineObject requires start and end points.');
    }
    return LineObject(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Line',
      layerId: (json['layerId'] as String?) ?? '',
      start: Vec2.fromJson(startJson),
      end: Vec2.fromJson(endJson),
      fill: FillStyle.fromJson(
        (json['fill'] as Map<String, dynamic>?) ?? FillStyle.none.toJson(),
      ),
      stroke: StrokeStyle.fromJson(
        (json['stroke'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      visible: json['visible'] is bool ? json['visible'] as bool : true,
      locked: json['locked'] is bool ? json['locked'] as bool : false,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
