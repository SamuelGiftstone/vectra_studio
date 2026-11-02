import 'package:flutter/painting.dart';

import '../core/utils/color_utils.dart';
import '../core/utils/validation_utils.dart';

/// Fill paint style for editable vector objects.
class FillStyle {
  final Color color;
  final bool isEnabled;
  final double opacity;

  const FillStyle({
    required this.color,
    this.isEnabled = true,
    this.opacity = 1.0,
  });

  static const FillStyle defaultFill = FillStyle(
    color: Color(0xFFA78BFA),
    isEnabled: true,
    opacity: 1.0,
  );

  static const FillStyle none = FillStyle(
    color: Color(0xFFA78BFA),
    isEnabled: false,
    opacity: 1.0,
  );

  FillStyle copyWith({
    Color? color,
    bool? isEnabled,
    double? opacity,
  }) {
    return FillStyle(
      color: color ?? this.color,
      isEnabled: isEnabled ?? this.isEnabled,
      opacity: ValidationUtils.clampDouble(opacity ?? this.opacity, 0.0, 1.0),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'color': ColorUtils.toHex(color, includeAlpha: true),
        'isEnabled': isEnabled,
        'opacity': opacity,
      };

  factory FillStyle.fromJson(
    Map<String, dynamic>? json, {
    FillStyle fallback = FillStyle.defaultFill,
  }) {
    if (json == null) return fallback;
    return FillStyle(
      color: ColorUtils.fromJsonValue(
        json['color'],
        fallback: fallback.color,
      ),
      isEnabled: json['isEnabled'] is bool
          ? json['isEnabled'] as bool
          : fallback.isEnabled,
      opacity: json['opacity'] is num
          ? ValidationUtils.clampDouble(
              (json['opacity'] as num).toDouble(),
              0.0,
              1.0,
            )
          : 1.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FillStyle &&
          ColorUtils.toArgbInt(other.color) == ColorUtils.toArgbInt(color) &&
          other.isEnabled == isEnabled &&
          other.opacity == opacity);

  @override
  int get hashCode =>
      Object.hash(ColorUtils.toArgbInt(color), isEnabled, opacity);
}
