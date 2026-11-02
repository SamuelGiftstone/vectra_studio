import 'package:flutter/painting.dart';

import '../core/utils/color_utils.dart';
import '../core/utils/validation_utils.dart';

/// Stroke cap options mapped cleanly between Flutter Canvas and SVG.
enum VectorStrokeCap {
  butt,
  round,
  square;

  StrokeCap toFlutterCap() {
    switch (this) {
      case VectorStrokeCap.butt:
        return StrokeCap.butt;
      case VectorStrokeCap.round:
        return StrokeCap.round;
      case VectorStrokeCap.square:
        return StrokeCap.square;
    }
  }

  String toSvgValue() => name;

  static VectorStrokeCap fromName(String? raw) {
    return VectorStrokeCap.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => VectorStrokeCap.round,
    );
  }
}

/// Stroke join options mapped cleanly between Flutter Canvas and SVG.
enum VectorStrokeJoin {
  miter,
  round,
  bevel;

  StrokeJoin toFlutterJoin() {
    switch (this) {
      case VectorStrokeJoin.miter:
        return StrokeJoin.miter;
      case VectorStrokeJoin.round:
        return StrokeJoin.round;
      case VectorStrokeJoin.bevel:
        return StrokeJoin.bevel;
    }
  }

  String toSvgValue() => name;

  static VectorStrokeJoin fromName(String? raw) {
    return VectorStrokeJoin.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => VectorStrokeJoin.round,
    );
  }
}

/// Stroke paint style for editable vector objects.
class StrokeStyle {
  final Color color;
  final double width;
  final bool isEnabled;
  final double opacity;
  final VectorStrokeCap cap;
  final VectorStrokeJoin join;

  const StrokeStyle({
    required this.color,
    this.width = 2.0,
    this.isEnabled = true,
    this.opacity = 1.0,
    this.cap = VectorStrokeCap.round,
    this.join = VectorStrokeJoin.round,
  });

  static const StrokeStyle defaultStroke = StrokeStyle(
    color: Color(0xFF1E1B4B),
    width: 2.0,
    isEnabled: true,
    opacity: 1.0,
    cap: VectorStrokeCap.round,
    join: VectorStrokeJoin.round,
  );

  static const StrokeStyle none = StrokeStyle(
    color: Color(0xFF1E1B4B),
    width: 0.0,
    isEnabled: false,
    opacity: 1.0,
    cap: VectorStrokeCap.round,
    join: VectorStrokeJoin.round,
  );

  bool get isVisible => isEnabled && width > 0.0 && opacity > 0.0;

  StrokeStyle copyWith({
    Color? color,
    double? width,
    bool? isEnabled,
    double? opacity,
    VectorStrokeCap? cap,
    VectorStrokeJoin? join,
  }) {
    return StrokeStyle(
      color: color ?? this.color,
      width: ValidationUtils.clampDouble(width ?? this.width, 0.0, 500.0),
      isEnabled: isEnabled ?? this.isEnabled,
      opacity: ValidationUtils.clampDouble(opacity ?? this.opacity, 0.0, 1.0),
      cap: cap ?? this.cap,
      join: join ?? this.join,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'color': ColorUtils.toHex(color, includeAlpha: true),
        'width': width,
        'isEnabled': isEnabled,
        'opacity': opacity,
        'cap': cap.name,
        'join': join.name,
      };

  factory StrokeStyle.fromJson(
    Map<String, dynamic>? json, {
    StrokeStyle fallback = StrokeStyle.defaultStroke,
  }) {
    if (json == null) return fallback;
    return StrokeStyle(
      color: ColorUtils.fromJsonValue(
        json['color'],
        fallback: fallback.color,
      ),
      width: json['width'] is num
          ? ValidationUtils.clampDouble(
              (json['width'] as num).toDouble(),
              0.0,
              500.0,
            )
          : 2.0,
      isEnabled: json['isEnabled'] is bool ? json['isEnabled'] as bool : true,
      opacity: json['opacity'] is num
          ? ValidationUtils.clampDouble(
              (json['opacity'] as num).toDouble(),
              0.0,
              1.0,
            )
          : 1.0,
      cap: VectorStrokeCap.fromName(json['cap'] as String?),
      join: VectorStrokeJoin.fromName(json['join'] as String?),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StrokeStyle &&
          ColorUtils.toArgbInt(other.color) == ColorUtils.toArgbInt(color) &&
          other.width == width &&
          other.isEnabled == isEnabled &&
          other.opacity == opacity &&
          other.cap == cap &&
          other.join == join);

  @override
  int get hashCode => Object.hash(
        ColorUtils.toArgbInt(color),
        width,
        isEnabled,
        opacity,
        cap,
        join,
      );
}
