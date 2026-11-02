import 'dart:convert';
import 'dart:typed_data';

import '../core/constants/editor_constants.dart';
import '../core/utils/color_utils.dart';
import '../models/vector_document.dart';
import 'vectra_archive_codec.dart';

/// Serializes an editable [VectorDocument] into either `.vectra` JSON text or a
/// portable `.vectra` ZIP archive bundle (`manifest.json` + binary `assets/<id>.<ext>`).
class DocumentSerializer {
  const DocumentSerializer();

  Map<String, dynamic> toMap(
    VectorDocument document, {
    bool inlineAssetBytes = false,
  }) {
    final pruned = document.pruneUnusedAssets();
    return <String, dynamic>{
      'format': EditorConstants.projectFormatId,
      'schemaVersion': EditorConstants.currentSchemaVersion,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'document': <String, dynamic>{
        'id': pruned.id,
        'name': pruned.name,
        'version': EditorConstants.currentSchemaVersion,
        'width': pruned.width,
        'height': pruned.height,
        'backgroundColor': ColorUtils.toHex(
          pruned.backgroundColor,
          includeAlpha: true,
        ),
        'activeLayerId': pruned.activeLayerId,
        'createdAt': pruned.createdAt.toUtc().toIso8601String(),
        'updatedAt': pruned.updatedAt.toUtc().toIso8601String(),
        'assets': pruned.assets.values
            .map((a) => a.toMetadataJson(includeInlineBytes: inlineAssetBytes))
            .toList(),
        'layers': pruned.layers.map((layer) => layer.toJson()).toList(),
      },
    };
  }

  /// Serializes [document] as UTF-8 JSON text.
  ///
  /// When [inlineAssetBytes] is omitted, standalone string serialization includes
  /// inline bytes only if binary assets exist; archive serialization passes
  /// `inlineAssetBytes: false` so `manifest.json` stays lean.
  String serialize(
    VectorDocument document, {
    bool pretty = true,
    bool? inlineAssetBytes,
  }) {
    final includeInline = inlineAssetBytes ?? document.assets.isNotEmpty;
    final map = toMap(document, inlineAssetBytes: includeInline);
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(map);
    }
    return jsonEncode(map);
  }

  /// Serializes [document] into binary `.vectra` bytes:
  /// - Uses a portable PKZIP container (`manifest.json` + `assets/<id>.<ext>`)
  ///   whenever the document contains embedded binary image assets (or when
  ///   [forceArchive] is `true`), keeping `manifest.json` completely free of binary bloat.
  /// - Writes clean UTF-8 JSON bytes when no binary assets are present and [forceArchive] is `false`.
  Uint8List serializeToProjectBytes(
    VectorDocument document, {
    bool forceArchive = false,
  }) {
    final pruned = document.pruneUnusedAssets();
    if (!forceArchive && pruned.assets.isEmpty) {
      final jsonText = serialize(pruned, pretty: true, inlineAssetBytes: false);
      return Uint8List.fromList(utf8.encode(jsonText));
    }

    final manifestText = serialize(
      pruned,
      pretty: true,
      inlineAssetBytes: false,
    );
    final archiveEntries = <String, Uint8List>{
      'manifest.json': Uint8List.fromList(utf8.encode(manifestText)),
    };
    for (final asset in pruned.assets.values) {
      archiveEntries[asset.archiveEntryPath] = asset.bytes;
    }

    return VectraArchiveCodec.encodeArchive(archiveEntries);
  }
}
