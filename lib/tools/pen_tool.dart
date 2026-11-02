import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../core/constants/editor_constants.dart';
import '../core/utils/id_generator.dart';
import '../editor/editor_controller.dart';
import '../editor/tool_controller.dart';
import '../math/vec2.dart';
import '../models/anchor_point.dart';
import 'editor_tool.dart';

/// Interactive Pen Tool (`P`) for constructing open and closed cubic Bézier [PathObject]s.
class PenTool extends EditorTool {
  bool _isDraggingNewAnchorHandles = false;
  bool _closingOnPointerUp = false;

  @override
  EditorToolType get type => EditorToolType.pen;

  @override
  SystemMouseCursor cursor(EditorController controller) =>
      SystemMouseCursors.precise;

  @override
  void onPointerHover(EditorController controller, ToolPointerData event) {
    final transient = controller.toolController.state.transient;
    if (!transient.hasActivePenPath) return;

    final canClose = _isWithinFirstAnchor(
      transient.penAnchors,
      event.docPosition,
      event.zoom,
    );

    controller.toolController.updateTransient(
      (t) => t.copyWith(
        penPreviewPoint: event.docPosition,
        isPenHoveringClose: canClose,
      ),
    );
  }

  @override
  void onPointerDown(EditorController controller, ToolPointerData event) {
    final transient = controller.toolController.state.transient;
    final anchors = List<AnchorPoint>.of(transient.penAnchors);

    // Clicking the first anchor when >= 2 anchors exist closes and commits the path
    if (_isWithinFirstAnchor(anchors, event.docPosition, event.zoom)) {
      _closingOnPointerUp = true;
      _isDraggingNewAnchorHandles = false;
      return;
    }

    _closingOnPointerUp = false;

    // Avoid accidental duplicate coincident anchor when double-clicking to finish
    if (anchors.isNotEmpty &&
        anchors.last.position.distanceTo(event.docPosition) <
            (2.0 / math.max(0.05, event.zoom))) {
      _isDraggingNewAnchorHandles = true;
      return;
    }

    final newAnchor = AnchorPoint(
      id: IdGenerator.anchorId(),
      position: event.docPosition,
      handleIn: Vec2.zero,
      handleOut: Vec2.zero,
      nodeType: NodeType.corner,
    );

    anchors.add(newAnchor);
    _isDraggingNewAnchorHandles = true;

    controller.toolController.updateTransient(
      (t) => t.copyWith(
        penAnchors: anchors,
        penPreviewPoint: event.docPosition,
        isPenHoveringClose: false,
        isPenDraggingHandle: false,
      ),
    );
  }

  @override
  void onPointerMove(EditorController controller, ToolPointerData event) {
    if (!_isDraggingNewAnchorHandles) return;

    final transient = controller.toolController.state.transient;
    if (transient.penAnchors.isEmpty) return;

    final anchors = List<AnchorPoint>.of(transient.penAnchors);
    final last = anchors.last;
    final outVec = event.docPosition - last.position;
    final minDragDoc = 3.0 / math.max(0.05, event.zoom);

    if (outVec.length < minDragDoc) {
      return;
    }

    // Dragging pulls symmetric outgoing and incoming Bézier handles
    anchors[anchors.length - 1] = last.copyWith(
      handleOut: outVec,
      handleIn: event.isAltPressed ? last.handleIn : -outVec,
      nodeType: event.isAltPressed ? NodeType.corner : NodeType.smooth,
    );

    controller.toolController.updateTransient(
      (t) => t.copyWith(
        penAnchors: anchors,
        penPreviewPoint: event.docPosition,
        isPenDraggingHandle: true,
      ),
    );
  }

  @override
  void onPointerUp(EditorController controller, ToolPointerData event) {
    if (_closingOnPointerUp) {
      _closingOnPointerUp = false;
      _isDraggingNewAnchorHandles = false;
      controller.commitActivePenPath(closed: true);
      return;
    }

    _isDraggingNewAnchorHandles = false;
    controller.toolController.updateTransient(
      (t) => t.copyWith(isPenDraggingHandle: false),
    );
  }

  @override
  void onDoubleTap(EditorController controller, ToolPointerData event) {
    _isDraggingNewAnchorHandles = false;
    _closingOnPointerUp = false;
    if (controller.toolController.state.transient.penAnchors.length >= 2) {
      controller.commitActivePenPath(closed: false);
    }
  }

  @override
  void onCancel(EditorController controller) {
    _isDraggingNewAnchorHandles = false;
    _closingOnPointerUp = false;
    controller.toolController.clearTransient();
    controller.documentController.setStatusMessage('Canceled Pen path');
  }

  bool _isWithinFirstAnchor(
    List<AnchorPoint> anchors,
    Vec2 docPos,
    double zoom,
  ) {
    if (anchors.length < 2) return false;
    final closeRadiusDoc =
        EditorConstants.penCloseScreenRadius / math.max(0.05, zoom);
    return anchors.first.position.distanceTo(docPos) <= closeRadiusDoc;
  }
}
