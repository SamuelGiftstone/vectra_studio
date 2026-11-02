import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../core/constants/editor_constants.dart';
import '../editor/editor_commands.dart';
import '../editor/editor_controller.dart';
import '../editor/tool_controller.dart';
import '../math/bounds2d.dart';
import '../math/geometry_math.dart';
import '../math/hit_test_math.dart';
import '../math/transform_math.dart';
import '../math/vec2.dart';
import '../models/image_object.dart';
import '../models/path_object.dart';
import '../models/text_object.dart';
import '../models/vector_document.dart';
import '../models/vector_object.dart';
import 'editor_tool.dart';


enum _SelectionDragMode {
  none,
  moveObjects,
  resizeHandle,
  rotateObject,
  marquee,
}

/// Interactive Selection Tool (`V`) supporting single/multi selection, marquee box,
/// moving, 8-handle local resizing, and rotation around object center.
class SelectionTool extends EditorTool {
  _SelectionDragMode _mode = _SelectionDragMode.none;
  Vec2? _pointerDownDoc;
  VectorDocument? _initialDocument;
  VectorObject? _activeTransformTarget;
  ResizeHandle? _activeResizeHandle;
  double _initialPointerAngle = 0.0;
  double _initialObjectRotation = 0.0;
  SystemMouseCursor _hoverCursor = SystemMouseCursors.basic;

  @override
  EditorToolType get type => EditorToolType.selection;

  @override
  SystemMouseCursor cursor(EditorController controller) => _hoverCursor;

  @override
  void onPointerHover(EditorController controller, ToolPointerData event) {
    final doc = controller.currentDocument;
    final selIds = controller.selectedIds;

    if (selIds.length == 1) {
      final selectedObj = doc.findObjectById(selIds.first);
      if (selectedObj != null &&
          doc.isObjectEffectivelyVisible(selectedObj.id) &&
          !doc.isObjectEffectivelyLocked(selectedObj.id)) {
        if (HitTestMath.hitTestRotationHandle(
          selectedObj,
          event.docPosition,
          zoom: event.zoom,
        )) {
          _hoverCursor = SystemMouseCursors.grab;
          controller.selectionController.setHoveredObject(null);
          return;
        }
        final handle = HitTestMath.hitTestResizeHandles(
          selectedObj,
          event.docPosition,
          zoom: event.zoom,
          screenRadius: EditorConstants.handleHitScreenRadius,
        );
        if (handle != null) {
          _hoverCursor = _cursorForHandle(handle);
          controller.selectionController.setHoveredObject(null);
          return;
        }
      }
    }

    final hit = HitTestMath.hitTestDocument(
      doc,
      event.docPosition,
      zoom: event.zoom,
      screenTolerance: EditorConstants.hitTestScreenTolerance,
    );
    controller.selectionController.setHoveredObject(hit?.id);
    _hoverCursor =
        hit != null ? SystemMouseCursors.move : SystemMouseCursors.basic;
  }

  @override
  void onPointerDown(EditorController controller, ToolPointerData event) {
    if (controller.activeTextSession != null) {
      controller.commitInlineTextEditing();
    }

    final doc = controller.currentDocument;
    final selCtrl = controller.selectionController;
    final selIds = selCtrl.state.selectedIds;


    _pointerDownDoc = event.docPosition;
    _initialDocument = doc;

    // 1. Check rotation & resize handles when a single unlocked object is selected
    if (selIds.length == 1) {
      final selectedObj = doc.findObjectById(selIds.first);
      if (selectedObj != null &&
          doc.isObjectEffectivelyVisible(selectedObj.id) &&
          !doc.isObjectEffectivelyLocked(selectedObj.id)) {
        if (HitTestMath.hitTestRotationHandle(
          selectedObj,
          event.docPosition,
          zoom: event.zoom,
        )) {
          _mode = _SelectionDragMode.rotateObject;
          _activeTransformTarget = selectedObj;
          final c = selectedObj.center;
          _initialPointerAngle = math.atan2(
            event.docPosition.y - c.y,
            event.docPosition.x - c.x,
          );
          _initialObjectRotation = selectedObj.rotation;
          controller.documentController.beginInteractiveTransaction(
            currentSelection: selIds,
          );
          return;
        }

        final handle = HitTestMath.hitTestResizeHandles(
          selectedObj,
          event.docPosition,
          zoom: event.zoom,
          screenRadius: EditorConstants.handleHitScreenRadius,
        );
        if (handle != null) {
          _mode = _SelectionDragMode.resizeHandle;
          _activeTransformTarget = selectedObj;
          _activeResizeHandle = handle;
          controller.documentController.beginInteractiveTransaction(
            currentSelection: selIds,
          );
          return;
        }
      }
    }

    // 2. Hit-test document artwork
    final hitObj = HitTestMath.hitTestDocument(
      doc,
      event.docPosition,
      zoom: event.zoom,
      screenTolerance: EditorConstants.hitTestScreenTolerance,
    );

    if (hitObj != null) {
      if (event.isShiftPressed) {
        selCtrl.toggleObject(hitObj.id);
      } else if (!selCtrl.state.isSelected(hitObj.id)) {
        selCtrl.selectSingle(hitObj.id);
      }

      // Sync active layer to selected object's layer
      controller.documentController.setActiveLayer(hitObj.layerId);

      if (selCtrl.state.hasSelection) {
        _mode = _SelectionDragMode.moveObjects;
        controller.documentController.beginInteractiveTransaction(
          currentSelection: selCtrl.state.selectedIds,
        );
      }
      return;
    }

    // 3. Empty space -> clear selection (unless Shift held) and start marquee box
    if (!event.isShiftPressed) {
      selCtrl.clearSelection();
    }
    _mode = _SelectionDragMode.marquee;
  }

