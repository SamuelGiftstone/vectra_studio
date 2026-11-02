import 'dart:convert';
import 'dart:typed_data';

import '../core/constants/app_colors.dart';
import '../core/constants/editor_constants.dart';
import '../core/utils/color_utils.dart';
import '../core/utils/id_generator.dart';
import '../core/utils/validation_utils.dart';
import '../models/ellipse_object.dart';
import '../models/group_object.dart';
import '../models/image_asset.dart';
import '../models/image_object.dart';
import '../models/line_object.dart';
import '../models/path_object.dart';
import '../models/polygon_object.dart';
import '../models/rectangle_object.dart';
import '../models/star_object.dart';
import '../models/text_object.dart';
import '../models/vector_document.dart';
import '../models/vector_layer.dart';
import '../models/vector_object.dart';
import 'storage_exceptions.dart';
import 'vectra_archive_codec.dart';

/// Validates and reconstructs a [VectorDocument] from `.vectra` v1/v2 JSON text,
/// maps, or portable `.vectra` PKZIP archive bundles (`manifest.json` + `assets/*`).
class DocumentDeserializer {
  const DocumentDeserializer();

  /// Deserializes raw `.vectra` file bytes, automatically detecting whether the file
  /// is a `.vectra` PKZIP archive bundle or a plain UTF-8 JSON `.vectra` file.
  VectorDocument deserializeBytes(Uint8List rawBytes) {
    if (rawBytes.isEmpty) {
      throw const ProjectFormatException('The project file is empty.');
    }

    if (VectraArchiveCodec.isZipArchive(rawBytes)) {
      final entries = VectraArchiveCodec.decodeArchive(rawBytes);
      final manifestBytes = entries['manifest.json'];
      if (manifestBytes == null || manifestBytes.isEmpty) {
        throw const ProjectFormatException(
          'Invalid .vectra archive: missing "manifest.json".',
        );
      }
      final String manifestJson;
      try {
        manifestJson = utf8.decode(manifestBytes);
      } on FormatException catch (e) {
        throw ProjectFormatException(
          'Invalid UTF-8 text in .vectra manifest.json: ${e.message}',
          e,
        );
      }
      return deserialize(manifestJson, archiveFiles: entries);
    }

    final String jsonText;
    try {
      jsonText = utf8.decode(rawBytes);
    } on FormatException catch (e) {
      throw ProjectFormatException(
        'Unrecognized .vectra file encoding (neither valid ZIP archive nor UTF-8 JSON): ${e.message}',
        e,
      );
    }
    return deserialize(jsonText);
  }

