import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/services.dart';

import '../core/constants/editor_constants.dart';
import '../editor/editor_controller.dart';
import '../editor/tool_controller.dart';
import '../math/bounds2d.dart';
import '../math/hit_test_math.dart';
import '../math/vec2.dart';
import '../models/text_object.dart';
import 'editor_tool.dart';

/// Professional Text Tool (`T`) supporting:
/// - **Point Text**: single-click on the canvas to create an intrinsic-width text object,
///   or click an existing [TextObject] to immediately edit its text inline.
/// - **Area / Frame Text**: click-and-drag a rectangular frame (`>= 8 px` screen drag)
///   to create a word-wrapping multiline text box.
class TextTool extends EditorTool {
  Offset? _pointerDownScreen;
  Vec2? _pointerDownDoc;
  bool _isDraggingFrame = false;

  @override
  EditorToolType get type => EditorToolType.text;

  @override
  SystemMouseCursor cursor(EditorController controller) =>
      SystemMouseCursors.text;

  @override
  void onPointerHover(EditorController controller, ToolPointerData event) {
    final hit = HitTestMath.hitTestDocument(
      controller.currentDocument,
      event.docPosition,
      zoom: event.zoom,
      screenTolerance: EditorConstants.hitTestScreenTolerance,
    );
    if (hit is TextObject) {
      controller.selectionController.setHoveredObject(hit.id);
    } else {
      controller.selectionController.setHoveredObject(null);
    }
  }

  @override
  void onPointerDown(EditorController controller, ToolPointerData event) {
    // If an inline text editing session is already open and the user clicks outside it,
    // commit the previous session first!
    if (controller.activeTextSession != null) {
      controller.commitInlineTextEditing();
    }

    // Check if the user clicked an existing unlocked visible TextObject to edit it
    final hit = HitTestMath.hitTestDocument(
      controller.currentDocument,
      event.docPosition,
      zoom: event.zoom,
      screenTolerance: EditorConstants.hitTestScreenTolerance,
    );
    if (hit is TextObject &&
        controller.currentDocument.isObjectEffectivelyVisible(hit.id) &&
        !controller.currentDocument.isObjectEffectivelyLocked(hit.id)) {
      _resetDragState();
      controller.beginInlineTextEditing(hit.id);
      return;
    }

    _pointerDownScreen = event.screenPosition;
    _pointerDownDoc = event.docPosition;
    _isDraggingFrame = false;
  }

  @override
  void onPointerMove(EditorController controller, ToolPointerData event) {
    final startScreen = _pointerDownScreen;
    final startDoc = _pointerDownDoc;
    if (startScreen == null || startDoc == null) return;

    final screenDist = (event.screenPosition - startScreen).distance;
    if (!_isDraggingFrame &&
        screenDist >= EditorConstants.textFrameDragThreshold) {
      _isDraggingFrame = true;
    }

    if (_isDraggingFrame) {
      final frameBounds = Bounds2D.fromPoints(<Vec2>[startDoc, event.docPosition]);
      controller.toolController.updateTransient(
        (t) => t.copyWith(marqueeBounds: frameBounds),
      );
    }
  }

  @override
  void onPointerUp(EditorController controller, ToolPointerData event) {
    final startDoc = _pointerDownDoc;
    final wasDraggingFrame = _isDraggingFrame;
    _resetDragState();
    controller.toolController.clearTransient();

    if (startDoc == null) return;

    if (wasDraggingFrame) {
      final frameBounds =
          Bounds2D.fromPoints(<Vec2>[startDoc, event.docPosition]);
      final width = math.max(96.0, frameBounds.width);
      final height = math.max(40.0, frameBounds.height);
      controller.createAndBeginInlineText(
        x: frameBounds.left,
        y: frameBounds.top,
        frameWidth: width,
        frameHeight: height,
      );
    } else {
      controller.createAndBeginInlineText(
        x: startDoc.x,
        y: startDoc.y,
      );
    }
  }

  @override
  void onCancel(EditorController controller) {
    _resetDragState();
    controller.toolController.clearTransient();
    if (controller.activeTextSession != null) {
      controller.cancelInlineTextEditing();
    }
  }

  void _resetDragState() {
    _pointerDownScreen = null;
    _pointerDownDoc = null;
    _isDraggingFrame = false;
  }
}
