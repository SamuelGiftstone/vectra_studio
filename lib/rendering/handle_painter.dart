import 'dart:ui';

import '../core/constants/app_colors.dart';
import '../core/constants/app_dimensions.dart';
import '../editor/tool_controller.dart';
import '../math/bezier_math.dart';
import '../math/bounds2d.dart';
import '../math/transform_math.dart';
import '../math/vec2.dart';
import '../models/anchor_point.dart';
import '../models/path_object.dart';
import '../models/vector_object.dart';
import 'path_builder_utils.dart';
import 'viewport_transform.dart';

/// Screen-space vector handle, outline, node, and Pen preview drawing routines.
class HandlePainter {
  HandlePainter._();

  /// Draws a subtle outline around a hovered unselected object.
  static void paintHoverOutline(
    Canvas canvas,
    VectorObject object,
    ViewportTransform viewport,
  ) {
    canvas.save();
    viewport.applyToCanvas(canvas);
    if (object.rotation.abs() > 1e-9) {
      final c = object.center;
      canvas.translate(c.x, c.y);
      canvas.rotate(object.rotation);
      canvas.translate(-c.x, -c.y);
    }
    final path = PathBuilderUtils.buildLocalPath(object);
    final paint = Paint()
      ..color = AppColors.hoverOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 / viewport.zoom;
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  /// Draws rotated selection bounding box, 8 resize handles, and top rotation knob.
  static void paintSingleSelectionHandles(
    Canvas canvas,
    VectorObject object,
    ViewportTransform viewport, {
    required bool showTransformHandles,
  }) {
    final bounds = object.localBounds;
    final pivot = object.center;
    final rot = object.rotation;

    final tl = viewport.docToScreen(bounds.topLeft, pivot: pivot, rotationRadians: rot);
    final tr = viewport.docToScreen(bounds.topRight, pivot: pivot, rotationRadians: rot);
    final br = viewport.docToScreen(bounds.bottomRight, pivot: pivot, rotationRadians: rot);
    final bl = viewport.docToScreen(bounds.bottomLeft, pivot: pivot, rotationRadians: rot);

    final boxPath = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    final outlinePaint = Paint()
      ..color = AppColors.selectionOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawPath(boxPath, outlinePaint);

    if (!showTransformHandles) return;

    // Rotation stem + circular handle above topCenter
    final topCenterDoc = TransformMath.handleLocalPosition(
      bounds,
      ResizeHandle.topCenter,
    );
    final rotKnobDoc = Vec2(
      topCenterDoc.x,
      topCenterDoc.y - viewport.screenToDocLength(AppDimensions.rotationHandleOffset),
    );
    final topCenterScreen = viewport.docToScreen(
      topCenterDoc,
      pivot: pivot,
      rotationRadians: rot,
    );
    final rotKnobScreen = viewport.docToScreen(
      rotKnobDoc,
      pivot: pivot,
      rotationRadians: rot,
    );

    canvas.drawLine(topCenterScreen, rotKnobScreen, outlinePaint);

    final handleFillPaint = Paint()
      ..color = AppColors.handleFill
      ..style = PaintingStyle.fill;
    final handleStrokePaint = Paint()
      ..color = AppColors.handleStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(
      rotKnobScreen,
      AppDimensions.rotationHandleRadius,
      handleFillPaint,
    );
    canvas.drawCircle(
      rotKnobScreen,
      AppDimensions.rotationHandleRadius,
      handleStrokePaint,
    );

    // 8 square resize handles
    const half = AppDimensions.resizeHandleSize * 0.5;
    for (final handle in ResizeHandle.values) {
      final docPos = TransformMath.handleLocalPosition(bounds, handle);
      final screenPos = viewport.docToScreen(
        docPos,
        pivot: pivot,
        rotationRadians: rot,
      );
      final rect = Rect.fromCenter(
        center: screenPos,
        width: half * 2,
        height: half * 2,
      );
      canvas.drawRect(rect, handleFillPaint);
      canvas.drawRect(rect, handleStrokePaint);
    }
  }

  /// Draws group bounding box when multiple objects are selected simultaneously.
  static void paintMultiSelectionBounds(
    Canvas canvas,
    List<VectorObject> objects,
    ViewportTransform viewport,
  ) {
    if (objects.isEmpty) return;
    var unionBounds = objects.first.worldBounds;
    for (var i = 1; i < objects.length; i++) {
      final obj = objects[i];
      paintHoverOutline(canvas, obj, viewport);
      unionBounds = unionBounds.union(obj.worldBounds);
    }
    paintHoverOutline(canvas, objects.first, viewport);

    final tl = viewport.docToScreen(unionBounds.topLeft);
    final br = viewport.docToScreen(unionBounds.bottomRight);
    final rect = Rect.fromPoints(tl, br);
    final paint = Paint()
      ..color = AppColors.selectionOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(rect, paint);
  }

  /// Draws editable anchors and incoming/outgoing cubic Bézier handles for [PathObject].
  static void paintPathNodeOverlay(
    Canvas canvas,
    PathObject pathObject,
    ViewportTransform viewport, {
    int? selectedAnchorIndex,
  }) {
    // Highlight path spine
    paintHoverOutline(canvas, pathObject, viewport);

    final pivot = pathObject.center;
    final rot = pathObject.rotation;

    final handleLinePaint = Paint()
      ..color = AppColors.bezierHandleLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final handleKnobFill = Paint()
      ..color = AppColors.bezierHandleFill
      ..style = PaintingStyle.fill;

    final anchorWhiteFill = Paint()
      ..color = AppColors.handleFill
      ..style = PaintingStyle.fill;

    final anchorSelectedFill = Paint()
      ..color = AppColors.selectedAnchorFill
      ..style = PaintingStyle.fill;

    final anchorStroke = Paint()
      ..color = AppColors.handleStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    for (var i = 0; i < pathObject.anchors.length; i++) {
      final anchor = pathObject.anchors[i];
      final isSelected = i == selectedAnchorIndex;
      final anchorScreen = viewport.docToScreen(
        anchor.position,
        pivot: pivot,
        rotationRadians: rot,
      );

      if (anchor.hasHandleIn) {
        final inScreen = viewport.docToScreen(
          anchor.worldHandleIn,
          pivot: pivot,
          rotationRadians: rot,
        );
        canvas.drawLine(anchorScreen, inScreen, handleLinePaint);
        canvas.drawCircle(
          inScreen,
          AppDimensions.bezierHandleRadius,
          handleKnobFill,
        );
      }

      if (anchor.hasHandleOut) {
        final outScreen = viewport.docToScreen(
          anchor.worldHandleOut,
          pivot: pivot,
          rotationRadians: rot,
        );
        canvas.drawLine(anchorScreen, outScreen, handleLinePaint);
        canvas.drawCircle(
          outScreen,
          AppDimensions.bezierHandleRadius,
          handleKnobFill,
        );
      }

      // Corner nodes render as crisp squares; Smooth/Symmetric nodes render as circles
      final fillPaint = isSelected ? anchorSelectedFill : anchorWhiteFill;
      if (anchor.nodeType == NodeType.corner) {
        final rect = Rect.fromCenter(
          center: anchorScreen,
          width: AppDimensions.anchorNodeSize,
          height: AppDimensions.anchorNodeSize,
        );
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, anchorStroke);
      } else {
        const radius = AppDimensions.anchorNodeSize * 0.55;
        canvas.drawCircle(anchorScreen, radius, fillPaint);
        canvas.drawCircle(anchorScreen, radius, anchorStroke);
      }
    }
  }

