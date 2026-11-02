import '../math/bounds2d.dart';
import '../math/geometry_math.dart';
import '../math/vec2.dart';
import 'fill_style.dart';
import 'stroke_style.dart';
import 'transform_data.dart';

/// Supported vector primitive & path types in VECTRA Studio.
enum VectorObjectType {
  rectangle,
  ellipse,
  line,
  polygon,
  star,
  path,
  text,
  image,
  group;

  String get displayLabel {
    switch (this) {
      case VectorObjectType.rectangle:
        return 'Rectangle';
      case VectorObjectType.ellipse:
        return 'Ellipse';
      case VectorObjectType.line:
        return 'Line';
      case VectorObjectType.polygon:
        return 'Polygon';
      case VectorObjectType.star:
        return 'Star';
      case VectorObjectType.path:
        return 'Path';
      case VectorObjectType.text:
        return 'Text';
      case VectorObjectType.image:
        return 'Image';
      case VectorObjectType.group:
        return 'Group';
    }
  }


  static VectorObjectType fromName(String? raw) {
    return VectorObjectType.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => throw FormatException('Unknown vector object type "$raw".'),
    );
  }
}

/// Abstract base class for every editable vector object in a [VectorDocument].
abstract class VectorObject {
  final String id;
  final String name;
  final VectorObjectType type;
  final String layerId;
  final FillStyle fill;
  final StrokeStyle stroke;
  final double opacity;
  final bool visible;
  final bool locked;
  final double rotation;

  const VectorObject({
    required this.id,
    required this.name,
    required this.type,
    required this.layerId,
    required this.fill,
    required this.stroke,
    this.opacity = 1.0,
    this.visible = true,
    this.locked = false,
    this.rotation = 0.0,
  });

  /// Unrotated geometric bounding box in document coordinates.
  Bounds2D get localBounds;

  /// Axis-aligned bounding box in document coordinates accounting for [rotation].
  Bounds2D get worldBounds => GeometryMath.rotatedBounds(localBounds, rotation);

  /// Geometric pivot center in document coordinates.
  Vec2 get center => localBounds.center;

  /// Spatial summary used by the Inspector panel.
  TransformData get transform {
    final b = localBounds;
    return TransformData(
      x: b.left,
      y: b.top,
      width: b.width,
      height: b.height,
      rotationRadians: rotation,
    );
  }

  /// Translates the object in document coordinates by [delta].
  VectorObject translate(Vec2 delta);

  /// Resizes the object's local geometry to fit [newBounds].
  VectorObject resizeLocalBounds(Bounds2D newBounds);

  VectorObject withRotation(double newRotationRadians);
  VectorObject withFill(FillStyle newFill);
  VectorObject withStroke(StrokeStyle newStroke);
  VectorObject withOpacity(double newOpacity);
  VectorObject withName(String newName);
  VectorObject withVisibility(bool isVisible);
  VectorObject withLocked(bool isLocked);
  VectorObject withLayerId(String newLayerId);

  /// Creates an independent clone with [newId] and optional translation [offset].
  VectorObject duplicateWithNewId({
    required String newId,
    String? newLayerId,
    Vec2 offset = Vec2.zero,
  });

  /// Serializes shared base fields into JSON.
  Map<String, dynamic> baseFieldsToJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': type.name,
        'layerId': layerId,
        'fill': fill.toJson(),
        'stroke': stroke.toJson(),
        'opacity': opacity,
        'visible': visible,
        'locked': locked,
        'rotation': rotation,
      };

  Map<String, dynamic> toJson();
}
