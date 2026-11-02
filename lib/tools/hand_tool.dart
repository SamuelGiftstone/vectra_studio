import 'package:flutter/services.dart';

import '../editor/editor_controller.dart';
import '../editor/tool_controller.dart';
import 'editor_tool.dart';

/// Hand / Pan Tool (`H`) for dragging and navigating across the canvas viewport.
class HandTool extends EditorTool {
  bool _isDragging = false;

  @override
  EditorToolType get type => EditorToolType.hand;

  @override
  SystemMouseCursor cursor(EditorController controller) =>
      _isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab;

  @override
  void onPointerDown(EditorController controller, ToolPointerData event) {
    _isDragging = true;
    controller.toolController.updateTransient(
      (t) => t.copyWith(isHandDragging: true),
    );
  }

  @override
  void onPointerMove(EditorController controller, ToolPointerData event) {
    if (!_isDragging) return;
    controller.viewportController.panBy(event.screenDelta);
  }

  @override
  void onPointerUp(EditorController controller, ToolPointerData event) {
    _isDragging = false;
    controller.toolController.updateTransient(
      (t) => t.copyWith(isHandDragging: false),
    );
  }

  @override
  void onCancel(EditorController controller) {
    _isDragging = false;
    controller.toolController.updateTransient(
      (t) => t.copyWith(isHandDragging: false),
    );
  }
}
