import 'dart:ui' show Offset;

import 'package:flutter/services.dart';

import '../core/constants/editor_constants.dart';
import '../editor/editor_controller.dart';
import '../editor/tool_controller.dart';
import '../math/vec2.dart';
import '../models/vector_object.dart';

/// Normalized pointer payload passed to active [EditorTool] instances.
class ToolPointerData {
  final Offset screenPosition;
  final Offset screenDelta;
  final Vec2 docPosition;
  final double zoom;
  final bool isShiftPressed;
  final bool isAltPressed;
  final bool isControlPressed;

  const ToolPointerData({
    required this.screenPosition,
    this.screenDelta = Offset.zero,
    required this.docPosition,
    required this.zoom,
    this.isShiftPressed = false,
    this.isAltPressed = false,
    this.isControlPressed = false,
  });
}

/// Common interface implemented by all interactive canvas editing tools.
abstract class EditorTool {
  EditorToolType get type;

  SystemMouseCursor cursor(EditorController controller) =>
      SystemMouseCursors.basic;

  void onPointerDown(EditorController controller, ToolPointerData event);
  void onPointerMove(EditorController controller, ToolPointerData event);
  void onPointerUp(EditorController controller, ToolPointerData event);

  void onPointerHover(EditorController controller, ToolPointerData event) {}

  void onDoubleTap(EditorController controller, ToolPointerData event) {}

  void onCancel(EditorController controller) {
    controller.cancelActiveOperation();
  }
}

/// Shared base class for drag-to-create geometric shape tools
/// (Rectangle, Ellipse, Line, Polygon, Star).
abstract class ShapeDragTool extends EditorTool {
  Vec2? _dragStartDoc;
  Offset? _dragStartScreen;

  @override
  SystemMouseCursor cursor(EditorController controller) =>
      SystemMouseCursors.precise;

  /// Builds the preview/committed [VectorObject] for the drag from [startDoc] to [currentDoc].
  VectorObject? buildShapeObject({
    required EditorController controller,
    required String id,
    required Vec2 startDoc,
    required Vec2 currentDoc,
    required bool isShiftPressed,
    required bool isAltPressed,
  });

  String get creationHistoryLabel;

  @override
  void onPointerDown(EditorController controller, ToolPointerData event) {
    _dragStartDoc = event.docPosition;
    _dragStartScreen = event.screenPosition;
    controller.selectionController.clearSelection();
  }

  @override
  void onPointerMove(EditorController controller, ToolPointerData event) {
    final startDoc = _dragStartDoc;
    final startScreen = _dragStartScreen;
    if (startDoc == null || startScreen == null) return;

    if ((event.screenPosition - startScreen).distance <
        EditorConstants.minDragCreateDistance) {
      return;
    }

    final preview = buildShapeObject(
      controller: controller,
      id: 'draft_preview',
      startDoc: startDoc,
      currentDoc: event.docPosition,
      isShiftPressed: event.isShiftPressed,
      isAltPressed: event.isAltPressed,
    );

    controller.toolController.updateTransient(
      (t) => t.copyWith(
        draftObject: preview,
        clearDraftObject: preview == null,
      ),
    );
  }

  @override
  void onPointerUp(EditorController controller, ToolPointerData event) {
    final startDoc = _dragStartDoc;
    final startScreen = _dragStartScreen;
    _dragStartDoc = null;
    _dragStartScreen = null;

    controller.toolController.clearTransient();

    if (startDoc == null || startScreen == null) return;
    if ((event.screenPosition - startScreen).distance <
        EditorConstants.minDragCreateDistance) {
      return;
    }

    final committed = buildShapeObject(
      controller: controller,
      id: '',
      startDoc: startDoc,
      currentDoc: event.docPosition,
      isShiftPressed: event.isShiftPressed,
      isAltPressed: event.isAltPressed,
    );

    if (committed == null) return;

    final prevSelection = controller.selectedIds;
    final nextSelection = <String>{committed.id};

    controller.documentController.executeEdit(
      label: creationHistoryLabel,
      mutator: (doc) => doc.addObject(committed),
      beforeSelection: prevSelection,
      afterSelection: nextSelection,
    );
    controller.selectionController.selectSingle(committed.id);
  }

  @override
  void onCancel(EditorController controller) {
    _dragStartDoc = null;
    _dragStartScreen = null;
    controller.toolController.clearTransient();
  }
}
