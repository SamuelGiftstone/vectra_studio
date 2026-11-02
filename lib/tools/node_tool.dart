import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../core/constants/editor_constants.dart';
import '../core/utils/id_generator.dart';
import '../editor/editor_commands.dart';
import '../editor/editor_controller.dart';
import '../editor/tool_controller.dart';
import '../math/bezier_math.dart';
import '../math/hit_test_math.dart';
import '../math/transform_math.dart';
import '../math/vec2.dart';
import '../models/anchor_point.dart';
import '../models/path_object.dart';
import '../models/vector_document.dart';
import 'editor_tool.dart';

/// Interactive Node Tool (`N`) for selecting and manipulating [PathObject]
/// anchors, incoming/outgoing cubic Bézier handles, smooth/corner continuity,
/// and curve segment splitting.
class NodeTool extends EditorTool {
  String? _activePathId;
  NodeHitResult? _activeHit;
  VectorDocument? _initialDocument;
  Vec2? _dragStartLocal;
  SystemMouseCursor _cursor = SystemMouseCursors.precise;

  @override
  EditorToolType get type => EditorToolType.node;

  @override
  SystemMouseCursor cursor(EditorController controller) => _cursor;

  PathObject? _selectedPath(EditorController controller) {
    final primaryId = controller.selectionController.state.primarySelectedId;
    if (primaryId == null) return null;
    final obj = controller.currentDocument.findObjectById(primaryId);
    if (obj is PathObject &&
        controller.currentDocument.isObjectEffectivelyVisible(obj.id) &&
        !controller.currentDocument.isObjectEffectivelyLocked(obj.id)) {
      return obj;
    }
    return null;
  }

  @override
  void onPointerHover(EditorController controller, ToolPointerData event) {
    final path = _selectedPath(controller);
    if (path != null) {
      final hit = HitTestMath.hitTestPathNodes(
        path,
        event.docPosition,
        zoom: event.zoom,
        activeAnchorIndex:
            controller.selectionController.state.selectedAnchorIndex,
        screenRadius: EditorConstants.handleHitScreenRadius,
      );
      if (hit != null) {
        _cursor = SystemMouseCursors.click;
        return;
      }
    }
    _cursor = SystemMouseCursors.precise;
  }

  @override
  void onPointerDown(EditorController controller, ToolPointerData event) {
    final doc = controller.currentDocument;
    final currentPath = _selectedPath(controller);

    if (currentPath != null) {
      final nodeHit = HitTestMath.hitTestPathNodes(
        currentPath,
        event.docPosition,
        zoom: event.zoom,
        activeAnchorIndex:
            controller.selectionController.state.selectedAnchorIndex,
        screenRadius: EditorConstants.handleHitScreenRadius,
      );

      if (nodeHit != null) {
        _activePathId = currentPath.id;
        _activeHit = nodeHit;
        _initialDocument = doc;
        _dragStartLocal = TransformMath.worldToLocal(
          event.docPosition,
          currentPath.center,
          currentPath.rotation,
        );
        controller.selectionController.selectAnchor(nodeHit.anchorIndex);
        controller.documentController.beginInteractiveTransaction(
          currentSelection: controller.selectedIds,
        );
        return;
      }
    }

    // Otherwise check if user clicked another PathObject on the canvas
    final hitObj = HitTestMath.hitTestDocument(
      doc,
      event.docPosition,
      zoom: event.zoom,
      screenTolerance: EditorConstants.hitTestScreenTolerance,
    );

    if (hitObj is PathObject) {
      controller.selectionController.selectSingle(hitObj.id);
      return;
    }

    controller.selectionController.selectAnchor(null);
  }

  @override
  void onPointerMove(EditorController controller, ToolPointerData event) {
    final pathId = _activePathId;
    final nodeHit = _activeHit;
    final baseDoc = _initialDocument;
    final startLocal = _dragStartLocal;

    if (pathId == null ||
        nodeHit == null ||
        baseDoc == null ||
        startLocal == null) {
      return;
    }

    final initialPath = baseDoc.findObjectById(pathId);
    if (initialPath is! PathObject) return;

    final currentLocal = TransformMath.worldToLocal(
      event.docPosition,
      initialPath.center,
      initialPath.rotation,
    );

    final updatedDoc = EditorCommands.updatePathAnchor(
      baseDoc,
      pathId,
      nodeHit.anchorIndex,
      (anchor) {
        switch (nodeHit.part) {
          case NodeHitPart.anchor:
            final delta = currentLocal - startLocal;
            return anchor.translate(delta);

          case NodeHitPart.handleOut:
            return anchor.withWorldHandleOut(
              currentLocal,
              breakSmooth: event.isAltPressed,
            );

          case NodeHitPart.handleIn:
            return anchor.withWorldHandleIn(
              currentLocal,
              breakSmooth: event.isAltPressed,
            );
        }
      },
    );

    controller.documentController.updateInteractiveDocument(updatedDoc);
  }