  /// Draws the in-progress Pen Tool construction curve, handles, rubber-band preview,
  /// and path-close target ring.
  static void paintPenConstructionOverlay(
    Canvas canvas,
    TransientToolState transient,
    ViewportTransform viewport,
  ) {
    final anchors = transient.penAnchors;
    if (anchors.isEmpty) return;

    // 1. Committed segments inside the unfinished pen path
    if (anchors.length >= 2) {
      final path = Path();
      final firstScreen = viewport.docToScreen(anchors.first.position);
      path.moveTo(firstScreen.dx, firstScreen.dy);

      for (var i = 0; i < anchors.length - 1; i++) {
        final a = anchors[i];
        final b = anchors[i + 1];
        final p1 = viewport.docToScreen(a.worldHandleOut);
        final p2 = viewport.docToScreen(b.worldHandleIn);
        final p3 = viewport.docToScreen(b.position);
        path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
      }

      final spinePaint = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawPath(path, spinePaint);
    }

    // 2. Live rubber-band preview segment from last anchor to cursor
    final previewPt = transient.penPreviewPoint;
    if (previewPt != null && !transient.isPenDraggingHandle) {
      final last = anchors.last;
      final targetDoc =
          transient.isPenHoveringClose ? anchors.first.position : previewPt;
      final targetHandleIn = transient.isPenHoveringClose
          ? anchors.first.worldHandleIn
          : targetDoc;

      final samples = BezierMath.sampleCubic(
        last.position,
        last.worldHandleOut,
        targetHandleIn,
        targetDoc,
        steps: 24,
      );
      if (samples.length >= 2) {
        final previewPath = Path();
        final s0 = viewport.docToScreen(samples.first);
        previewPath.moveTo(s0.dx, s0.dy);
        for (var i = 1; i < samples.length; i++) {
          final si = viewport.docToScreen(samples[i]);
          previewPath.lineTo(si.dx, si.dy);
        }
        final rubberPaint = Paint()
          ..color = AppColors.accent.withOpacity(0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawPath(previewPath, rubberPaint);
      }
    }

    // 3. Draw anchors and handles of unfinished path
    final handleLinePaint = Paint()
      ..color = AppColors.bezierHandleLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final handleFill = Paint()
      ..color = AppColors.bezierHandleFill
      ..style = PaintingStyle.fill;
    final nodeFill = Paint()
      ..color = AppColors.handleFill
      ..style = PaintingStyle.fill;
    final nodeStroke = Paint()
      ..color = AppColors.handleStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var i = 0; i < anchors.length; i++) {
      final a = anchors[i];
      final aScreen = viewport.docToScreen(a.position);
      if (a.hasHandleIn) {
        final inScreen = viewport.docToScreen(a.worldHandleIn);
        canvas.drawLine(aScreen, inScreen, handleLinePaint);
        canvas.drawCircle(inScreen, 3.8, handleFill);
      }
      if (a.hasHandleOut) {
        final outScreen = viewport.docToScreen(a.worldHandleOut);
        canvas.drawLine(aScreen, outScreen, handleLinePaint);
        canvas.drawCircle(outScreen, 3.8, handleFill);
      }

      final rect = Rect.fromCenter(center: aScreen, width: 7.5, height: 7.5);
      canvas.drawRect(rect, nodeFill);
      canvas.drawRect(rect, nodeStroke);
    }

    // 4. Highlight close ring around first anchor when hovered
    if (transient.isPenHoveringClose && anchors.length >= 2) {
      final firstScreen = viewport.docToScreen(anchors.first.position);
      final ringPaint = Paint()
        ..color = AppColors.success
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(firstScreen, 9.0, ringPaint);
    }
  }

  /// Draws rectangular selection marquee box.
  static void paintMarquee(
    Canvas canvas,
    Bounds2D marqueeDocBounds,
    ViewportTransform viewport,
  ) {
    final tl = viewport.docToScreen(marqueeDocBounds.topLeft);
    final br = viewport.docToScreen(marqueeDocBounds.bottomRight);
    final rect = Rect.fromPoints(tl, br);

    final fillPaint = Paint()
      ..color = AppColors.marqueeFill
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppColors.marqueeStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, strokePaint);
  }
}