  @override
  void onPointerMove(EditorController controller, ToolPointerData event) {
    final startDoc = _pointerDownDoc;
    final baseDoc = _initialDocument;
    if (startDoc == null || baseDoc == null) return;

    switch (_mode) {
      case _SelectionDragMode.none:
        return;

      case _SelectionDragMode.moveObjects:
        var delta = event.docPosition - startDoc;
        if (event.isShiftPressed) {
          if (delta.x.abs() >= delta.y.abs()) {
            delta = Vec2(delta.x, 0.0);
          } else {
            delta = Vec2(0.0, delta.y);
          }
        }
        final updated = EditorCommands.translateObjects(
          baseDoc,
          controller.selectedIds,
          delta,
        );
        controller.documentController.updateInteractiveDocument(updated);
        break;

      case _SelectionDragMode.resizeHandle:
        final target = _activeTransformTarget;
        final handle = _activeResizeHandle;
        if (target == null || handle == null) return;

        final localPointer = TransformMath.worldToLocal(
          event.docPosition,
          target.center,
          target.rotation,
        );
        final keepRatio =
            (target is ImageObject && target.preserveAspectRatio)
                ? !event.isShiftPressed
                : event.isShiftPressed;
        final nextBounds = TransformMath.computeResizedBounds(
          initialBounds: target.localBounds,
          handle: handle,
          localPointer: localPointer,
          keepAspectRatio: keepRatio,
        );
        final updated = EditorCommands.resizeObject(
          baseDoc,
          target.id,
          nextBounds,
        );
        controller.documentController.updateInteractiveDocument(updated);
        break;


      case _SelectionDragMode.rotateObject:
        final target = _activeTransformTarget;
        if (target == null) return;
        final c = target.center;
        final currentAngle = math.atan2(
          event.docPosition.y - c.y,
          event.docPosition.x - c.x,
        );
        var nextRotation = GeometryMath.normalizeRadians(
          _initialObjectRotation + (currentAngle - _initialPointerAngle),
        );
        if (event.isShiftPressed) {
          nextRotation = GeometryMath.snapAngleRadians(
            nextRotation,
            stepDegrees: 15.0,
          );
        }
        final updated = EditorCommands.rotateObject(
          baseDoc,
          target.id,
          nextRotation,
        );
        controller.documentController.updateInteractiveDocument(updated);
        break;

      case _SelectionDragMode.marquee:
        final marquee = Bounds2D.fromPoints(<Vec2>[startDoc, event.docPosition]);
        controller.toolController.updateTransient(
          (t) => t.copyWith(marqueeBounds: marquee),
        );
        break;
    }
  }

  @override
  void onPointerUp(EditorController controller, ToolPointerData event) {
    final mode = _mode;
    final startDoc = _pointerDownDoc;
    _resetInternalState();

    switch (mode) {
      case _SelectionDragMode.none:
        return;

      case _SelectionDragMode.moveObjects:
        controller.documentController.commitInteractiveTransaction(
          label: 'Move Object',
          afterSelection: controller.selectedIds,
        );
        break;

      case _SelectionDragMode.resizeHandle:
        controller.documentController.commitInteractiveTransaction(
          label: 'Resize Object',
          afterSelection: controller.selectedIds,
        );
        break;

      case _SelectionDragMode.rotateObject:
        controller.documentController.commitInteractiveTransaction(
          label: 'Rotate Object',
          afterSelection: controller.selectedIds,
        );
        break;

      case _SelectionDragMode.marquee:
        final marquee = controller.toolController.state.transient.marqueeBounds;
        controller.toolController.clearTransient();
        if (marquee != null &&
            startDoc != null &&
            (marquee.width > 2.0 || marquee.height > 2.0)) {
          final doc = controller.currentDocument;
          final matched = <String>{
            if (event.isShiftPressed) ...controller.selectedIds,
          };
          for (final layer in doc.layers) {
            if (!layer.visible || layer.locked) continue;
            for (final obj in layer.objects) {
              if (!obj.visible || obj.locked) continue;
              if (marquee.intersects(obj.worldBounds)) {
                matched.add(obj.id);
              }
            }
          }
          controller.selectionController.setSelectedIds(matched);
        }
        break;
    }
  }

  @override
  void onDoubleTap(EditorController controller, ToolPointerData event) {
    final hit = HitTestMath.hitTestDocument(
      controller.currentDocument,
      event.docPosition,
      zoom: event.zoom,
    );
    if (hit is TextObject) {
      controller.beginInlineTextEditing(hit.id);
      return;
    }
    if (hit is PathObject) {
      controller.selectionController.selectSingle(hit.id);
      controller.activateTool(EditorToolType.node);
    }
  }


  @override
  void onCancel(EditorController controller) {
    _resetInternalState();
    controller.toolController.clearTransient();
    controller.documentController.cancelInteractiveTransaction();
  }

  void _resetInternalState() {
    _mode = _SelectionDragMode.none;
    _pointerDownDoc = null;
    _initialDocument = null;
    _activeTransformTarget = null;
    _activeResizeHandle = null;
  }

  SystemMouseCursor _cursorForHandle(ResizeHandle handle) {
    switch (handle) {
      case ResizeHandle.topLeft:
      case ResizeHandle.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case ResizeHandle.topRight:
      case ResizeHandle.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
      case ResizeHandle.topCenter:
      case ResizeHandle.bottomCenter:
        return SystemMouseCursors.resizeUpDown;
      case ResizeHandle.middleLeft:
      case ResizeHandle.middleRight:
        return SystemMouseCursors.resizeLeftRight;
    }
  }
}
