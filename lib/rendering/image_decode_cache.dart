import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../models/image_asset.dart';
import '../models/vector_document.dart';

class _CachedImageEntry {
  final int byteLength;
  final Uint8List sourceBytes;
  final ui.Image image;

  const _CachedImageEntry({
    required this.byteLength,
    required this.sourceBytes,
    required this.image,
  });
}

/// Asynchronous `dart:ui` image decoder and cache notifying [DocumentPainter]
/// when embedded [ImageAsset] bytes finish decoding for GPU canvas painting.
class ImageDecodeCache extends ChangeNotifier {
  ImageDecodeCache._();

  static final ImageDecodeCache instance = ImageDecodeCache._();

  final Map<String, _CachedImageEntry> _cache = <String, _CachedImageEntry>{};
  final Set<String> _pendingIds = <String>{};

  /// Returns a decoded [ui.Image] immediately if cached, or schedules decoding
  /// and notifies listeners upon completion.
  ui.Image? getOrScheduleDecode(ImageAsset asset) {
    final existing = _cache[asset.id];
    if (existing != null &&
        existing.byteLength == asset.bytes.length &&
        identical(existing.sourceBytes, asset.bytes)) {
      return existing.image;
    }

    if (!_pendingIds.contains(asset.id)) {
      _pendingIds.add(asset.id);
      _decodeAsync(asset);
    }

    return existing?.image;
  }

  /// Ensures every [ImageAsset] referenced by [document] is decoded into a
  /// [ui.Image] before synchronous offscreen PNG/JPEG raster export runs.
  Future<void> ensureDecodedForDocument(VectorDocument document) async {
    for (final asset in document.assets.values) {
      final existing = _cache[asset.id];
      if (existing != null && existing.byteLength == asset.bytes.length) {
        continue;
      }
      await decodeNow(asset);
    }
  }

  Future<ui.Image?> decodeNow(ImageAsset asset) async {
    try {
      final codec = await ui.instantiateImageCodec(asset.bytes);
      final frame = await codec.getNextFrame();
      _cache[asset.id] = _CachedImageEntry(
        byteLength: asset.bytes.length,
        sourceBytes: asset.bytes,
        image: frame.image,
      );
      _pendingIds.remove(asset.id);
      notifyListeners();
      return frame.image;
    } catch (_) {
      _pendingIds.remove(asset.id);
      return null;
    }
  }

  Future<void> _decodeAsync(ImageAsset asset) async {
    await decodeNow(asset);
  }
}
