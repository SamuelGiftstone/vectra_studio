import 'package:flutter/painting.dart';

/// Utilities for parsing, formatting, and converting colors across JSON, UI, and SVG.
class ColorUtils {
  ColorUtils._();

  /// Formats a [Color] as `#RRGGBB` (or `#AARRGGBB` when [includeAlpha] is true).
  static String toHex(Color color, {bool includeAlpha = false}) {
    final r = color.red.toRadixString(16).padLeft(2, '0').toUpperCase();
    final g = color.green.toRadixString(16).padLeft(2, '0').toUpperCase();
    final b = color.blue.toRadixString(16).padLeft(2, '0').toUpperCase();
    if (includeAlpha) {
      final a = color.alpha.toRadixString(16).padLeft(2, '0').toUpperCase();
      return '#$a$r$g$b';
    }
    return '#$r$g$b';
  }

  /// Formats a [Color] as SVG-compatible `#RRGGBB`.
  static String toSvgHex(Color color) => toHex(color, includeAlpha: false);

  /// Parses `#RGB`, `#RRGGBB`, or `#AARRGGBB` into a [Color].
  /// Returns `null` if [input] is not a valid hex color string.
  static Color? tryParseHex(String input) {
    var cleaned = input.trim();
    if (cleaned.startsWith('#')) {
      cleaned = cleaned.substring(1);
    } else if (cleaned.toLowerCase().startsWith('0x')) {
      cleaned = cleaned.substring(2);
    }

    if (cleaned.length == 3) {
      final r = cleaned[0];
      final g = cleaned[1];
      final b = cleaned[2];
      cleaned = 'FF$r$r$g$g$b$b';
    } else if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    } else if (cleaned.length != 8) {
      return null;
    }

    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) {
      return null;
    }
    return Color(parsed);
  }

  /// Serializes a [Color] as a 32-bit ARGB integer.
  static int toArgbInt(Color color) {
    return ((color.alpha & 0xFF) << 24) |
        ((color.red & 0xFF) << 16) |
        ((color.green & 0xFF) << 8) |
        (color.blue & 0xFF);
  }

  /// Deserializes a [Color] from either an integer or hex string.
  static Color fromJsonValue(Object? raw, {Color fallback = const Color(0xFF000000)}) {
    if (raw is int) {
      return Color(raw);
    }
    if (raw is String) {
      return tryParseHex(raw) ?? fallback;
    }
    return fallback;
  }

  /// Returns `true` when the color is visually dark (useful for grid line contrast).
  static bool isDark(Color color) {
    return color.computeLuminance() < 0.35;
  }
}
