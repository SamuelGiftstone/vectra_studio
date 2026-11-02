import 'dart:math' as math;

import '../core/constants/app_dimensions.dart';
import '../models/anchor_point.dart';
import '../models/ellipse_object.dart';
import '../models/group_object.dart';
import '../models/image_object.dart';
import '../models/line_object.dart';
import '../models/path_object.dart';
import '../models/polygon_object.dart';
import '../models/rectangle_object.dart';
import '../models/star_object.dart';
import '../models/text_object.dart';
import '../models/vector_document.dart';
import '../models/vector_object.dart';
import 'bezier_math.dart';
import 'bounds2d.dart';
import 'geometry_math.dart';
import 'polygon_math.dart';
import 'transform_math.dart';
import 'vec2.dart';

/// Result of testing control handles or anchors on a selected [PathObject].
enum NodeHitPart {
  anchor,
  handleIn,
  handleOut,
}

class NodeHitResult {
  final int anchorIndex;
  final NodeHitPart part;

  const NodeHitResult({
    required this.anchorIndex,
    required this.part,
  });
}

/// Geometry-accurate hit testing in document coordinates for shapes, paths,
/// text blocks, raster images, groups, selection handles, rotation handles, and Bézier nodes.
class HitTestMath {
  HitTestMath._();

  /// Hit-tests the top-most visible, unlocked [VectorObject] at [worldPoint].
  static VectorObject? hitTestDocument(
    VectorDocument document,
    Vec2 worldPoint, {
    required double zoom,
    double screenTolerance = 7.0,
  }) {
    final docTolerance = screenTolerance / math.max(0.05, zoom);

    for (var l = document.layers.length - 1; l >= 0; l--) {
      final layer = document.layers[l];
      if (!layer.visible || layer.locked) continue;

      for (var i = layer.objects.length - 1; i >= 0; i--) {
        final obj = layer.objects[i];
        if (!obj.visible || obj.locked) continue;
        if (hitTestObject(obj, worldPoint, tolerance: docTolerance)) {
          return obj;
        }
      }
    }
    return null;
  }

  /// Hit-tests an individual [VectorObject] using its actual vector or layout geometry.
  static bool hitTestObject(
    VectorObject object,
    Vec2 worldPoint, {
    double tolerance = 5.0,
  }) {
    final strokeHalf = object.stroke.isVisible ? object.stroke.width * 0.5 : 0.0;
    final effectiveTol = tolerance + strokeHalf;

    // Fast coarse reject in world bounds
    if (!object.worldBounds.inflate(effectiveTol + 4.0).containsPoint(worldPoint)) {
      return false;
    }

    // Transform pointer into the object's unrotated local frame
    final localPt = TransformMath.worldToLocal(
      worldPoint,
      object.center,
      object.rotation,
    );

    if (object is GroupObject) {
      for (var i = object.children.length - 1; i >= 0; i--) {
        final child = object.children[i];
        if (!child.visible) continue;
        if (hitTestObject(child, localPt, tolerance: tolerance)) {
          return true;
        }
      }
      return false;
    }

    if (object is TextObject) {
      return object.localBounds.containsPoint(localPt, tolerance: effectiveTol);
    }

    if (object is ImageObject) {
      return object.localBounds.containsPoint(localPt, tolerance: effectiveTol);
    }

    final hasFill = object.fill.isEnabled && object.fill.opacity > 0.0;

    if (object is RectangleObject) {
      if (hasFill &&
          GeometryMath.isPointInRect(
            localPt,
            left: object.x,
            top: object.y,
            width: object.width,
            height: object.height,
            cornerRadius: object.effectiveCornerRadius,
          )) {
        return true;
      }
      final corners = object.localBounds.corners;
      return PolygonMath.distanceToPolyline(localPt, corners, closed: true) <=
          effectiveTol;
    }

    if (object is EllipseObject) {
      final center = object.localBounds.center;
      final rx = object.rx;
      final ry = object.ry;
      if (hasFill &&
          GeometryMath.isPointInEllipse(
            localPt,
            center: center,
            rx: rx + tolerance * 0.25,
            ry: ry + tolerance * 0.25,
          )) {
        return true;
      }
      final outerHit = GeometryMath.isPointInEllipse(
        localPt,
        center: center,
        rx: rx + effectiveTol,
        ry: ry + effectiveTol,
      );
      final innerHit = rx > effectiveTol &&
          ry > effectiveTol &&
          GeometryMath.isPointInEllipse(
            localPt,
            center: center,
            rx: rx - effectiveTol,
            ry: ry - effectiveTol,
          );
      return outerHit && !innerHit;
    }

    if (object is LineObject) {
      return GeometryMath.hitTestSegment(
        localPt,
        object.start,
        object.end,
        tolerance: effectiveTol,
      );
    }

    if (object is PolygonObject) {
      final verts = object.localVertices;
      if (hasFill && PolygonMath.isPointInPolygon(localPt, verts)) {
        return true;
      }
      return PolygonMath.distanceToPolyline(localPt, verts, closed: true) <=
          effectiveTol;
    }

    if (object is StarObject) {
      final verts = object.localVertices;
      if (hasFill && PolygonMath.isPointInPolygon(localPt, verts)) {
        return true;
      }
      return PolygonMath.distanceToPolyline(localPt, verts, closed: true) <=
          effectiveTol;
    }

    if (object is PathObject) {
      final segs = object.segments;
      for (final seg in segs) {
        final d = BezierMath.distanceToCubic(
          localPt,
          seg.p0,
          seg.p1,
          seg.p2,
          seg.p3,
        );
        if (d <= effectiveTol) {
          return true;
        }
      }
      if (object.closed && hasFill && object.anchors.length >= 3) {
        final sampled = object.sampleOutline(stepsPerSegment: 16);
        if (PolygonMath.isPointInPolygon(localPt, sampled)) {
          return true;
        }
      }
      return false;
    }

    return false;
  }


