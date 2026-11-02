import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

import '../core/constants/editor_constants.dart';
import '../models/vector_document.dart';
import '../rendering/artwork_renderer.dart';
import '../rendering/image_decode_cache.dart';
import 'storage_exceptions.dart';

/// Renders pure document artwork offscreen via `dart:ui` [ui.PictureRecorder]
/// and encodes lossless RGBA PNG or opaque JPEG files without any editor overlays.
class RasterExportService {
  const RasterExportService();

  /// Renders [document] to a [ui.Image] at `[document.width * scale, document.height * scale]`.
  Future<ui.Image> renderArtworkImage(
    VectorDocument document, {
    double scale = 1.0,
    required bool paintBackground,
    Color? backgroundOverride,
  }) async {
    final safeScale = scale.clamp(0.1, 16.0);
    final pixelW = math.max(1, (document.width * safeScale).round());
    final pixelH = math.max(1, (document.height * safeScale).round());

    if (pixelW > 16384 || pixelH > 16384) {
      throw ProjectStorageException(
        'Export dimensions (${pixelW}x$pixelH px) exceed the maximum supported 16384x16384 raster size.',
      );
    }

    final cache = ImageDecodeCache.instance;
    await cache.ensureDecodedForDocument(document);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, pixelW.toDouble(), pixelH.toDouble()),
    );

    canvas.save();
    canvas.scale(
      pixelW / document.width,
      pixelH / document.height,
    );

    ArtworkRenderer.paintDocumentArtwork(
      canvas: canvas,
      document: document,
      imageCache: cache,
      paintBackground: paintBackground,
      backgroundOverride: backgroundOverride,
    );

    canvas.restore();

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(pixelW, pixelH);
    } finally {
      picture.dispose();
    }
  }

  /// Encodes [document] into lossless RGBA `.png` bytes.
  ///
  /// When [transparentBackground] is `true`, the artboard background fill is omitted
  /// so empty regions preserve alpha `0`.
  Future<Uint8List> encodePng(
    VectorDocument document, {
    double scale = 1.0,
    bool transparentBackground = false,
  }) async {
    final image = await renderArtworkImage(
      document,
      scale: scale,
      paintBackground: !transparentBackground,
    );
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw const ProjectStorageException(
          'Flutter engine failed to encode PNG byte data.',
        );
      }
      return byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
    } finally {
      image.dispose();
    }
  }

  /// Encodes [document] into `.jpg` bytes using `package:image` `encodeJpg`,
  /// compositing onto an opaque [backgroundColor] (JPEG does not support alpha).
  Future<Uint8List> encodeJpeg(
    VectorDocument document, {
    double scale = 1.0,
    Color? backgroundColor,
    int quality = EditorConstants.defaultJpegQuality,
  }) async {
    final baseBg = backgroundColor ?? document.backgroundColor;
    // Ensure 100% opaque background for JPEG compositing
    final opaqueBg = baseBg.alpha == 255
        ? baseBg
        : Color.alphaBlend(baseBg, const Color(0xFFFFFFFF));

    final image = await renderArtworkImage(
      document,
      scale: scale,
      paintBackground: true,
      backgroundOverride: opaqueBg,
    );

    try {
      final rawRgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rawRgba == null) {
        throw const ProjectStorageException(
          'Flutter engine failed to extract RGBA pixel buffer for JPEG encoding.',
        );
      }

      final rgbaView = rawRgba.buffer.asUint8List(
        rawRgba.offsetInBytes,
        rawRgba.lengthInBytes,
      );
      final copiedRgba = Uint8List.fromList(rgbaView);

      final raster = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: copiedRgba.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );

      final clampedQuality = quality.clamp(10, 100);
      return img.encodeJpg(raster, quality: clampedQuality);
    } finally {
      image.dispose();
    }
  }
}
