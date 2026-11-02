/// Validation, clamping, number formatting, and XML/SVG escaping utilities.
class ValidationUtils {
  ValidationUtils._();

  static bool isFiniteNumber(num? value) =>
      value != null && !value.isNaN && !value.isInfinite;

  static double clampDouble(
    double value,
    double min,
    double max, {
    double? fallback,
  }) {
    if (value.isNaN || value.isInfinite) {
      return fallback ?? min;
    }
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static int clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static double requireFiniteDouble(
    Object? raw,
    String fieldName, {
    double? min,
    double? max,
  }) {
    if (raw is! num || raw.isNaN || raw.isInfinite) {
      throw FormatException('Invalid or non-finite numeric field "$fieldName".');
    }
    var val = raw.toDouble();
    if (min != null && val < min) val = min;
    if (max != null && val > max) val = max;
    return val;
  }

  /// Parses an optional finite numeric JSON value or returns [fallback] if absent/non-finite.
  static double optionalDouble(Object? raw, double fallback) {
    if (raw is num && !raw.isNaN && !raw.isInfinite) {
      return raw.toDouble();
    }
    return fallback;
  }

  /// Parses a required finite integer JSON value with optional [min]/[max] clamping.
  static int requireInt(
    Object? raw,
    String fieldName, {
    int? min,
    int? max,
  }) {
    if (raw is! num || raw.isNaN || raw.isInfinite) {
      throw FormatException('Invalid or non-finite integer field "$fieldName".');
    }
    var val = raw.round();
    if (min != null && val < min) val = min;
    if (max != null && val > max) val = max;
    return val;
  }

  static String formatCompact(double value, {int decimals = 2}) {
    if (value.isNaN || value.isInfinite) return '0';
    final fixed = value.toStringAsFixed(decimals);
    if (!fixed.contains('.')) return fixed;
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// Escapes XML special characters for safe SVG attribute and text output.
  static String escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
