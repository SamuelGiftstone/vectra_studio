import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../core/constants/editor_constants.dart';
import '../models/vector_document.dart';
import 'document_deserializer.dart';
import 'document_export_service.dart';
import 'document_serializer.dart';
import 'image_import_service.dart';
import 'storage_exceptions.dart';
import 'svg_exporter.dart';
import 'svg_import_service.dart';

/// Result returned when opening a `.vectra` project from disk.
class LoadedProjectResult {
  final VectorDocument document;
  final String filePath;

  const LoadedProjectResult({
    required this.document,
    required this.filePath,
  });
}

/// Manages local file system persistence for `.vectra` projects (both plain JSON
/// and ZIP archive bundles with binary raster assets), image/SVG imports, and
/// SVG/PNG/JPEG exports.
class ProjectStorage {
  final DocumentSerializer _serializer;
  final DocumentDeserializer _deserializer;
  final SvgExporter _svgExporter;
  final ImageImportService _imageImporter;
  final SvgImportService _svgImporter;
  final DocumentExportService _exportService;

  const ProjectStorage({
    DocumentSerializer serializer = const DocumentSerializer(),
    DocumentDeserializer deserializer = const DocumentDeserializer(),
    SvgExporter svgExporter = const SvgExporter(),
    ImageImportService imageImporter = const ImageImportService(),
    SvgImportService svgImporter = const SvgImportService(),
    DocumentExportService exportService = const DocumentExportService(),
  })  : _serializer = serializer,
        _deserializer = deserializer,
        _svgExporter = svgExporter,
        _imageImporter = imageImporter,
        _svgImporter = svgImporter,
        _exportService = exportService;

  ImageImportService get imageImporter => _imageImporter;
  SvgImportService get svgImporter => _svgImporter;
  DocumentExportService get exportService => _exportService;

  /// Prompts the user to pick a `.vectra` file and deserializes it.
  /// Returns `null` if the user cancels the dialog.
  Future<LoadedProjectResult?> pickAndOpenProject() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Open VECTRA Studio Project',
      type: FileType.custom,
      allowedExtensions: const <String>[EditorConstants.projectExtension],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final pickedPath = result.files.single.path;
    if (pickedPath == null || pickedPath.isEmpty) {
      throw const ProjectStorageException(
        'Selected file did not provide a readable desktop path.',
      );
    }

    return loadProjectFromPath(pickedPath);
  }

  /// Reads and deserializes a `.vectra` project (either v1/v2 JSON or v2 ZIP archive)
  /// directly from [filePath].
  Future<LoadedProjectResult> loadProjectFromPath(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ProjectStorageException('Project file not found: $filePath');
      }
      final rawBytes = await file.readAsBytes();
      final doc = _deserializer.deserializeBytes(rawBytes);
      return LoadedProjectResult(document: doc, filePath: filePath);
    } on ProjectStorageException {
      rethrow;
    } on IOException catch (e) {
      throw ProjectStorageException('Unable to read file "$filePath": $e', e);
    }
  }

  /// Saves [document] directly to an existing [filePath].
  /// Automatically writes a portable `.vectra` ZIP archive bundle when binary
  /// raster assets are present, or clean UTF-8 JSON otherwise.
  Future<String> saveProjectToPath(
    VectorDocument document,
    String filePath,
  ) async {
    final normalizedPath = _ensureExtension(
      filePath,
      EditorConstants.projectExtension,
    );
    try {
      final projectBytes = _serializer.serializeToProjectBytes(document);
      final file = File(normalizedPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(projectBytes, flush: true);
      return normalizedPath;
    } on IOException catch (e) {
      throw ProjectStorageException(
        'Failed to write project file "$normalizedPath": $e',
        e,
      );
    }
  }

  /// Opens a native Save As dialog for `.vectra` projects and writes the file.
  Future<String?> pickAndSaveProjectAs(VectorDocument document) async {
    final suggestedName =
        '${_sanitizeFileName(document.name)}.${EditorConstants.projectExtension}';
    final chosenPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save VECTRA Studio Project',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: const <String>[EditorConstants.projectExtension],
    );

    if (chosenPath == null || chosenPath.trim().isEmpty) {
      return null;
    }
    return saveProjectToPath(document, chosenPath);
  }

  /// Opens a native Save dialog and exports [document] to a `.svg` vector file.
  Future<String?> pickAndExportSvg(VectorDocument document) async {
    final suggestedName =
        '${_sanitizeFileName(document.name)}.${EditorConstants.svgExtension}';
    final chosenPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Artwork as SVG',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: const <String>[EditorConstants.svgExtension],
    );

    if (chosenPath == null || chosenPath.trim().isEmpty) {
      return null;
    }

    return exportSvgToPath(document, chosenPath);
  }

  /// Writes SVG markup for [document] directly to [filePath].
  Future<String> exportSvgToPath(
    VectorDocument document,
    String filePath,
  ) async {
    final normalizedPath = _ensureExtension(
      filePath,
      EditorConstants.svgExtension,
    );
    try {
      final svgMarkup = _svgExporter.export(document);
      final file = File(normalizedPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(svgMarkup, flush: true);
      return normalizedPath;
    } on IOException catch (e) {
      throw ProjectStorageException(
        'Failed to export SVG to "$normalizedPath": $e',
        e,
      );
    }
  }

  String generateSvgPreview(VectorDocument document) {
    return _svgExporter.export(document);
  }

  String _ensureExtension(String path, String extensionWithoutDot) {
    final suffix = '.$extensionWithoutDot';
    if (path.toLowerCase().endsWith(suffix.toLowerCase())) {
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
