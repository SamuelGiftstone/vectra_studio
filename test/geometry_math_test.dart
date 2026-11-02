import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:vectora_studio_software/math/bounds2d.dart';
import 'package:vectora_studio_software/math/geometry_math.dart';
import 'package:vectora_studio_software/math/hit_test_math.dart';
import 'package:vectora_studio_software/math/polygon_math.dart';
import 'package:vectora_studio_software/math/transform_math.dart';
import 'package:vectora_studio_software/math/vec2.dart';
import 'package:vectora_studio_software/models/ellipse_object.dart';
import 'package:vectora_studio_software/models/fill_style.dart';
import 'package:vectora_studio_software/models/line_object.dart';
import 'package:vectora_studio_software/models/rectangle_object.dart';
import 'package:vectora_studio_software/models/stroke_style.dart';

void main() {
  group('Vec2 & GeometryMath vector operations', () {
    test('performs addition, subtraction, scaling, dot product, and length', () {
      const a = Vec2(3.0, 4.0);
      const b = Vec2(-1.0, 2.0);

      expect(GeometryMath.add(a, b), const Vec2(2.0, 6.0));
      expect(GeometryMath.subtract(a, b), const Vec2(4.0, 2.0));
      expect(GeometryMath.scale(a, 2.5), const Vec2(7.5, 10.0));
      expect(GeometryMath.dot(a, b), closeTo(5.0, 1e-9));
      expect(GeometryMath.length(a), closeTo(5.0, 1e-9));
      expect(GeometryMath.distance(a, const Vec2(0.0, 0.0)), closeTo(5.0, 1e-9));
    });

    test('rotates a point 90 degrees around an arbitrary pivot', () {
      const pivot = Vec2(100.0, 100.0);
      const point = Vec2(150.0, 100.0);
      final rotated = GeometryMath.rotatePoint(point, pivot, math.pi / 2.0);

      expect(rotated.x, closeTo(100.0, 1e-6));
      expect(rotated.y, closeTo(150.0, 1e-6));
    });
  });

  group('Point-to-segment distance', () {
    test('computes exact perpendicular distance for interior projection', () {
      const a = Vec2(10.0, 20.0);
      const b = Vec2(110.0, 20.0);
      const query = Vec2(55.0, 32.5);

      expect(GeometryMath.distanceToSegment(query, a, b), closeTo(12.5, 1e-6));
    });

    test('clamps closest point to segment endpoints when outside span', () {
      const a = Vec2(0.0, 0.0);
      const b = Vec2(10.0, 0.0);

      expect(
        GeometryMath.distanceToSegment(const Vec2(-3.0, 4.0), a, b),
        closeTo(5.0, 1e-6),
      );
      expect(
        GeometryMath.distanceToSegment(const Vec2(13.0, -4.0), a, b),
        closeTo(5.0, 1e-6),
      );
    });

    test('handles degenerate zero-length segment safely', () {
      const p = Vec2(5.0, 5.0);
      expect(
        GeometryMath.distanceToSegment(const Vec2(8.0, 9.0), p, p),
        closeTo(5.0, 1e-6),
      );
    });
  });

  group('Polygon & Star hit testing', () {
    test('ray-casting accurately distinguishes interior and exterior of hexagon', () {
      final bounds = Bounds2D.fromLTWH(0, 0, 200, 200);
      final hex = PolygonMath.generatePolygonVertices(bounds, 6);

      expect(hex.length, 6);
      expect(PolygonMath.isPointInPolygon(const Vec2(100, 100), hex), isTrue);
      expect(PolygonMath.isPointInPolygon(const Vec2(5, 5), hex), isFalse);
      expect(PolygonMath.isPointInPolygon(const Vec2(250, 100), hex), isFalse);
    });

    test('ray-casting handles concave 5-point star valleys accurately', () {
      final bounds = Bounds2D.fromLTWH(0, 0, 200, 200);
      final star = PolygonMath.generateStarVertices(
        bounds,
        points: 5,
        innerRadiusRatio: 0.35,
      );

      expect(star.length, 10);
      // Center is inside star
      expect(PolygonMath.isPointInPolygon(const Vec2(100, 100), star), isTrue);
      // Top apex at (100, ~5) is inside top star point
      expect(PolygonMath.isPointInPolygon(const Vec2(100, 10), star), isTrue);
      // Concave valley between top apex and upper-right point is outside
      expect(PolygonMath.isPointInPolygon(const Vec2(145, 25), star), isFalse);
    });
  });

  group('Viewport & Document coordinate transformations', () {
    test('round-trips screen and document coordinates across zoom and pan', () {
      const pan = Offset(140.0, -65.0);
      const zoom = 2.5;
      const originalDoc = Vec2(320.4, 180.8);

      final screenPt = TransformMath.documentToScreen(
        originalDoc,
        panOffset: pan,
        zoom: zoom,
      );
      final roundTrippedDoc = TransformMath.screenToDocument(
        screenPt,
        panOffset: pan,
        zoom: zoom,
      );

      expect(roundTrippedDoc.x, closeTo(originalDoc.x, 1e-6));
      expect(roundTrippedDoc.y, closeTo(originalDoc.y, 1e-6));
    });

    test('computes aspect-locked resized bounds from corner handle', () {
      final initial = Bounds2D.fromLTWH(100, 100, 200, 100); // 2:1 aspect
      final resized = TransformMath.computeResizedBounds(
        initialBounds: initial,
        handle: ResizeHandle.bottomRight,
        localPointer: const Vec2(400, 180), // width=300 -> height should become 150
        keepAspectRatio: true,
      );

      expect(resized.width, closeTo(300.0, 1e-6));
      expect(resized.height, closeTo(150.0, 1e-6));
    });
  });

  group('HitTestMath vector shape hit testing', () {
    test('hits filled rectangle, ellipse, and stroked line accurately', () {
      const rect = RectangleObject(
        id: 'r1',
        name: 'Rect',
        layerId: 'l1',
        x: 50,
        y: 50,
        width: 100,
        height: 80,
        fill: FillStyle.defaultFill,
        stroke: StrokeStyle.defaultStroke,
      );
      expect(HitTestMath.hitTestObject(rect, const Vec2(100, 90)), isTrue);
      expect(HitTestMath.hitTestObject(rect, const Vec2(10, 10)), isFalse);

      const ellipse = EllipseObject(
        id: 'e1',
        name: 'Oval',
        layerId: 'l1',
        x: 200,
        y: 200,
        width: 100,
        height: 100,
        fill: FillStyle.defaultFill,
        stroke: StrokeStyle.defaultStroke,
      );
      expect(HitTestMath.hitTestObject(ellipse, const Vec2(250, 250)), isTrue);
      // Corner of bounding box (201, 201) is outside circle of radius 50
      expect(
        HitTestMath.hitTestObject(ellipse, const Vec2(201, 201), tolerance: 1.0),
        isFalse,
      );

      const line = LineObject(
        id: 'ln1',
        name: 'Line',
        layerId: 'l1',
        start: Vec2(0, 0),
        end: Vec2(100, 100),
        fill: FillStyle.none,
        stroke: StrokeStyle.defaultStroke,
      );
      expect(
        HitTestMath.hitTestObject(line, const Vec2(50, 52), tolerance: 4.0),
        isTrue,
      );
      expect(
        HitTestMath.hitTestObject(line, const Vec2(20, 80), tolerance: 4.0),
        isFalse,
      );
    });
  });
}
