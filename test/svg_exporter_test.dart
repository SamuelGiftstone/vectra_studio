import 'dart:math' as math;

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
import 'package:vectora_studio_software/storage/svg_exporter.dart';

void main() {
  const exporter = SvgExporter();

  group('SvgExporter vector markup serialization', () {
    test('exports SVG elements for rect, ellipse, line, polygon, star, and cubic Bézier path', () {
      var doc = VectorDocument.createNew(
        name: 'Icons & Curves <Test>',
        width: 800,
        height: 600,
        backgroundColor: const Color(0xFFFFFFFF),
      );

      doc = doc
          .addObject(
            RectangleObject(
              id: 'r1',
              name: 'Box "A"',
              layerId: '',
              x: 20,
              y: 30,
              width: 100,
              height: 60,
              cornerRadius: 8,
              rotation: math.pi / 4, // 45 degrees
              fill: const FillStyle(color: Color(0xFFA78BFA)),
              stroke: const StrokeStyle(color: Color(0xFF111827), width: 2),
            ),
          )
          .addObject(
            const EllipseObject(
              id: 'e1',
              name: 'Circle',
              layerId: '',
              x: 200,
              y: 100,
              width: 80,
              height: 50,
              fill: FillStyle(color: Color(0xFF10B981)),
              stroke: StrokeStyle(color: Color(0xFF064E3B), width: 1.5),
            ),
          )
          .addObject(
            const LineObject(
              id: 'l1',
              name: 'Connector',
              layerId: '',
              start: Vec2(10, 500),
              end: Vec2(300, 520),
              fill: FillStyle.none,
              stroke: StrokeStyle(color: Color(0xFFEF4444), width: 3),
            ),
          )
          .addObject(
            const PolygonObject(
              id: 'p1',
              name: 'Pentagon',
              layerId: '',
              x: 350,
              y: 50,
              width: 90,
              height: 90,
              sides: 5,
              fill: FillStyle.defaultFill,
              stroke: StrokeStyle.defaultStroke,
            ),
          )
          .addObject(
            const StarObject(
              id: 's1',
              name: 'Star',
              layerId: '',
              x: 480,
              y: 50,
              width: 90,
              height: 90,
              points: 5,
              innerRadiusRatio: 0.45,
              fill: FillStyle.defaultFill,
              stroke: StrokeStyle.defaultStroke,
            ),
          )
          .addObject(
            PathObject(
              id: 'bezier_1',
              name: 'Wave',
              layerId: '',
              closed: true,
              fill: FillStyle.defaultFill,
              stroke: StrokeStyle.defaultStroke,
              anchors: const <AnchorPoint>[
                AnchorPoint(
                  id: 'n1',
                  position: Vec2(100, 300),
                  handleOut: Vec2(50, -60),
                  nodeType: NodeType.smooth,
                ),
                AnchorPoint(
                  id: 'n2',
                  position: Vec2(250, 300),
                  handleIn: Vec2(-50, 60),
                  nodeType: NodeType.smooth,
                ),
                AnchorPoint(
                  id: 'n3',
                  position: Vec2(175, 420),
                  nodeType: NodeType.corner,
                ),
              ],
            ),
          )
          .addObject(
            const RectangleObject(
              id: 'hidden_rect',
              name: 'Hidden Guide',
              layerId: '',
              x: 0,
              y: 0,
              width: 50,
              height: 50,
              visible: false,
              fill: FillStyle.defaultFill,
              stroke: StrokeStyle.defaultStroke,
            ),
          );

      final svg = exporter.export(doc);

      expect(svg, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(svg, contains('<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600" viewBox="0 0 800 600">'));
      // Escaped XML special characters
      expect(svg, contains('<title>Icons &amp; Curves &lt;Test&gt;</title>'));
      expect(svg, contains('data-name="Box &quot;A&quot;"'));

      // Shapes & attributes
      expect(svg, contains('<rect id="r1"'));
      expect(svg, contains('rx="8" ry="8"'));
      expect(svg, contains('fill="#A78BFA"'));
      expect(svg, contains('transform="rotate(45 70 60)"'));

      expect(svg, contains('<ellipse id="e1"'));
      expect(svg, contains('cx="240" cy="125" rx="40" ry="25"'));

      expect(svg, contains('<line id="l1"'));
      expect(svg, contains('x1="10" y1="500" x2="300" y2="520"'));
      expect(svg, contains('fill="none" stroke="#EF4444" stroke-width="3"'));

      expect(svg, contains('<polygon id="p1"'));
      expect(svg, contains('<polygon id="s1"'));

      // Cubic Bézier path command C + linear L + close Z
      expect(svg, contains('<path id="bezier_1"'));
      expect(svg, contains('M 100 300 C 150 240, 200 360, 250 300 L 175 420 L 100 300 Z'));

      // Hidden object must not be exported
      expect(svg, isNot(contains('hidden_rect')));
    });
  });
}
