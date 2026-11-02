import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/constants/editor_constants.dart';
import '../math/bounds2d.dart';
import 'font_catalog.dart';

/// Shared text measurement and layout engine backed by Flutter's native [TextPainter].
///
/// Guarantees consistent bounding boxes across hit-testing, selection handles,
/// floating object tags, Find My Artwork bounds, canvas painting, and raster export.
class TextLayoutService {
  TextLayoutService._();

  /// Builds and lays out a [TextPainter] for the given typographic parameters.
  ///
  /// When [frameWidth] is non-null, text wraps inside `[0, frameWidth]` (Area Text).
  /// When [frameWidth] is null, text uses intrinsic line widths (Point Text).
  static TextPainter buildLaidOutPainter({
    required String text,
    required String fontFamily,
    required double fontSize,
    required int fontWeightValue,
    required bool isItalic,
    required TextAlign textAlign,
    required double lineHeight,
    required double letterSpacing,
    required Color color,
    double? frameWidth,
    Paint? foreground,
  }) {
    // Preserve trailing newlines visually during measurement & editing
    final effectiveText = text.isEmpty
        ? ' '
        : (text.endsWith('\n') ? '$text ' : text);

    final style = FontCatalog.buildTextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeightValue: fontWeightValue,
      isItalic: isItalic,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      color: color,
      foreground: foreground,
    );

    final painter = TextPainter(
      text: TextSpan(text: effectiveText, style: style),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    );

    if (frameWidth != null) {
      final constrainedWidth = math.max(
        EditorConstants.minTextFrameWidth,
        frameWidth,
      );
      painter.layout(
        minWidth: constrainedWidth,
        maxWidth: constrainedWidth,
      );
    } else {
      painter.layout();
    }

    return painter;
  }

  /// Measures the unrotated local document [Bounds2D] of a text block anchored at `(x, y)`.
  static Bounds2D measureLocalBounds({
    required double x,
    required double y,
    required String text,
    required String fontFamily,
    required double fontSize,
    required int fontWeightValue,
    required bool isItalic,
    required TextAlign textAlign,
    required double lineHeight,
    required double letterSpacing,
    double? frameWidth,
    double? frameHeight,
  }) {
    final painter = buildLaidOutPainter(
      text: text,
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeightValue: fontWeightValue,
      isItalic: isItalic,
      textAlign: textAlign,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      color: const Color(0xFFFFFFFF),
      frameWidth: frameWidth,
    );

    final double measuredW;
    final double measuredH;

    if (frameWidth != null) {
      measuredW = math.max(EditorConstants.minTextFrameWidth, frameWidth);
      measuredH = math.max(
        frameHeight ?? EditorConstants.minTextFrameHeight,
        math.max(EditorConstants.minTextFrameHeight, painter.height),
      );
    } else {
      final minGlyphW = math.max(8.0, fontSize * 0.35);
      final minGlyphH = math.max(10.0, fontSize * lineHeight);
      measuredW = text.isEmpty ? minGlyphW : math.max(minGlyphW, painter.width);
      measuredH = math.max(minGlyphH, painter.height);
    }

    painter.dispose();
    return Bounds2D.fromLTWH(x, y, measuredW, measuredH);
  }

  /// Computes the horizontal offset inside a point-text block for aligned multiline text
  /// when exporting to formats like SVG `<text>` / `<tspan>`.
  static double alignedLineAnchorX({
    required double left,
    required double width,
    required TextAlign align,
  }) {
    switch (align) {
      case TextAlign.center:
        return left + width * 0.5;
      case TextAlign.right:
      case TextAlign.end:
        return left + width;
      case TextAlign.left:
      case TextAlign.start:
      case TextAlign.justify:
        return left;
    }
  }
}
