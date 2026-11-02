import 'package:flutter/rendering.dart';

import '../editor/selection_controller.dart';
import '../editor/tool_controller.dart';
import '../models/path_object.dart';
import '../models/vector_document.dart';
import '../models/vector_object.dart';
import 'handle_painter.dart';
import 'viewport_transform.dart';

/// Dedicated overlay [CustomPainter] rendering hover outlines, selection bounds,
/// resize/rotation handles, Node Tool Bézier handles, and Pen Tool previews.
///
/// Strictly separated from [DocumentPainter] and artwork exports.
class SelectionPainter extends CustomPainter {
  final VectorDocument document;
  final SelectionState selection;
  final EditorToolType activeTool;
  final TransientToolState transient;
  final ViewportTransform viewport;
  final String? activeEditingTextId;

  const SelectionPainter({
    required this.document,
    required this.selection,
    required this.activeTool,
    required this.transient,
    required this.viewport,
    this.activeEditingTextId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Hover outline (when hovering an unselected unlocked visible object)
    final hoveredId = selection.hoveredObjectId;
    if (hoveredId != null &&
        hoveredId != activeEditingTextId &&
        !selection.isSelected(hoveredId)) {
      final hoveredObj = document.findObjectById(hoveredId);
      if (hoveredObj != null &&
          document.isObjectEffectivelyVisible(hoveredId)) {
        HandlePainter.paintHoverOutline(canvas, hoveredObj, viewport);
      }
    }

    // 2. Resolve selected visible objects (excluding any actively inline-edited text object)
    final selectedObjects = <VectorObject>[];
    for (final id in selection.selectedIds) {
      if (id == activeEditingTextId) continue;
      final obj = document.findObjectById(id);
      if (obj != null && document.isObjectEffectivelyVisible(id)) {
        selectedObjects.add(obj);
      }
    }

    // 3. Node Tool mode vs standard Selection Bounds mode
    if (selectedObjects.length == 1) {
      final primary = selectedObjects.first;
      final isUnlocked = !document.isObjectEffectivelyLocked(primary.id);

      if (activeTool == EditorToolType.node && primary is PathObject) {
        HandlePainter.paintPathNodeOverlay(
          canvas,
          primary,
          viewport,
          selectedAnchorIndex: selection.selectedAnchorIndex,
        );
      } else {
        HandlePainter.paintSingleSelectionHandles(
          canvas,
          primary,
          viewport,
          showTransformHandles:
              isUnlocked && activeTool == EditorToolType.selection,
        );
      }
    } else if (selectedObjects.length > 1) {
      HandlePainter.paintMultiSelectionBounds(
        canvas,
        selectedObjects,
        viewport,
      );
    }

    // 4. Pen Tool live construction overlay
    if (transient.hasActivePenPath) {
      HandlePainter.paintPenConstructionOverlay(canvas, transient, viewport);
    }

    // 5. Marquee selection box or Text Frame drag preview box
    if (transient.marqueeBounds != null) {
      HandlePainter.paintMarquee(canvas, transient.marqueeBounds!, viewport);
    }
  }

  @override
  bool shouldRepaint(covariant SelectionPainter oldDelegate) {
    return !identical(oldDelegate.document, document) ||
        oldDelegate.selection != selection ||
        oldDelegate.activeTool != activeTool ||
        oldDelegate.transient != transient ||
        oldDelegate.activeEditingTextId != activeEditingTextId ||
        oldDelegate.viewport.zoom != viewport.zoom ||
        oldDelegate.viewport.panOffset != viewport.panOffset;
  }
}
