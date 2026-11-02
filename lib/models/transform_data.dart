import '../math/geometry_math.dart';

/// Spatial transform descriptor exposing position, dimensions, and rotation.
class TransformData {
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotationRadians;

  const TransformData({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotationRadians = 0.0,
  });

  double get rotationDegrees => GeometryMath.radiansToDegrees(rotationRadians);

  TransformData copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotationRadians,
  }) {
    return TransformData(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotationRadians: rotationRadians ?? this.rotationRadians,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotationRadians': rotationRadians,
      };

  factory TransformData.fromJson(Map<String, dynamic> json) {
    return TransformData(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 0.0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
      rotationRadians: (json['rotationRadians'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