  VectorDocument deserialize(
    String jsonContent, {
    Map<String, Uint8List>? archiveFiles,
  }) {
    if (jsonContent.trim().isEmpty) {
      throw const ProjectFormatException('The project file is empty.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(jsonContent);
    } on FormatException catch (e) {
      throw ProjectFormatException(
        'Invalid JSON syntax in .vectra project file: ${e.message}',
        e,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const ProjectFormatException(
        'Root of .vectra project file must be a JSON object.',
      );
    }

    return fromMap(decoded, archiveFiles: archiveFiles);
  }

  VectorDocument fromMap(
    Map<String, dynamic> root, {
    Map<String, Uint8List>? archiveFiles,
  }) {
    final format = root['format'];
    if (format != EditorConstants.projectFormatId) {
      throw ProjectFormatException(
        'Unrecognized project format "${format ?? 'missing'}". Expected "${EditorConstants.projectFormatId}".',
      );
    }

    final rawVersion = root['schemaVersion'];
    if (rawVersion is! int) {
      throw const ProjectFormatException(
        'Missing or non-integer "schemaVersion" in project file.',
      );
    }
    if (rawVersion < 1 || rawVersion > EditorConstants.currentSchemaVersion) {
      throw UnsupportedDocumentVersionException(
        foundVersion: rawVersion,
        maxSupportedVersion: EditorConstants.currentSchemaVersion,
      );
    }

    final docMap = root['document'];
    if (docMap is! Map<String, dynamic>) {
      throw const ProjectFormatException(
        'Missing "document" payload in .vectra project file.',
      );
    }

    try {
      final id = (docMap['id'] as String?)?.trim();
      if (id == null || id.isEmpty) {
        throw const FormatException('Document id is missing.');
      }

      final name = (docMap['name'] as String?)?.trim();
      final width = ValidationUtils.requireFiniteDouble(
        docMap['width'],
        'width',
        min: EditorConstants.minArtboardSize,
        max: EditorConstants.maxArtboardSize,
      );
      final height = ValidationUtils.requireFiniteDouble(
        docMap['height'],
        'height',
        min: EditorConstants.minArtboardSize,
        max: EditorConstants.maxArtboardSize,
      );

      final bgColor = ColorUtils.fromJsonValue(
        docMap['backgroundColor'],
        fallback: AppColors.artboardDefaultBg,
      );

      // Parse embedded binary assets (Schema v2+; empty map for Schema v1)
      final parsedAssets = <String, ImageAsset>{};
      final rawAssets = docMap['assets'];
      if (rawAssets != null) {
        if (rawAssets is! List) {
          throw const FormatException('Document "assets" must be a JSON list.');
        }
        for (final rawAsset in rawAssets) {
          if (rawAsset is! Map<String, dynamic>) {
            throw const FormatException('Malformed asset metadata entry.');
          }
          final archivePath = rawAsset['archivePath'] as String?;
          final archiveBytes = (archivePath != null && archiveFiles != null)
              ? archiveFiles[archivePath]
              : null;
          final asset = ImageAsset.fromMetadataAndBytes(
            rawAsset,
            archiveBytes: archiveBytes,
          );
          parsedAssets[asset.id] = asset;
        }
      }

      final rawLayers = docMap['layers'];
      if (rawLayers is! List) {
        throw const FormatException('Document "layers" must be a JSON list.');
      }

      final parsedLayers = <VectorLayer>[];
      for (final rawLayer in rawLayers) {
        if (rawLayer is! Map<String, dynamic>) {
          throw const FormatException('Invalid layer object in "layers".');
        }
        parsedLayers.add(_parseLayer(rawLayer));
      }

      if (parsedLayers.isEmpty) {
        parsedLayers.add(
          VectorLayer(id: IdGenerator.layerId(), name: 'Layer 1'),
        );
      }

      final requestedActiveLayer = docMap['activeLayerId'] as String?;
      final hasRequestedLayer =
          parsedLayers.any((l) => l.id == requestedActiveLayer);
      final resolvedActiveLayerId =
          hasRequestedLayer ? requestedActiveLayer! : parsedLayers.last.id;

      final createdAt =
          DateTime.tryParse((docMap['createdAt'] as String?) ?? '');
      final updatedAt =
          DateTime.tryParse((docMap['updatedAt'] as String?) ?? '');

      final reconstructed = VectorDocument(
        id: id,
        name: (name == null || name.isEmpty) ? 'Untitled Artwork' : name,
        version: EditorConstants.currentSchemaVersion,
        width: width,
        height: height,
        backgroundColor: bgColor,
        layers: parsedLayers,
        activeLayerId: resolvedActiveLayerId,
        assets: parsedAssets,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      // Verify all ImageObject asset references resolve cleanly
      for (final obj in reconstructed.allObjectsRecursive) {
        if (obj is ImageObject &&
            reconstructed.findAssetById(obj.assetId) == null) {
          throw ProjectFormatException(
            'Image object "${obj.name}" references missing asset "${obj.assetId}".',
          );
        }
      }

      return reconstructed;
    } on ProjectStorageException {
      rethrow;
    } on FormatException catch (e) {
      throw ProjectFormatException('Corrupted project data: ${e.message}', e);
    } catch (e) {
      throw ProjectFormatException('Failed to read project data: $e', e);
    }
  }

  VectorLayer _parseLayer(Map<String, dynamic> json) {
    final layerId = (json['id'] as String?)?.trim();
    if (layerId == null || layerId.isEmpty) {
      throw const FormatException('Layer requires a non-empty id.');
    }

    final rawObjects = json['objects'];
    if (rawObjects != null && rawObjects is! List) {
      throw const FormatException('Layer "objects" must be a list.');
    }

    final objects = <VectorObject>[];
    if (rawObjects is List) {
      for (final item in rawObjects) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Malformed vector object entry.');
        }
        final obj = parseVectorObject(item).withLayerId(layerId);
        objects.add(obj);
      }
    }

    return VectorLayer(
      id: layerId,
      name: (json['name'] as String?) ?? 'Layer',
      visible: json['visible'] is bool ? json['visible'] as bool : true,
      locked: json['locked'] is bool ? json['locked'] as bool : false,
      expanded: json['expanded'] is bool ? json['expanded'] as bool : true,
      objects: objects,
    );
  }

  VectorObject parseVectorObject(Map<String, dynamic> json) {
    final rawId = json['id'];
    if (rawId is! String || rawId.trim().isEmpty) {
      throw const FormatException('Vector object is missing a valid id.');
    }

    final objType = VectorObjectType.fromName(json['type'] as String?);
    switch (objType) {
      case VectorObjectType.rectangle:
        return RectangleObject.fromJson(json);
      case VectorObjectType.ellipse:
        return EllipseObject.fromJson(json);
      case VectorObjectType.line:
        return LineObject.fromJson(json);
      case VectorObjectType.polygon:
        return PolygonObject.fromJson(json);
      case VectorObjectType.star:
        return StarObject.fromJson(json);
      case VectorObjectType.path:
        return PathObject.fromJson(json);
      case VectorObjectType.text:
        return TextObject.fromJson(json);
      case VectorObjectType.image:
        return ImageObject.fromJson(json);
      case VectorObjectType.group:
        return GroupObject.fromJson(
          json,
          childParser: parseVectorObject,
        );
    }
  }
}
