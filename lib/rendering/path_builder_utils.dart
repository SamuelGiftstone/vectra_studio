import 'dart:ui';

import '../models/ellipse_object.dart';
import '../models/group_object.dart';
import '../models/image_object.dart';
import '../models/line_object.dart';
import '../models/path_object.dart';
import '../models/polygon_object.dart';
import '../models/rectangle_object.dart';
import '../models/star_object.dart';
import '../models/text_object.dart';
import '../models/vector_object.dart';

/// Builds Flutter [Path] geometry in local document coordinates from [VectorObject] models.
class PathBuilderUtils {
  PathBuilderUtils._();

  static Path buildLocalPath(VectorObject object) {
    final path = Path();

    if (object is RectangleObject) {
      final rect = Rect.fromLTWH(object.x, object.y, object.width, object.height);
      final r = object.effectiveCornerRadius;
      if (r > 1e-4) {
        path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
      } else {
        path.addRect(rect);
      }
      return path;
    }

    if (object is EllipseObject) {
      path.addOval(
        Rect.fromLTWH(object.x, object.y, object.width, object.height),
      );
      return path;
    }

    if (object is LineObject) {
      path.moveTo(object.start.x, object.start.y);
      path.lineTo(object.end.x, object.end.y);
      return path;
    }

    if (object is PolygonObject) {
      final verts = object.localVertices;
      if (verts.isNotEmpty) {
        path.moveTo(verts.first.x, verts.first.y);
        for (var i = 1; i < verts.length; i++) {
          path.lineTo(verts[i].x, verts[i].y);
        }
        path.close();
      }
      return path;
    }

    if (object is StarObject) {
      final verts = object.localVertices;
      if (verts.isNotEmpty) {
        path.moveTo(verts.first.x, verts.first.y);
        for (var i = 1; i < verts.length; i++) {
          path.lineTo(verts[i].x, verts[i].y);
        }
        path.close();
      }
      return path;
    }

    if (object is PathObject) {
      if (object.anchors.isEmpty) return path;
      final first = object.anchors.first;
      path.moveTo(first.position.x, first.position.y);
      for (final seg in object.segments) {
        if (seg.isLinear) {
          path.lineTo(seg.p3.x, seg.p3.y);
        } else {
          path.cubicTo(
            seg.p1.x,
            seg.p1.y,
            seg.p2.x,
            seg.p2.y,
            seg.p3.x,
            seg.p3.y,
          );
        }
      }
      if (object.closed && object.anchors.length >= 2) {
        path.close();
      }
      return path;
    }

    if (object is TextObject ||
        object is ImageObject ||
        object is GroupObject) {
      path.addRect(object.localBounds.toRect());
      return path;
    }

    return path;
  }
}