  @override
  void onPointerUp(EditorController controller, ToolPointerData event) {
    final hit = _activeHit;
    _activePathId = null;
    _activeHit = null;
    _initialDocument = null;
    _dragStartLocal = null;

    if (hit == null) return;

    final label = hit.part == NodeHitPart.anchor
        ? 'Move Path Anchor'
        : 'Edit Bézier Handle';

    controller.documentController.commitInteractiveTransaction(
      label: label,
      afterSelection: controller.selectedIds,
    );
  }

  @override
  void onDoubleTap(EditorController controller, ToolPointerData event) {
    final path = _selectedPath(controller);
    if (path == null) return;

    // 1. Double-clicking an anchor toggles between Corner and Smooth continuity
    final nodeHit = HitTestMath.hitTestPathNodes(
      path,
      event.docPosition,
      zoom: event.zoom,
      screenRadius: EditorConstants.handleHitScreenRadius + 2.0,
    );

    if (nodeHit != null && nodeHit.part == NodeHitPart.anchor) {
      controller.selectionController.selectAnchor(nodeHit.anchorIndex);
      final currentNode = path.anchors[nodeHit.anchorIndex];
      final nextType = currentNode.nodeType == NodeType.corner
          ? NodeType.smooth
          : NodeType.corner;
      controller.setSelectedAnchorNodeType(nextType);
      return;
    }

    // 2. Double-clicking on a curve segment splits the cubic Bézier at `t` using De Casteljau
    final localPt = TransformMath.worldToLocal(
      event.docPosition,
      path.center,
      path.rotation,
    );
    final tol =
        EditorConstants.hitTestScreenTolerance / math.max(0.05, event.zoom);
    final segs = path.segments;

    for (var i = 0; i < segs.length; i++) {
      final seg = segs[i];
      final dist = BezierMath.distanceToCubic(
        localPt,
        seg.p0,
        seg.p1,
        seg.p2,
        seg.p3,
      );
      if (dist <= tol + path.stroke.width * 0.5) {
        final t = BezierMath.closestParameterOnCubic(
          localPt,
          seg.p0,
          seg.p1,
          seg.p2,
          seg.p3,
        ).clamp(0.1, 0.9);

        final split = BezierMath.splitCubic(seg.p0, seg.p1, seg.p2, seg.p3, t);
        final nextIdx = (i + 1) % path.anchors.length;
        final updatedAnchors = List<AnchorPoint>.of(path.anchors);

        final startAnchor = updatedAnchors[i];
        final endAnchor = updatedAnchors[nextIdx];

        updatedAnchors[i] = startAnchor.copyWith(
          handleOut: split.left.p1 - startAnchor.position,
        );
        updatedAnchors[nextIdx] = endAnchor.copyWith(
          handleIn: split.right.p2 - endAnchor.position,
        );

        final insertedAnchor = AnchorPoint(
          id: IdGenerator.anchorId(),
          position: split.left.p3,
          handleIn: split.left.p2 - split.left.p3,
          handleOut: split.right.p1 - split.left.p3,
          nodeType: seg.isLinear ? NodeType.corner : NodeType.smooth,
        );

        final insertPos = i + 1;
        updatedAnchors.insert(insertPos, insertedAnchor);

        controller.documentController.executeEdit(
          label: 'Insert Path Anchor',
          mutator: (doc) => doc.updateObject(
            path.id,
            (_) => path.copyWith(anchors: updatedAnchors),
          ),
          beforeSelection: controller.selectedIds,
        );
        controller.selectionController.selectAnchor(insertPos);
        return;
      }
    }
  }

  @override
  void onCancel(EditorController controller) {
    _activePathId = null;
    _activeHit = null;
    _initialDocument = null;
    _dragStartLocal = null;
    controller.documentController.cancelInteractiveTransaction();
  }
}
