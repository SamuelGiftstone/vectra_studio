import 'dart:ui';

import '../core/constants/app_colors.dart';
import '../core/utils/color_utils.dart';

/// Renders an adaptive unit grid clipped to the artboard when enabled.
class GridPainter {
  GridPainter._();

  static void paintArtboardGrid({
    required Canvas canvas,
    required double width,
    required double height,
    required double baseGridSize,
    required double zoom,
    required Color artboardBackground,
  }) {
    if (baseGridSize <= 1.0 || zoom <= 0.05) return;

    // Adapt grid step so lines never crowd below ~10 screen pixels
    var step = baseGridSize;
    while (step * zoom < 10.0) {
      step *= 5.0;
    }

    final darkBg = ColorUtils.isDark(artboardBackground);
    final minorPaint = Paint()
      ..color = darkBg ? AppColors.gridMinorDark : AppColors.gridMinor
      ..strokeWidth = 1.0 / zoom
      ..style = PaintingStyle.stroke;

    final majorPaint = Paint()
      ..color = darkBg ? AppColors.gridMajorDark : AppColors.gridMajor
      ..strokeWidth = 1.0 / zoom
      ..style = PaintingStyle.stroke;

    var colIndex = 0;
    for (var x = 0.0; x <= width; x += step) {
      final isMajor = colIndex % 5 == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, height),
        isMajor ? majorPaint : minorPaint,
      );
      colIndex++;
    }

    var rowIndex = 0;
    for (var y = 0.0; y <= height; y += step) {
      final isMajor = rowIndex % 5 == 0;
      canvas.drawLine(
        Offset(0, y),
        Offset(width, y),
        isMajor ? majorPaint : minorPaint,
      );
      rowIndex++;
    }
  }
}
