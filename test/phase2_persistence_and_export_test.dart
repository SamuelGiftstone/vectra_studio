import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vectora_studio_software/models/fill_style.dart';
import 'package:vectora_studio_software/models/group_object.dart';
import 'package:vectora_studio_software/models/image_object.dart';
import 'package:vectora_studio_software/models/rectangle_object.dart';
import 'package:vectora_studio_software/models/stroke_style.dart';
import 'package:vectora_studio_software/models/text_object.dart';
import 'package:vectora_studio_software/models/vector_document.dart';
import 'package:vectora_studio_software/rendering/font_catalog.dart';
import 'package:vectora_studio_software/storage/document_deserializer.dart';
import 'package:vectora_studio_software/storage/document_export_service.dart';
import 'package:vectora_studio_software/storage/document_serializer.dart';
import 'package:vectora_studio_software/storage/image_import_service.dart';
import 'package:vectora_studio_software/storage/storage_exceptions.dart';
import 'package:vectora_studio_software/storage/vectra_archive_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FontCatalog.ensureOfflineSafeConfiguration();

  const serializer = DocumentSerializer();
  const deserializer = DocumentDeserializer();
  const imageImporter = ImageImportService();
  const exportService = DocumentExportService();

  group('Phase 2 .vectra PKZIP Archive Bundle & Binary Asset Persistence', () {
    test('stores raster assets as binary entries inside .vectra ZIP without JSON base64 bloat and round-trips bit-for-bit', () {
      var doc = VectorDocument.createNew(
        name: 'Composite Poster',
        width: 640,
        height: 480,
      );

      // Create binary PNG asset
      final bitmap = img.Image(width: 64, height: 48);
      img.fill(bitmap, color: img.ColorRgba8(59, 130, 246, 255));
      final pngBytes = Uint8List.fromList(img.encodePng(bitmap));

      final imported = imageImporter.importImageFromBytes(
        bytes: pngBytes,
        fileName: 'photo.png',
        currentDocument: doc,
      );

      doc = doc
          .addAsset(imported.asset)
          .addObject(imported.imageObject)
          .addObject(
            GroupObject(
              id: 'grp_caption',
              name: 'Caption Group',
              layerId: '',
              children: const <TextObject>[
                TextObject(
                  id: 'txt_caption',
                  name: 'Caption Text',
                  layerId: '',
                  text: 'Portable Archive Format',
                  x: 40,
                  y: 400,
                  fontSize: 24,
                  fill: FillStyle(color: Color(0xFF111827)),
                ),
              ],
            ),
          );

      final archiveBytes = serializer.serializeToProjectBytes(doc);
      expect(VectraArchiveCodec.isZipArchive(archiveBytes), isTrue);

      // Inspect raw archive entries: manifest.json + assets/<id>.png
      final entries = VectraArchiveCodec.decodeArchive(archiveBytes);
      expect(entries.containsKey('manifest.json'), isTrue);
      expect(entries.containsKey(imported.asset.archiveEntryPath), isTrue);

      final manifestJson = utf8.decode(entries['manifest.json']!);
      // Verify manifest.json has ZERO inline base64 image bloat!
      expect(manifestJson, isNot(contains('inlineBase64')));
      expect(
        entries[imported.asset.archiveEntryPath],
        equals(pngBytes),
      );

      // Reopen from .vectra archive bytes and verify every object & asset
      final reopened = deserializer.deserializeBytes(archiveBytes);
      expect(reopened.name, 'Composite Poster');
      expect(reopened.assets.length, 1);
      expect(reopened.assets[imported.asset.id]!.bytes, equals(pngBytes));

      final reopenedImg =
          reopened.findObjectById(imported.imageObject.id) as ImageObject;
      expect(reopenedImg.naturalWidth, 64);
      expect(reopenedImg.naturalHeight, 48);

      final reopenedGroup =
          reopened.findObjectById('grp_caption') as GroupObject;
      expect(reopenedGroup.children.single, isA<TextObject>());
      expect(
        (reopenedGroup.children.single as TextObject).text,
        'Portable Archive Format',
      );
    });

    test('detects missing referenced image asset inside corrupted .vectra archive', () {
      var doc = VectorDocument.createNew();
      doc = doc.addObject(
        const ImageObject(
          id: 'orphan_img',
          name: 'Missing Photo',
          layerId: '',
          assetId: 'asset_missing_999',
          x: 0,
          y: 0,
          width: 100,
          height: 100,
          naturalWidth: 100,
          naturalHeight: 100,
        ),
      );

      final rawJson = serializer.serialize(doc, inlineAssetBytes: false);
      expect(
        () => deserializer.deserialize(rawJson),
        throwsA(isA<ProjectFormatException>()),
      );
    });
  });

  group('DocumentExportService SVG, PNG, and JPEG export pipeline', () {
    test('encodes clean SVG, transparent PNG, and opaque JPEG from VectorDocument', () async {
      var doc = VectorDocument.createNew(
        name: 'Export Verification',
        width: 200,
        height: 150,
        backgroundColor: const Color(0xFFFFFFFF),
      );
      doc = doc.addObject(
        const RectangleObject(
          id: 'r_export',
          name: 'Violet Tile',
          layerId: '',
          x: 20,
          y: 20,
          width: 160,
          height: 110,
          cornerRadius: 12,
          fill: FillStyle(color: Color(0xFFA78BFA)),
          stroke: StrokeStyle(color: Color(0xFF1E1B4B), width: 2),
        ),
      );

      // 1. SVG Export
      final svgBytes = await exportService.encodeToBytes(
        doc,
        const ExportConfig(format: ExportFormat.svg, scale: 2.0),
      );
      final svgText = utf8.decode(svgBytes);
      expect(svgText, contains('width="400" height="300" viewBox="0 0 200 150"'));
      expect(svgText, contains('<rect id="r_export"'));
      // Verify editor tag labels are not rendered as overlay widgets in exported SVG
      expect(svgText, isNot(contains('TagLayoutEngine')));

      // 2. Transparent PNG Export at 2x (400x300)
      final pngBytes = await exportService.encodeToBytes(
        doc,
        const ExportConfig(
          format: ExportFormat.png,
          scale: 2.0,
          includeBackground: false, // transparent background
        ),
      );
      final decodedPng = img.decodePng(pngBytes);
      expect(decodedPng, isNotNull);
      expect(decodedPng!.width, 400);
      expect(decodedPng.height, 300);
      // Corner pixel (2, 2) outside the (20,20) rectangle must be fully transparent (alpha == 0)
      expect(decodedPng.getPixel(2, 2).a, equals(0));

      // 3. Opaque JPEG Export at 1x (200x150)
      final jpgBytes = await exportService.encodeToBytes(
        doc,
        const ExportConfig(
          format: ExportFormat.jpeg,
          scale: 1.0,
          jpegBackgroundColor: Color(0xFFFFFFFF),
          jpegQuality: 90,
        ),
      );
      final decodedJpg = img.decodeJpg(jpgBytes);
      expect(decodedJpg, isNotNull);
      expect(decodedJpg!.width, 200);
      expect(decodedJpg.height, 150);
    });
  });
}
