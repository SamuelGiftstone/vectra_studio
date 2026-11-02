import 'package:flutter_test/flutter_test.dart';
import 'package:vectora_studio_software/math/bezier_math.dart';
import 'package:vectora_studio_software/math/vec2.dart';
import 'package:vectora_studio_software/models/anchor_point.dart';

void main() {
  group('Cubic Bézier curve evaluation & tangents', () {
    const p0 = Vec2(0.0, 0.0);
    const p1 = Vec2(0.0, 100.0);
    const p2 = Vec2(100.0, 100.0);
    const p3 = Vec2(100.0, 0.0);

    test('evaluates endpoints and midpoint accurately', () {
      expect(BezierMath.evaluateCubic(p0, p1, p2, p3, 0.0), p0);
      expect(BezierMath.evaluateCubic(p0, p1, p2, p3, 1.0), p3);

      // At t = 0.5 for symmetric arch: x = 50, y = 3/8*100 + 3/8*100 = 75
      final mid = BezierMath.evaluateCubic(p0, p1, p2, p3, 0.5);
      expect(mid.x, closeTo(50.0, 1e-6));
      expect(mid.y, closeTo(75.0, 1e-6));
    });

    test('computes exact start, midpoint, and end derivatives', () {
      // B'(0) = 3 * (p1 - p0) = (0, 300)
      final startTan = BezierMath.cubicTangent(p0, p1, p2, p3, 0.0);
      expect(startTan.x, closeTo(0.0, 1e-6));
      expect(startTan.y, closeTo(300.0, 1e-6));

      // B'(0.5) is horizontal (dy = 0, dx > 0) at peak of arch
      final midTan = BezierMath.cubicTangent(p0, p1, p2, p3, 0.5);
      expect(midTan.y, closeTo(0.0, 1e-6));
      expect(midTan.x, greaterThan(0.0));

      // B'(1) = 3 * (p3 - p2) = (0, -300)
      final endTan = BezierMath.cubicTangent(p0, p1, p2, p3, 1.0);
      expect(endTan.x, closeTo(0.0, 1e-6));
      expect(endTan.y, closeTo(-300.0, 1e-6));
    });

    test('computes tight analytical bounding box excluding off-curve control hull', () {
      // Control points reach y = 100, but actual curve apex is y = 75!
      final bounds = BezierMath.cubicBounds(p0, p1, p2, p3);
      expect(bounds.minX, closeTo(0.0, 1e-6));
      expect(bounds.maxX, closeTo(100.0, 1e-6));
      expect(bounds.minY, closeTo(0.0, 1e-6));
      expect(bounds.maxY, closeTo(75.0, 1e-6));
    });

    test('splits cubic curve via De Casteljau while preserving exact locus', () {
      final split = BezierMath.splitCubic(p0, p1, p2, p3, 0.4);
      final joinPoint = BezierMath.evaluateCubic(p0, p1, p2, p3, 0.4);

      expect(split.left.p3.x, closeTo(joinPoint.x, 1e-6));
      expect(split.left.p3.y, closeTo(joinPoint.y, 1e-6));
      expect(split.right.p0.x, closeTo(joinPoint.x, 1e-6));
      expect(split.right.p0.y, closeTo(joinPoint.y, 1e-6));

      // u = 0.5 on left segment corresponds to t = 0.2 on original curve
      final leftMid = BezierMath.evaluateCubic(
        split.left.p0,
        split.left.p1,
        split.left.p2,
        split.left.p3,
        0.5,
      );
      final origAt02 = BezierMath.evaluateCubic(p0, p1, p2, p3, 0.2);
      expect(leftMid.x, closeTo(origAt02.x, 1e-6));
      expect(leftMid.y, closeTo(origAt02.y, 1e-6));

      // u = 0.5 on right segment corresponds to t = 0.4 + 0.5 * 0.6 = 0.7 on original
      final rightMid = BezierMath.evaluateCubic(
        split.right.p0,
        split.right.p1,
        split.right.p2,
        split.right.p3,
        0.5,
      );
      final origAt07 = BezierMath.evaluateCubic(p0, p1, p2, p3, 0.7);
      expect(rightMid.x, closeTo(origAt07.x, 1e-6));
      expect(rightMid.y, closeTo(origAt07.y, 1e-6));
    });

    test('computes curve hit-test distance accurately', () {
      // Point (50, 75) lies directly on the curve apex
      final onCurveDist = BezierMath.distanceToCubic(
        const Vec2(50.0, 75.0),
        p0,
        p1,
        p2,
        p3,
      );
      expect(onCurveDist, lessThan(0.5));

      final farDist = BezierMath.distanceToCubic(
        const Vec2(50.0, 10.0),
        p0,
        p1,
        p2,
        p3,
      );
      expect(farDist, greaterThan(30.0));
    });
  });

  group('AnchorPoint smooth vs corner handle alignment', () {
    test('keeps opposite handle collinear when dragging smooth node handle', () {
      const anchor = AnchorPoint(
        id: 'a1',
        position: Vec2(100, 100),
        handleIn: Vec2(-20, 0),
        handleOut: Vec2(40, 0),
        nodeType: NodeType.smooth,
      );

      // Drag outgoing handle straight down to (100, 150) -> handleOut = (0, 50)
      // Smooth node preserves handleIn length (20) while pointing opposite -> (0, -20)
      final updated = anchor.withWorldHandleOut(const Vec2(100, 150));
      expect(updated.handleOut.x, closeTo(0.0, 1e-6));
      expect(updated.handleOut.y, closeTo(50.0, 1e-6));
      expect(updated.handleIn.x, closeTo(0.0, 1e-6));
      expect(updated.handleIn.y, closeTo(-20.0, 1e-6));
    });

    test('breaks handle alignment into corner node when breakSmooth is true', () {
      const anchor = AnchorPoint(
        id: 'a1',
        position: Vec2(100, 100),
        handleIn: Vec2(-20, 0),
        handleOut: Vec2(40, 0),
        nodeType: NodeType.smooth,
      );

      final broken = anchor.withWorldHandleOut(
        const Vec2(100, 150),
        breakSmooth: true,
      );
      expect(broken.nodeType, NodeType.corner);
      expect(broken.handleIn, const Vec2(-20, 0));
      expect(broken.handleOut, const Vec2(0, 50));
    });
  });
}
