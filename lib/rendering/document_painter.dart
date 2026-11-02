import 'package:flutter/rendering.dart';

import '../core/constants/app_colors.dart';
import '../models/vector_document.dart';
import '../models/vector_object.dart';
import 'artwork_renderer.dart';
import 'grid_painter.dart';
import 'image_decode_cache.dart';
import 'viewport_transform.dart';

/// Renders the artboard, document background, optional grid, all visible
/// [VectorObject]s (via [ArtworkRenderer]), and any in-progress shape/text frame preview.
class DocumentPainter extends CustomPainter {
  final VectorDocument document;
  final ViewportTransform viewport;
  final bool showGrid;
  final double gridSize;
  final VectorObject? draftObject;
  final String? activeEditingTextId;
  final ImageDecodeCache imageCache;

  DocumentPainter({
    required this.document,
    required this.viewport,
    required this.showGrid,
    required this.gridSize,
    this.draftObject,
    this.activeEditingTextId,
    ImageDecodeCache? imageCache,
  })  : imageCache = imageCache ?? ImageDecodeCache.instance,
        super(repaint: imageCache ?? ImageDecodeCache.instance);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    viewport.applyToCanvas(canvas);

    final artboardRect = Rect.fromLTWH(0, 0, document.width, document.height);

    // 1. Artboard elevation shadow
    final shadowOffset = 8.0 / viewport.zoom;
    final shadowPaint = Paint()
      ..color = AppColors.artboardShadow
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        14.0 / viewport.zoom,
      );
    canvas.drawRect(artboardRect.shift(Offset(0, shadowOffset)), shadowPaint);

    // 2. Artboard background fill
    final bgPaint = Paint()
      ..color = document.backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(artboardRect, bgPaint);

    // 3. Optional artboard grid (clipped to artboard)
    if (showGrid) {
      canvas.save();
      canvas.clipRect(artboardRect);
      GridPainter.paintArtboardGrid(
        canvas: canvas,
        width: document.width,
        height: document.height,
        baseGridSize: gridSize,
        zoom: viewport.zoom,
        artboardBackground: document.backgroundColor,
      );
      canvas.restore();
    }

    // 4. Subtle artboard frame border
    final borderPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / viewport.zoom;
    canvas.drawRect(artboardRect, borderPaint);

    // 5. Render visible layers, groups, text, images, shapes, paths, and draft preview
    ArtworkRenderer.paintDocumentArtwork(
      canvas: canvas,
      document: document,
      imageCache: imageCache,
      paintBackground: false,
      skipObjectId: activeEditingTextId,
      draftObject: draftObject,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DocumentPainter oldDelegate) {
    return !identical(oldDelegate.document, document) ||
        oldDelegate.viewport.zoom != viewport.zoom ||
        oldDelegate.viewport.panOffset != viewport.panOffset ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.gridSize != gridSize ||
        oldDelegate.draftObject != draftObject ||
        oldDelegate.activeEditingTextId != activeEditingTextId;
  }
}