  /// Hit-tests the 8 resize handles of [object] in document space.
  static ResizeHandle? hitTestResizeHandles(
    VectorObject object,
    Vec2 worldPoint, {
    required double zoom,
    double screenRadius = 8.5,
  }) {
    final docRadius = screenRadius / math.max(0.05, zoom);
    final localPt = TransformMath.worldToLocal(
      worldPoint,
      object.center,
      object.rotation,
    );
    final bounds = object.localBounds;

    for (final handle in ResizeHandle.values) {
      final handlePos = TransformMath.handleLocalPosition(bounds, handle);
      if (localPt.distanceTo(handlePos) <= docRadius) {
        return handle;
      }
    }
    return null;
  }

  /// Hit-tests the rotation handle positioned above top-center of [object].
  static bool hitTestRotationHandle(
    VectorObject object,
    Vec2 worldPoint, {
    required double zoom,
    double screenRadius = 9.0,
  }) {
    final safeZoom = math.max(0.05, zoom);
    final docRadius = screenRadius / safeZoom;
    final docOffset = AppDimensions.rotationHandleOffset / safeZoom;
    final localPt = TransformMath.worldToLocal(
      worldPoint,
      object.center,
      object.rotation,
    );
    final bounds = object.localBounds;
    final rotPos = Vec2(
      (bounds.minX + bounds.maxX) * 0.5,
      bounds.minY - docOffset,
    );
    return localPt.distanceTo(rotPos) <= docRadius;
  }

  /// Hit-tests Bézier handles first, then anchor points of [pathObject].
  static NodeHitResult? hitTestPathNodes(
    PathObject pathObject,
    Vec2 worldPoint, {
    required double zoom,
    int? activeAnchorIndex,
    double screenRadius = 8.5,
  }) {
    final docRadius = screenRadius / math.max(0.05, zoom);
    final localPt = TransformMath.worldToLocal(
      worldPoint,
      pathObject.center,
      pathObject.rotation,
    );

    // 1. Prioritize visible control handles so overlapping/close handles remain draggable
    for (var i = 0; i < pathObject.anchors.length; i++) {
      final AnchorPoint anchor = pathObject.anchors[i];
      if (anchor.hasHandleOut &&
          localPt.distanceTo(anchor.worldHandleOut) <= docRadius) {
        return NodeHitResult(anchorIndex: i, part: NodeHitPart.handleOut);
      }
      if (anchor.hasHandleIn &&
          localPt.distanceTo(anchor.worldHandleIn) <= docRadius) {
        return NodeHitResult(anchorIndex: i, part: NodeHitPart.handleIn);
      }
    }

    // 2. Test anchor positions
    for (var i = pathObject.anchors.length - 1; i >= 0; i--) {
      final anchor = pathObject.anchors[i];
      if (localPt.distanceTo(anchor.position) <= docRadius) {
        return NodeHitResult(anchorIndex: i, part: NodeHitPart.anchor);
      }
    }

    return null;
  }
}
