import 'dart:convert';
import 'dart:typed_data';

import '../core/utils/validation_utils.dart';

/// Embedded binary raster asset stored inside a [VectorDocument] and persisted
/// inside `.vectra` archive bundles under `assets/<id>.<ext>`.
class ImageAsset {
  final String id;
  final String name;
  final String mimeType;
  final String extension;
  final Uint8List bytes;
  final int naturalWidth;
  final int naturalHeight;

  const ImageAsset({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.extension,
    required this.bytes,
    required this.naturalWidth,
    required this.naturalHeight,
  });

  /// Relative archive entry path inside a `.vectra` ZIP bundle.
  String get archiveEntryPath {
    final cleanExt = extension.replaceAll('.', '').trim().toLowerCase();
    return 'assets/$id.${cleanExt.isEmpty ? 'png' : cleanExt}';
  }

  /// Builds a data URI suitable for standalone SVG `<image href="data:..."/>` export.
  String toDataUri() {
    final encoded = base64Encode(bytes);
    return 'data:$mimeType;base64,$encoded';
  }

  /// Serializes metadata only (without bloating `manifest.json` with binary bytes).
  /// When [includeInlineBytes] is `true` (e.g. for plain-JSON string tests), base64
  /// bytes are included as a fallback.
  Map<String, dynamic> toMetadataJson({bool includeInlineBytes = false}) {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'mimeType': mimeType,
      'extension': extension,
      'archivePath': archiveEntryPath,
      'byteLength': bytes.length,
      'naturalWidth': naturalWidth,
      'naturalHeight': naturalHeight,
      if (includeInlineBytes) 'inlineBase64': base64Encode(bytes),
    };
  }

  factory ImageAsset.fromMetadataAndBytes(
    Map<String, dynamic> json, {
    Uint8List? archiveBytes,
  }) {
    final id = (json['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) {
      throw const FormatException('ImageAsset metadata is missing "id".');
    }

    Uint8List? resolvedBytes = archiveBytes;
    if (resolvedBytes == null || resolvedBytes.isEmpty) {
      final inlineBase64 = json['inlineBase64'] as String?;
      if (inlineBase64 != null && inlineBase64.isNotEmpty) {
        resolvedBytes = Uint8List.fromList(base64Decode(inlineBase64));
      }
    }

    if (resolvedBytes == null || resolvedBytes.isEmpty) {
      throw FormatException(
        'Missing binary asset payload for ImageAsset "$id".',
      );
    }

    final width = ValidationUtils.requireInt(
      json['naturalWidth'],
      'naturalWidth',
      min: 1,
      max: 32768,
    );
    final height = ValidationUtils.requireInt(
      json['naturalHeight'],
      'naturalHeight',
      min: 1,
      max: 32768,
    );

    final ext = ((json['extension'] as String?) ?? 'png')
        .replaceAll('.', '')
        .trim()
        .toLowerCase();

    return ImageAsset(
      id: id,
      name: ((json['name'] as String?) ?? 'Image').trim(),
      mimeType: ((json['mimeType'] as String?) ?? 'image/png').trim(),
      extension: ext.isEmpty ? 'png' : ext,
      bytes: resolvedBytes,
      naturalWidth: width,
      naturalHeight: height,
    );
  }
}
