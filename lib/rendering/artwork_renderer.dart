import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../core/constants/app_colors.dart';
import '../models/group_object.dart';
import '../models/image_object.dart';
import '../models/line_object.dart';
import '../models/text_object.dart';
import '../models/vector_document.dart';
import '../models/vector_object.dart';
import 'image_decode_cache.dart';
import 'path_builder_utils.dart';
import 'text_layout_service.dart';

/// Shared pure-artwork rendering pipeline used by both [DocumentPainter] (interactive
/// viewport) and `RasterExportService` (PNG & JPEG export).
///
/// Never renders editor overlays, selection handles, floating tags, grid lines, or cursors.
class ArtworkRenderer {
  ArtworkRenderer._();

  /// Renders all visible layers and objects of [document] onto [canvas] in document coordinates.
  static void paintDocumentArtwork({
    required Canvas canvas,
    required VectorDocument document,
    required ImageDecodeCache imageCache,
    bool paintBackground = true,
    Color? backgroundOverride,
    String? skipObjectId,
    VectorObject? draftObject,
  }) {
    final artboardRect = Rect.fromLTWH(0, 0, document.width, document.height);

    if (paintBackground) {
      final bgColor = backgroundOverride ?? document.backgroundColor;
      if (bgColor.alpha > 0) {
        final bgPaint = Paint()
          ..color = bgColor
          ..style = PaintingStyle.fill;
        canvas.drawRect(artboardRect, bgPaint);
      }
    }

    for (final layer in document.layers) {
      if (!layer.visible) continue;
      for (final obj in layer.objects) {
        if (!obj.visible) continue;
        paintObject(
          canvas: canvas,
          object: obj,
          document: document,
          imageCache: imageCache,
          parentOpacity: 1.0,
          skipObjectId: skipObjectId,
        );
      }
    }

    if (draftObject != null && draftObject.id != skipObjectId) {
      paintObject(
        canvas: canvas,
        object: draftObject,
        document: document,
        imageCache: imageCache,
        parentOpacity: 1.0,
        skipObjectId: skipObjectId,
      );
    }
  }

