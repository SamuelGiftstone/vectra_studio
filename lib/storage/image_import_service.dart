import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

import '../core/constants/editor_constants.dart';
import '../core/utils/id_generator.dart';
import '../models/image_asset.dart';
import '../models/image_object.dart';
import '../models/vector_document.dart';
import '../models/vector_object.dart';
import 'storage_exceptions.dart';

/// Result of importing a local raster image into a [VectorDocument].
class ImportedRasterImage {
  final ImageAsset asset;
  final ImageObject imageObject;

  const ImportedRasterImage({
    required this.asset,
    required this.imageObject,
  });
}

/// Validates and imports local PNG, JPEG/JPG, and WebP images as selectable,
/// transformable [ImageObject]s backed by binary [ImageAsset] records.
class ImageImportService {
  const ImageImportService();

  /// Prompts the user to pick a local raster image file (`.png`, `.jpg`, `.jpeg`, `.webp`).
  /// Returns `null` if canceled.
  Future<ImportedRasterImage?> pickAndImportImage(
    VectorDocument currentDocument,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Raster Image (PNG, JPEG, WebP)',
      type: FileType.custom,
      allowedExtensions: EditorConstants.supportedRasterImportExtensions,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final picked = result.files.single;
    final path = picked.path;
    if (path != null && path.isNotEmpty) {
      return importImageFromFile(path, currentDocument);
    }

    if (picked.bytes != null && picked.bytes!.isNotEmpty) {
      return importImageFromBytes(
        bytes: picked.bytes!,
        fileName: picked.name,
        currentDocument: currentDocument,
      );
    }

    throw const ProjectStorageException(
      'Selected image file could not be read from disk.',
    );
  }

  /// Reads, validates, and decodes a local image file at [filePath].
  Future<ImportedRasterImage> importImageFromFile(
    String filePath,
    VectorDocument currentDocument,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ProjectStorageException('Image file does not exist: $filePath');
    }

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on IOException catch (e) {
      throw ProjectStorageException(
        'Failed to read image file "$filePath": $e',
        e,
      );
    }

    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'Image.png';

    return importImageFromBytes(
      bytes: bytes,
      fileName: fileName,
      currentDocument: currentDocument,
    );
  }

  /// Validates [bytes], extracts natural pixel dimensions via `package:image`,
  /// and builds a centered, aspect-ratio-preserving [ImageObject].
  ImportedRasterImage importImageFromBytes({
    required Uint8List bytes,
    required String fileName,
    required VectorDocument currentDocument,
  }) {
    if (bytes.isEmpty) {
      throw const ProjectFormatException('Imported image file is empty.');
    }

    final ext = _extractExtension(fileName, bytes);
    if (!EditorConstants.supportedRasterImportExtensions.contains(ext)) {
      throw ProjectFormatException(
        'Unsupported image format ".$ext". Supported formats: PNG, JPG/JPEG, WebP.',
      );
    }

    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (e) {
      throw ProjectFormatException(
        'Corrupted or unreadable image file "$fileName": $e',
        e,
      );
    }

    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      throw ProjectFormatException(
        'Unable to decode raster image "$fileName". Ensure it is a valid PNG, JPEG, or WebP file.',
      );
    }

    final naturalW = decoded.width;
    final naturalH = decoded.height;
    final mimeType = _mimeForExtension(ext);
    final baseTitle = _stripExtension(fileName);
    final assetId = IdGenerator.assetId();

    final asset = ImageAsset(
      id: assetId,
      name: baseTitle,
      mimeType: mimeType,
      extension: ext,
      bytes: bytes,
      naturalWidth: naturalW,
      naturalHeight: naturalH,
    );

    // Fit oversized images cleanly inside 75% of the artboard while preserving aspect ratio
    final maxInitialW = currentDocument.width * 0.75;
    final maxInitialH = currentDocument.height * 0.75;
    var placedW = naturalW.toDouble();
    var placedH = naturalH.toDouble();
    if (placedW > maxInitialW || placedH > maxInitialH) {
      final scale = math.min(maxInitialW / placedW, maxInitialH / placedH);
      placedW = math.max(16.0, placedW * scale);
      placedH = math.max(16.0, placedH * scale);
    }

    final placedX = (currentDocument.width - placedW) * 0.5;
    final placedY = (currentDocument.height - placedH) * 0.5;

    final objName = baseTitle.isNotEmpty
        ? currentDocument.nextObjectName(
            VectorObjectType.image,
            customPrefix: baseTitle,
          )
        : currentDocument.nextObjectName(VectorObjectType.image);

    final imageObject = ImageObject(
      id: IdGenerator.objectId(),
      name: objName,
      layerId: currentDocument.activeLayer.id,
      assetId: assetId,
      x: placedX,
      y: placedY,
      width: placedW,
      height: placedH,
      naturalWidth: naturalW,
      naturalHeight: naturalH,
      preserveAspectRatio: true,
    );

    return ImportedRasterImage(
      asset: asset,
      imageObject: imageObject,
    );
  }

  String _extractExtension(String fileName, Uint8List bytes) {
    final dotIdx = fileName.lastIndexOf('.');
    if (dotIdx != -1 && dotIdx < fileName.length - 1) {
      final raw = fileName.substring(dotIdx + 1).trim().toLowerCase();
      if (EditorConstants.supportedRasterImportExtensions.contains(raw)) {
        return raw;
      }
    }
    // Fallback magic-byte detection
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return dotIdx != -1 ? fileName.substring(dotIdx + 1).toLowerCase() : 'png';
  }

  String _mimeForExtension(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'png':
      default:
        return 'image/png';
    }
  }

  String _stripExtension(String fileName) {
    final trimmed = fileName.trim();
    final dotIdx = trimmed.lastIndexOf('.');
    if (dotIdx <= 0) return trimmed.isEmpty ? 'Image' : trimmed;
    return trimmed.substring(0, dotIdx).trim();
  }
}
