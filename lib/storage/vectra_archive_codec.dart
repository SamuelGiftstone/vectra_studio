import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'storage_exceptions.dart';

/// Standard PKZIP (`PK\x03\x04`) reader and writer used to bundle `manifest.json`
/// and binary `assets/<id>.<ext>` files inside a portable single-file `.vectra` archive.
///
/// Supports both Method 0 (STORE) and Method 8 (DEFLATE) without third-party
/// archive version conflicts.
class VectraArchiveCodec {
  VectraArchiveCodec._();

  static const int _localFileHeaderSig = 0x04034B50;
  static const int _centralDirHeaderSig = 0x02014B50;
  static const int _endOfCentralDirSig = 0x06054B50;

  static final Uint32List _crcTable = _buildCrc32Table();

  /// Returns `true` when [bytes] begins with the standard PKZIP magic header (`PK\x03\x04`).
  static bool isZipArchive(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  /// Packs a map of relative archive paths (`manifest.json`, `assets/...`) into
  /// a valid PKZIP byte stream.
  static Uint8List encodeArchive(
    Map<String, Uint8List> files, {
    Set<String> compressPaths = const <String>{'manifest.json'},
  }) {
    final out = BytesBuilder(copy: false);
    final centralDir = BytesBuilder(copy: false);

    var localOffset = 0;
    var entryCount = 0;

    for (final entry in files.entries) {
      final pathBytes = Uint8List.fromList(utf8.encode(entry.key));
      final rawData = entry.value;
      final crc = computeCrc32(rawData);

      final shouldDeflate =
          compressPaths.contains(entry.key) && rawData.length > 64;
      final Uint8List storedData;
      final int method;
      if (shouldDeflate) {
        final deflated = Uint8List.fromList(
          ZLibCodec(raw: true, level: 6).encode(rawData),
        );
        if (deflated.length < rawData.length) {
          storedData = deflated;
          method = 8; // DEFLATE
        } else {
          storedData = rawData;
          method = 0; // STORE
        }
      } else {
        storedData = rawData;
        method = 0; // STORE
      }

      // Local File Header (30 bytes + filename)
      final localHeader = ByteData(30);
      localHeader.setUint32(0, _localFileHeaderSig, Endian.little);
      localHeader.setUint16(4, 20, Endian.little); // version needed (2.0)
      localHeader.setUint16(6, 0x0800, Endian.little); // UTF-8 filename flag
      localHeader.setUint16(8, method, Endian.little);
      localHeader.setUint16(10, 0, Endian.little); // mod time
      localHeader.setUint16(12, 0x21, Endian.little); // mod date
      localHeader.setUint32(14, crc, Endian.little);
      localHeader.setUint32(18, storedData.length, Endian.little);
      localHeader.setUint32(22, rawData.length, Endian.little);
      localHeader.setUint16(26, pathBytes.length, Endian.little);
      localHeader.setUint16(28, 0, Endian.little); // extra length

      final localHeaderBytes = localHeader.buffer.asUint8List();
      out.add(localHeaderBytes);
      out.add(pathBytes);
      out.add(storedData);

      // Central Directory Header (46 bytes + filename)
      final centralHeader = ByteData(46);
      centralHeader.setUint32(0, _centralDirHeaderSig, Endian.little);
      centralHeader.setUint16(4, 20, Endian.little); // version made by
      centralHeader.setUint16(6, 20, Endian.little); // version needed
      centralHeader.setUint16(8, 0x0800, Endian.little); // UTF-8 flag
      centralHeader.setUint16(10, method, Endian.little);
      centralHeader.setUint16(12, 0, Endian.little);
      centralHeader.setUint16(14, 0x21, Endian.little);
      centralHeader.setUint32(16, crc, Endian.little);
      centralHeader.setUint32(20, storedData.length, Endian.little);
      centralHeader.setUint32(24, rawData.length, Endian.little);
      centralHeader.setUint16(28, pathBytes.length, Endian.little);
      centralHeader.setUint16(30, 0, Endian.little); // extra len
      centralHeader.setUint16(32, 0, Endian.little); // comment len
      centralHeader.setUint16(34, 0, Endian.little); // disk number
      centralHeader.setUint16(36, 0, Endian.little); // internal attrs
      centralHeader.setUint32(38, 0, Endian.little); // external attrs
      centralHeader.setUint32(42, localOffset, Endian.little);

      centralDir.add(centralHeader.buffer.asUint8List());
      centralDir.add(pathBytes);

      localOffset += 30 + pathBytes.length + storedData.length;
      entryCount++;
    }

    final centralDirBytes = centralDir.takeBytes();
    final centralDirOffset = localOffset;
    out.add(centralDirBytes);

    // End of Central Directory Record (22 bytes)
    final eocd = ByteData(22);
    eocd.setUint32(0, _endOfCentralDirSig, Endian.little);
    eocd.setUint16(4, 0, Endian.little);
    eocd.setUint16(6, 0, Endian.little);
    eocd.setUint16(8, entryCount, Endian.little);
    eocd.setUint16(10, entryCount, Endian.little);
    eocd.setUint32(12, centralDirBytes.length, Endian.little);
    eocd.setUint32(16, centralDirOffset, Endian.little);
    eocd.setUint16(20, 0, Endian.little);

    out.add(eocd.buffer.asUint8List());
    return out.takeBytes();
  }

  /// Extracts all file entries from a PKZIP `.vectra` archive bundle.
  static Map<String, Uint8List> decodeArchive(Uint8List archiveBytes) {
    if (!isZipArchive(archiveBytes)) {
      throw const ProjectFormatException(
        'Invalid .vectra archive header (not a valid ZIP container).',
      );
    }

    final view = ByteData.sublistView(archiveBytes);
    // Locate End of Central Directory record scanning backward from the end
    var eocdOffset = -1;
    final minSearch = (archiveBytes.length - 65557).clamp(0, archiveBytes.length);
    for (var i = archiveBytes.length - 22; i >= minSearch; i--) {
      if (view.getUint32(i, Endian.little) == _endOfCentralDirSig) {
        eocdOffset = i;
        break;
      }
    }

    if (eocdOffset < 0) {
      throw const ProjectFormatException(
        'Corrupted .vectra archive: missing End of Central Directory record.',
      );
    }

    final totalEntries = view.getUint16(eocdOffset + 10, Endian.little);
    final centralDirOffset = view.getUint32(eocdOffset + 16, Endian.little);

    if (centralDirOffset > archiveBytes.length) {
      throw const ProjectFormatException(
        'Corrupted .vectra archive: central directory offset out of range.',
      );
    }

    final extracted = <String, Uint8List>{};
    var cursor = centralDirOffset;

    for (var i = 0; i < totalEntries; i++) {
      if (cursor + 46 > archiveBytes.length) {
        throw const ProjectFormatException(
          'Corrupted .vectra archive: truncated central directory entry.',
        );
      }
      final sig = view.getUint32(cursor, Endian.little);
      if (sig != _centralDirHeaderSig) {
        throw const ProjectFormatException(
          'Corrupted .vectra archive: invalid central directory signature.',
        );
      }

      final method = view.getUint16(cursor + 10, Endian.little);
      final expectedCrc = view.getUint32(cursor + 16, Endian.little);
      final compressedSize = view.getUint32(cursor + 20, Endian.little);
      final nameLen = view.getUint16(cursor + 28, Endian.little);
      final extraLen = view.getUint16(cursor + 30, Endian.little);
      final commentLen = view.getUint16(cursor + 32, Endian.little);
      final localHeaderOffset = view.getUint32(cursor + 42, Endian.little);

      final nameStart = cursor + 46;
      final nameEnd = nameStart + nameLen;
      if (nameEnd > archiveBytes.length) {
        throw const ProjectFormatException(
          'Corrupted .vectra archive: entry name out of bounds.',
        );
      }

      final entryName = utf8.decode(
        archiveBytes.sublist(nameStart, nameEnd),
        allowMalformed: true,
      );
      cursor = nameEnd + extraLen + commentLen;

      // Read corresponding Local File Header
      if (localHeaderOffset + 30 > archiveBytes.length) {
        throw const ProjectFormatException(
          'Corrupted .vectra archive: local header offset out of bounds.',
        );
      }
      final localSig = view.getUint32(localHeaderOffset, Endian.little);
      if (localSig != _localFileHeaderSig) {
        throw const ProjectFormatException(
          'Corrupted .vectra archive: invalid local header signature.',
        );
      }
      final localNameLen = view.getUint16(localHeaderOffset + 26, Endian.little);
      final localExtraLen = view.getUint16(localHeaderOffset + 28, Endian.little);
      final dataStart = localHeaderOffset + 30 + localNameLen + localExtraLen;
      final dataEnd = dataStart + compressedSize;

      if (dataEnd > archiveBytes.length) {
        throw ProjectFormatException(
          'Corrupted .vectra archive: truncated payload for "$entryName".',
        );
      }

      final payloadSlice = Uint8List.sublistView(archiveBytes, dataStart, dataEnd);
      final Uint8List uncompressed;
      if (method == 0) {
        uncompressed = Uint8List.fromList(payloadSlice);
      } else if (method == 8) {
        try {
          uncompressed = Uint8List.fromList(
            ZLibCodec(raw: true).decode(payloadSlice),
          );
        } catch (e) {
          throw ProjectFormatException(
            'Failed to decompress "$entryName" in .vectra archive: $e',
            e,
          );
        }
      } else {
        throw ProjectFormatException(
          'Unsupported ZIP compression method ($method) for "$entryName".',
        );
      }

      final actualCrc = computeCrc32(uncompressed);
      if (actualCrc != expectedCrc) {
        throw ProjectFormatException(
          'CRC32 checksum mismatch for "$entryName" in .vectra archive.',
        );
      }

      // Skip directory entries and prevent path traversal
      if (!entryName.endsWith('/') && !entryName.contains('..')) {
        extracted[entryName] = uncompressed;
      }
    }

    return extracted;
  }

  static int computeCrc32(Uint8List bytes) {
    var crc = 0xFFFFFFFF;
    for (var i = 0; i < bytes.length; i++) {
      crc = _crcTable[(crc ^ bytes[i]) & 0xFF] ^ (crc >>> 8);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static Uint32List _buildCrc32Table() {
    final table = Uint32List(256);
    for (var i = 0; i < 256; i++) {
      var c = i;
      for (var k = 0; k < 8; k++) {
        if ((c & 1) != 0) {
          c = 0xEDB88320 ^ (c >>> 1);
        } else {
          c = c >>> 1;
        }
      }
      table[i] = c;
    }
    return table;
  }
}