  /// Paints a single [VectorObject] (including recursive [GroupObject] hierarchies,
  /// [TextObject] typography, [ImageObject] bitmaps, and vector paths/shapes).
  static void paintObject({
    required Canvas canvas,
    required VectorObject object,
    required VectorDocument document,
    required ImageDecodeCache imageCache,
    double parentOpacity = 1.0,
    String? skipObjectId,
  }) {
    if (!object.visible || object.id == skipObjectId) return;
    final effectiveOpacity = (parentOpacity * object.opacity).clamp(0.0, 1.0);
    if (effectiveOpacity <= 0.0) return;

    canvas.save();

    if (object.rotation.abs() > 1e-9) {
      final c = object.center;
      canvas.translate(c.x, c.y);
      canvas.rotate(object.rotation);
      canvas.translate(-c.x, -c.y);
    }

    if (object is GroupObject) {
      for (final child in object.children) {
        if (!child.visible) continue;
        paintObject(
          canvas: canvas,
          object: child,
          document: document,
          imageCache: imageCache,
          parentOpacity: effectiveOpacity,
          skipObjectId: skipObjectId,
        );
      }
      canvas.restore();
      return;
    }

    if (object is TextObject) {
      _paintTextObject(canvas, object, effectiveOpacity);
      canvas.restore();
      return;
    }

    if (object is ImageObject) {
      _paintImageObject(canvas, object, document, imageCache, effectiveOpacity);
      canvas.restore();
      return;
    }

    // Standard primitive shape or Bézier PathObject
    final path = PathBuilderUtils.buildLocalPath(object);

    if (object is! LineObject &&
        object.fill.isEnabled &&
        object.fill.opacity > 0.0) {
      final combinedAlpha = ((object.fill.color.alpha / 255.0) *
              object.fill.opacity *
              effectiveOpacity)
          .clamp(0.0, 1.0);
      final fillPaint = Paint()
        ..color = object.fill.color.withOpacity(combinedAlpha)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawPath(path, fillPaint);
    }

    if (object.stroke.isVisible) {
      final combinedAlpha = ((object.stroke.color.alpha / 255.0) *
              object.stroke.opacity *
              effectiveOpacity)
          .clamp(0.0, 1.0);
      final strokePaint = Paint()
        ..color = object.stroke.color.withOpacity(combinedAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = object.stroke.width
        ..strokeCap = object.stroke.cap.toFlutterCap()
        ..strokeJoin = object.stroke.join.toFlutterJoin()
        ..isAntiAlias = true;
      canvas.drawPath(path, strokePaint);
    }

    canvas.restore();
  }

  static void _paintTextObject(
    Canvas canvas,
    TextObject obj,
    double effectiveOpacity,
  ) {
    if (obj.text.isEmpty) return;

    final hasClipFrame = obj.isAreaText && obj.frameHeight != null;
    if (hasClipFrame) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          obj.x,
          obj.y,
          obj.frameWidth!,
          obj.frameHeight!,
        ),
      );
    }

    // Optional fill pass
    if (obj.fill.isEnabled && obj.fill.opacity > 0.0) {
      final fillAlpha = ((obj.fill.color.alpha / 255.0) *
              obj.fill.opacity *
              effectiveOpacity)
          .clamp(0.0, 1.0);
      final fillColor = obj.fill.color.withOpacity(fillAlpha);

      final fillPainter = TextLayoutService.buildLaidOutPainter(
        text: obj.text,
        fontFamily: obj.fontFamily,
        fontSize: obj.fontSize,
        fontWeightValue: obj.fontWeightValue,
        isItalic: obj.isItalic,
        textAlign: obj.textAlign,
        lineHeight: obj.lineHeight,
        letterSpacing: obj.letterSpacing,
        color: fillColor,
        frameWidth: obj.frameWidth,
      );
      fillPainter.paint(canvas, Offset(obj.x, obj.y));
      fillPainter.dispose();
    }

    // Optional text stroke pass
    if (obj.stroke.isVisible) {
      final strokeAlpha = ((obj.stroke.color.alpha / 255.0) *
              obj.stroke.opacity *
              effectiveOpacity)
          .clamp(0.0, 1.0);
      final strokePaint = Paint()
        ..color = obj.stroke.color.withOpacity(strokeAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = obj.stroke.width
        ..strokeCap = obj.stroke.cap.toFlutterCap()
        ..strokeJoin = obj.stroke.join.toFlutterJoin()
        ..isAntiAlias = true;

      final strokePainter = TextLayoutService.buildLaidOutPainter(
        text: obj.text,
        fontFamily: obj.fontFamily,
        fontSize: obj.fontSize,
        fontWeightValue: obj.fontWeightValue,
        isItalic: obj.isItalic,
        textAlign: obj.textAlign,
        lineHeight: obj.lineHeight,
        letterSpacing: obj.letterSpacing,
        color: obj.stroke.color,
        frameWidth: obj.frameWidth,
        foreground: strokePaint,
      );
      strokePainter.paint(canvas, Offset(obj.x, obj.y));
      strokePainter.dispose();
    }

    if (hasClipFrame) {
      canvas.restore();
    }
  }

  static void _paintImageObject(
    Canvas canvas,
    ImageObject obj,
    VectorDocument document,
    ImageDecodeCache imageCache,
    double effectiveOpacity,
  ) {
    final dstRect = Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height);
    final asset = document.findAssetById(obj.assetId);
    final ui.Image? decoded =
        asset != null ? imageCache.getOrScheduleDecode(asset) : null;

    if (decoded != null) {
      final srcRect = Rect.fromLTWH(
        0,
        0,
        decoded.width.toDouble(),
        decoded.height.toDouble(),
      );
      final imgPaint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, effectiveOpacity)
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true;
      canvas.drawImageRect(decoded, srcRect, dstRect, imgPaint);
    } else {
      // Clean non-intrusive placeholder frame while first-frame codec decode finishes
      final placeholderFill = Paint()
        ..color = AppColors.secondarySurface.withOpacity(0.35 * effectiveOpacity)
        ..style = PaintingStyle.fill;
      final placeholderBorder = Paint()
        ..color = AppColors.border.withOpacity(effectiveOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRect(dstRect, placeholderFill);
      canvas.drawRect(dstRect, placeholderBorder);
    }

    if (obj.stroke.isVisible) {
      final combinedAlpha = ((obj.stroke.color.alpha / 255.0) *
              obj.stroke.opacity *
              effectiveOpacity)
          .clamp(0.0, 1.0);
      final strokePaint = Paint()
        ..color = obj.stroke.color.withOpacity(combinedAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = obj.stroke.width
        ..strokeCap = obj.stroke.cap.toFlutterCap()
        ..strokeJoin = obj.stroke.join.toFlutterJoin()
        ..isAntiAlias = true;
      canvas.drawRect(dstRect, strokePaint);
    }
  }
}
