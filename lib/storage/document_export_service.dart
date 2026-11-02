import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/painting.dart';

import '../core/constants/editor_constants.dart';
import '../models/vector_document.dart';
import 'raster_export_service.dart';
import 'storage_exceptions.dart';
import 'svg_exporter.dart';

/// Supported artwork export formats in VECTRA Studio.
enum ExportFormat {
  svg,
  png,
  jpeg;

  String get label {
    switch (this) {
      case ExportFormat.svg:
        return 'SVG Vector (.svg)';
      case ExportFormat.png:
        return 'PNG Lossless (.png)';
      case ExportFormat.jpeg:
        return 'JPEG Raster (.jpg)';
    }
  }

  String get extension {
    switch (this) {
      case ExportFormat.svg:
        return EditorConstants.svgExtension;
      case ExportFormat.png:
        return EditorConstants.pngExtension;
      case ExportFormat.jpeg:
        return EditorConstants.jpegExtension;
    }
  }
}

/// User-selected configuration from the Export Artwork dialog.
class ExportConfig {
  final ExportFormat format;
  final double scale;
  final bool includeBackground;
  final Color jpegBackgroundColor;
  final int jpegQuality;

  const ExportConfig({
    required this.format,
    this.scale = 1.0,
    this.includeBackground = true,
    this.jpegBackgroundColor = const Color(0xFFFFFFFF),
    this.jpegQuality = EditorConstants.defaultJpegQuality,
  });

  int outputWidth(VectorDocument doc) =>
      (doc.width * scale.clamp(0.1, 16.0)).round().clamp(1, 16384);

  int outputHeight(VectorDocument doc) =>
      (doc.height * scale.clamp(0.1, 16.0)).round().clamp(1, 16384);
}

/// Summary returned after completing an artwork export.
class ExportResult {
  final ExportFormat format;
  final String filePath;
  final int byteLength;
  final int pixelWidth;
  final int pixelHeight;

  const ExportResult({
    required this.format,
    required this.filePath,
    required this.byteLength,
    required this.pixelWidth,
    required this.pixelHeight,
  });
}

/// Unified service orchestrating SVG, PNG, and JPEG encoding and file-save dialogs.
class DocumentExportService {
  final SvgExporter _svgExporter;
  final RasterExportService _rasterExporter;

  const DocumentExportService({
    SvgExporter svgExporter = const SvgExporter(),
    RasterExportService rasterExporter = const RasterExportService(),
  })  : _svgExporter = svgExporter,
        _rasterExporter = rasterExporter;

  /// Generates encoded bytes in memory for [document] according to [config].
  Future<Uint8List> encodeToBytes(
    VectorDocument document,
    ExportConfig config,
  ) async {
    switch (config.format) {
      case ExportFormat.svg:
        final markup = _svgExporter.export(
          document,
          includeBackground: config.includeBackground,
          scale: config.scale,
        );
        return Uint8List.fromList(utf8.encode(markup));

      case ExportFormat.png:
        return _rasterExporter.encodePng(
          document,
          scale: config.scale,
          transparentBackground: !config.includeBackground,
        );

      case ExportFormat.jpeg:
        return _rasterExporter.encodeJpeg(
          document,
          scale: config.scale,
          backgroundColor: config.jpegBackgroundColor,
          quality: config.jpegQuality,
        );
    }
  }

  /// Prompts the user for a destination path and writes the exported artwork file.
  /// Returns `null` if the user cancels the save dialog.
  Future<ExportResult?> pickAndExport(
    VectorDocument document,
    ExportConfig config,
  ) async {
    final baseName = _sanitizeFileName(document.name);
    final scaleSuffix = (config.scale - 1.0).abs() > 0.01 &&
            config.format != ExportFormat.svg
        ? '@${config.scale.toStringAsFixed(config.scale == config.scale.roundToDouble() ? 0 : 1)}x'
        : '';
    final suggestedFile = '$baseName$scaleSuffix.${config.format.extension}';

    final chosenPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Artwork as ${config.format.label}',
      fileName: suggestedFile,
      type: FileType.custom,
      allowedExtensions: <String>[config.format.extension],
    );

    if (chosenPath == null || chosenPath.trim().isEmpty) {
      return null;
    }

    return exportToPath(document, config, chosenPath);
  }

  /// Writes the exported artwork directly to [filePath] and returns [ExportResult].
  Future<ExportResult> exportToPath(
    VectorDocument document,
    ExportConfig config,
    String filePath,
  ) async {
    final normalizedPath = _ensureExtension(filePath, config.format.extension);
    final encodedBytes = await encodeToBytes(document, config);

    try {
      final file = File(normalizedPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(encodedBytes, flush: true);

      return ExportResult(
        format: config.format,
        filePath: normalizedPath,
        byteLength: encodedBytes.length,
        pixelWidth: config.outputWidth(document),
        pixelHeight: config.outputHeight(document),
      );
    } on IOException catch (e) {
      throw ProjectStorageException(
        'Failed to write exported file "$normalizedPath": $e',
        e,
      );
    }
  }

  String _ensureExtension(String path, String ext) {
    final lower = path.toLowerCase();
    if (ext == 'jpg' && (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))) {
      return path;
    }
    final suffix = '.$ext';
    if (lower.endsWith(suffix.toLowerCase())) {
      return path;
    }
    return '$path$suffix';
  }

  String _sanitizeFileName(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'artwork' : cleaned;
  }
}
