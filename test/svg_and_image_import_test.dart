import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vectora_studio_software/models/ellipse_object.dart';
import 'package:vectora_studio_software/models/group_object.dart';
import 'package:vectora_studio_software/models/line_object.dart';
import 'package:vectora_studio_software/models/path_object.dart';
import 'package:vectora_studio_software/models/rectangle_object.dart';
import 'package:vectora_studio_software/models/text_object.dart';
import 'package:vectora_studio_software/models/vector_document.dart';
import 'package:vectora_studio_software/rendering/font_catalog.dart';
import 'package:vectora_studio_software/storage/image_import_service.dart';
import 'package:vectora_studio_software/storage/storage_exceptions.dart';
import 'package:vectora_studio_software/storage/svg_import_service.dart';
import 'package:vectora_studio_software/storage/svg_path_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FontCatalog.ensureOfflineSafeConfiguration();

  group('SvgPathParser W3C path data commands', () {
    test('parses M, L, H, V, C, S, Q, T, A, and Z into editable Bézier subpaths', () {
      const d =
          'M 10 20 L 60 20 H 100 V 70 C 100 90, 80 110, 60 110 '
          'S 20 90, 20 70 Q 10 50, 20 35 T 30 25 A 15 15 0 0 1 10 20 Z';

      final subpaths = SvgPathParser.parse(d);
      expect(subpaths.length, 1);
      expect(subpaths.single.closed, isTrue);
      expect(subpaths.single.anchors.length, greaterThanOrEqualTo(8));
    });
  });

  group('SvgImportService editable vector import & security checks', () {
    const svgImporter = SvgImportService();

    test('converts SVG groups, shapes, paths, text, CSS styles, and transforms into editable objects', () {
      const sampleSvg = '''
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600" viewBox="0 0 800 600">
  <g id="hero_badge" transform="translate(50, 40)">
    <rect id="bg_box" x="10" y="20" width="200" height="100" rx="12" style="fill:#A78BFA;stroke:#1E1B4B;stroke-width:3" />
    <circle cx="60" cy="70" r="24" fill="#10B981" />
    <line x1="100" y1="50" x2="180" y2="90" stroke="#EF4444" stroke-width="2" />
    <polygon points="220,20 260,80 180,80" fill="#F59E0B" />
    <path d="M 10 150 C 40 120, 90 180, 130 150" fill="none" stroke="#111827" stroke-width="2.5" />
    <text x="100" y="75" font-family="Inter" font-size="22" font-weight="bold" fill="#FFFFFF">Launch</text>
  </g>
</svg>
''';

      final doc = VectorDocument.createNew(width: 800, height: 600);
      final imported = svgImporter.parseSvgToObjects(
        sampleSvg,
        currentDocument: doc,
        sourceName: 'Badge',
      );

      expect(imported, isNotEmpty);
      final rootGroup = imported.single as GroupObject;
      expect(rootGroup.children.length, 6);

      expect(rootGroup.children[0], isA<RectangleObject>());
      final rect = rootGroup.children[0] as RectangleObject;
      // Translated by (50, 40): x = 10 + 50 = 60, y = 20 + 40 = 60
      expect(rect.x, closeTo(60.0, 1e-5));
      expect(rect.y, closeTo(60.0, 1e-5));
      expect(rect.cornerRadius, closeTo(12.0, 1e-5));

      expect(rootGroup.children[1], isA<EllipseObject>());
      expect(rootGroup.children[2], isA<LineObject>());
      expect(rootGroup.children[3], isA<PathObject>()); // <polygon> -> closed PathObject
      expect(rootGroup.children[4], isA<PathObject>()); // <path> -> Bézier PathObject
      expect(rootGroup.children[5], isA<TextObject>());

      final text = rootGroup.children[5] as TextObject;
      expect(text.text, 'Launch');
      expect(text.fontWeightValue, 700);
    });

    test('rejects malicious <script>, <!ENTITY XXE, and malformed SVG XML cleanly', () {
      final doc = VectorDocument.createNew();

      const xxeSvg = '''
<!DOCTYPE svg [ <!ENTITY xxe SYSTEM "file:///etc/passwd"> ]>
<svg xmlns="http://www.w3.org/2000/svg"><text>&xxe;</text></svg>
''';
      expect(
        () => svgImporter.parseSvgToObjects(xxeSvg, currentDocument: doc),
        throwsA(isA<ProjectFormatException>()),
      );

      const scriptSvg = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <script>alert(1)</script>
  <rect width="50" height="50" />
</svg>
''';
      expect(
        () => svgImporter.parseSvgToObjects(scriptSvg, currentDocument: doc),
        throwsA(isA<ProjectFormatException>()),
      );

      expect(
        () => svgImporter.parseSvgToObjects('<svg><unclosed>', currentDocument: doc),
        throwsA(isA<ProjectFormatException>()),
      );
    });
  });

  group('ImageImportService raster decoding & validation', () {
    const imageImporter = ImageImportService();

    test('decodes valid PNG and JPEG bytes, preserves aspect ratio, and rejects corrupted data', () {
      final doc = VectorDocument.createNew(width: 1000, height: 800);

      // Synthesize a real 160x80 RGBA PNG image in memory
      final rawCanvas = img.Image(width: 160, height: 80);
      img.fill(rawCanvas, color: img.ColorRgba8(167, 139, 250, 255));
      final pngBytes = Uint8List.fromList(img.encodePng(rawCanvas));

      final importedPng = imageImporter.importImageFromBytes(
        bytes: pngBytes,
        fileName: 'hero_banner.png',
        currentDocument: doc,
      );

      expect(importedPng.asset.naturalWidth, 160);
      expect(importedPng.asset.naturalHeight, 80);
      expect(importedPng.asset.mimeType, 'image/png');
      expect(importedPng.imageObject.preserveAspectRatio, isTrue);
      expect(
        importedPng.imageObject.width / importedPng.imageObject.height,
        closeTo(2.0, 1e-6),
      );

      // Synthesize a real 120x120 JPEG image in memory
      final jpgCanvas = img.Image(width: 120, height: 120);
      img.fill(jpgCanvas, color: img.ColorRgb8(16, 185, 129));
      final jpgBytes = Uint8List.fromList(img.encodeJpg(jpgCanvas, quality: 90));

      final importedJpg = imageImporter.importImageFromBytes(
        bytes: jpgBytes,
        fileName: 'avatar.jpg',
        currentDocument: doc,
      );
      expect(importedJpg.asset.naturalWidth, 120);
      expect(importedJpg.asset.mimeType, 'image/jpeg');

      // Corrupted / non-image bytes must fail cleanly with ProjectFormatException
      expect(
        () => imageImporter.importImageFromBytes(
          bytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6]),
          fileName: 'broken.png',
          currentDocument: doc,
        ),
        throwsA(isA<ProjectFormatException>()),
      );
    });
  });
}
