import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vectora_studio_software/math/vec2.dart';
import 'package:vectora_studio_software/models/anchor_point.dart';
import 'package:vectora_studio_software/models/ellipse_object.dart';
import 'package:vectora_studio_software/models/fill_style.dart';
import 'package:vectora_studio_software/models/line_object.dart';
import 'package:vectora_studio_software/models/path_object.dart';
import 'package:vectora_studio_software/models/polygon_object.dart';
import 'package:vectora_studio_software/models/rectangle_object.dart';
import 'package:vectora_studio_software/models/star_object.dart';
import 'package:vectora_studio_software/models/stroke_style.dart';
import 'package:vectora_studio_software/models/vector_document.dart';
import 'package:vectora_studio_software/storage/document_deserializer.dart';
import 'package:vectora_studio_software/storage/document_serializer.dart';
import 'package:vectora_studio_software/storage/storage_exceptions.dart';

void main() {
  const serializer = DocumentSerializer();
  const deserializer = DocumentDeserializer();

  group('DocumentSerializer & DocumentDeserializer (.vectra)', () {
    test('round-trips full editable document with all 6 vector object types', () {
      var doc = VectorDocument.createNew(
        name: 'Brand Identity Sheet',
        width: 1600,
        height: 900,
        backgroundColor: const Color(0xFFF8FAFC),
      );
      final layer1Id = doc.activeLayerId;

      doc = doc
          .addObject(
            const RectangleObject(
              id: 'rect_1',
              name: 'Hero Card',
              layerId: '',
              x: 40,
              y: 60,
              width: 320,
              height: 180,
              cornerRadius: 16,
              rotation: 0.25,
              opacity: 0.85,
              fill: FillStyle(color: Color(0xFFA78BFA), opacity: 0.9),
              stroke: StrokeStyle(
                color: Color(0xFF1E1B4B),
                width: 3.5,
                cap: VectorStrokeCap.square,
                join: VectorStrokeJoin.bevel,
              ),
            ),
          )
          .addObject(
            const EllipseObject(
              id: 'ell_1',
              name: 'Badge Circle',
              layerId: '',
              x: 400,
              y: 120,
              width: 140,
              height: 140,
              fill: FillStyle.defaultFill,
              stroke: StrokeStyle.defaultStroke,
            ),
          )
          .addObject(
            const LineObject(
              id: 'line_1',
              name: 'Divider Rule',
              layerId: '',
              start: Vec2(50, 300),
              end: Vec2(550, 300),
              fill: FillStyle.none,
              stroke: StrokeStyle.defaultStroke,
            ),
          )
          .addLayer(customName: 'Foreground Icons');

      doc = doc
          .addObject(
            const PolygonObject(
              id: 'poly_1',
              name: 'Hex Token',
              layerId: '',
              x: 600,
              y: 80,
              width: 120,
              height: 120,
              sides: 6,
              fill: FillStyle.defaultFill,
              stroke: StrokeStyle.defaultStroke,
            ),
          )
          .addObject(
            const StarObject(
              id: 'star_1',
              name: 'Sparkle',
              layerId: '',
              x: 760,
              y: 80,
              width: 100,
              height: 100,
              points: 7,
              innerRadiusRatio: 0.42,
              fill: FillStyle.defaultFill,
              stroke: StrokeStyle.defaultStroke,
            ),
          )
          .addObject(
            PathObject(
              id: 'path_1',
              name: 'Custom Ribbon',
              layerId: '',
              closed: true,
              fill: FillStyle.defaultFill,
              stroke: StrokeStyle.defaultStroke,
              anchors: const <AnchorPoint>[
                AnchorPoint(
                  id: 'a1',
                  position: Vec2(100, 500),
                  handleIn: Vec2(-20, 10),
                  handleOut: Vec2(40, -50),
                  nodeType: NodeType.smooth,
                ),
                AnchorPoint(
                  id: 'a2',
                  position: Vec2(260, 480),
                  handleIn: Vec2(-30, -40),
                  handleOut: Vec2(30, 40),
                  nodeType: NodeType.smooth,
                ),
                AnchorPoint(
                  id: 'a3',
                  position: Vec2(200, 620),
                  nodeType: NodeType.corner,
                ),
              ],
            ),
          );

      final jsonText = serializer.serialize(doc);
      final restored = deserializer.deserialize(jsonText);

      expect(restored.id, doc.id);
      expect(restored.name, 'Brand Identity Sheet');
      expect(restored.width, 1600);
      expect(restored.height, 900);
      expect(restored.layers.length, 2);
      expect(restored.layers.first.id, layer1Id);
      expect(restored.objectCount, 6);

      final rect = restored.findObjectById('rect_1') as RectangleObject;
      expect(rect.cornerRadius, 16);
      expect(rect.rotation, closeTo(0.25, 1e-6));
      expect(rect.opacity, closeTo(0.85, 1e-6));
      expect(rect.stroke.width, closeTo(3.5, 1e-6));
      expect(rect.stroke.cap, VectorStrokeCap.square);

      final star = restored.findObjectById('star_1') as StarObject;
      expect(star.points, 7);
      expect(star.innerRadiusRatio, closeTo(0.42, 1e-6));

      final path = restored.findObjectById('path_1') as PathObject;
      expect(path.closed, isTrue);
      expect(path.anchors.length, 3);
      expect(path.anchors.first.handleOut, const Vec2(40, -50));
      expect(path.anchors.first.nodeType, NodeType.smooth);

      // Verify reopened objects remain editable
      final edited = restored.updateObject(
        'rect_1',
        (o) => o.translate(const Vec2(25, -10)),
      );
      final movedRect = edited.findObjectById('rect_1') as RectangleObject;
      expect(movedRect.x, 65);
      expect(movedRect.y, 50);
    });

    test('rejects malformed JSON and unsupported schema versions cleanly', () {
      expect(
        () => deserializer.deserialize(''),
        throwsA(isA<ProjectFormatException>()),
      );

      expect(
        () => deserializer.deserialize('{not valid json'),
        throwsA(isA<ProjectFormatException>()),
      );

      expect(
        () => deserializer.deserialize('{"format": "other-app", "schemaVersion": 1}'),
        throwsA(isA<ProjectFormatException>()),
      );

      expect(
        () => deserializer.deserialize(
          '{"format": "vectra-studio", "schemaVersion": 99, "document": {}}',
        ),
        throwsA(isA<UnsupportedDocumentVersionException>()),
      );
    });
  });
}
