import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/editor_providers.dart';
import '../../tools/editor_tool.dart';
import '../../tools/tool_registry.dart';
import 'artboard_widget.dart';
import 'artwork_navigation_overlay.dart';
import 'inline_text_editor_overlay.dart';
import 'object_tag_overlay.dart';

/// Interactive desktop viewport hosting [ArtboardWidget], Floating Object Tags,
/// Viewport-Aligned Inline Text Editing, and Artwork Navigation controls.
class CanvasViewport extends ConsumerStatefulWidget {
  final ToolRegistry toolRegistry;

  const CanvasViewport({
    super.key,
    required this.toolRegistry,
  });

  @override
  ConsumerState<CanvasViewport> createState() => _CanvasViewportState();
}

class _CanvasViewportState extends ConsumerState<CanvasViewport> {
  Size _lastReportedSize = Size.zero;
  bool _isMiddleButtonPanning = false;
  DateTime? _lastPrimaryDownTime;
  Offset? _lastPrimaryDownPos;

  ToolPointerData _buildPointerData(
    Offset localPosition, {
    Offset screenDelta = Offset.zero,
  }) {
    final viewport = ref.read(viewportControllerProvider);
    final kb = HardwareKeyboard.instance;
    return ToolPointerData(
      screenPosition: localPosition,
      screenDelta: screenDelta,
      docPosition: viewport.screenToDocument(localPosition),
      zoom: viewport.zoom,
      isShiftPressed: kb.isShiftPressed,
      isAltPressed: kb.isAltPressed,
      isControlPressed: kb.isControlPressed || kb.isMetaPressed,
    );
  }

  void _onPointerSignal(PointerSignalEvent signal) {
    if (signal is! PointerScrollEvent) return;
    final dy = signal.scrollDelta.dy;
    if (dy.abs() < 0.01) return;

    final viewportCtrl = ref.read(viewportControllerProvider.notifier);
    final factor = dy < 0 ? 1.12 : (1.0 / 1.12);
    viewportCtrl.zoomByFactor(
      factor,
      focalScreenPoint: signal.localPosition,
    );
  }

  void _onPointerHover(PointerHoverEvent event) {
    final data = _buildPointerData(event.localPosition);
    ref.read(viewportControllerProvider.notifier).setCursorPosition(
          data.docPosition,
        );

    final transient = ref.read(transientToolStateProvider);
    if (transient.isSpacePanning) return;
    if (ref.read(activeTextSessionProvider) != null) return;

    final editor = ref.read(editorControllerProvider);
    final activeTool = ref.read(activeToolProvider);
    widget.toolRegistry.forType(activeTool).onPointerHover(editor, data);
  }

  void _onPointerDown(PointerDownEvent event) {
    final editor = ref.read(editorControllerProvider);

    // Clicking outside an active inline canvas text editor commits it cleanly!
    if (editor.activeTextSession != null) {
      editor.commitInlineTextEditing();
      FocusManager.instance.primaryFocus?.unfocus();
      // If using Selection Tool or Hand Tool, allow continuing; if Text Tool, return
      // so clicking outside commits the current text without immediately spawning a second empty box.
      if (ref.read(activeToolProvider) ==
          widget.toolRegistry.forType(ref.read(activeToolProvider)).type) {
        if (ref.read(activeToolProvider).name == 'text') {
          return;
        }
      }
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    // Middle mouse button or Spacebar hold -> instant viewport pan
    final isSpacePan = ref.read(transientToolStateProvider).isSpacePanning;
    if (event.buttons == kMiddleMouseButton ||
        (isSpacePan && event.buttons == kPrimaryMouseButton)) {
      _isMiddleButtonPanning = true;
      return;
    }

    if (event.buttons != kPrimaryMouseButton) return;

    final activeTool = ref.read(activeToolProvider);
    final tool = widget.toolRegistry.forType(activeTool);
    final data = _buildPointerData(event.localPosition);

    final now = DateTime.now();
    final isDoubleTap = _lastPrimaryDownTime != null &&
        _lastPrimaryDownPos != null &&
        now.difference(_lastPrimaryDownTime!).inMilliseconds <= 280 &&
        (event.localPosition - _lastPrimaryDownPos!).distance <= 6.0;

    if (isDoubleTap) {
      _lastPrimaryDownTime = null;
      _lastPrimaryDownPos = null;
      tool.onDoubleTap(editor, data);
      return;
    }

    _lastPrimaryDownTime = now;
    _lastPrimaryDownPos = event.localPosition;
    tool.onPointerDown(editor, data);
  }

  void _onPointerMove(PointerMoveEvent event) {
    final data = _buildPointerData(
      event.localPosition,
      screenDelta: event.delta,
    );
    ref.read(viewportControllerProvider.notifier).setCursorPosition(
          data.docPosition,
        );

    if (_isMiddleButtonPanning) {
      ref.read(viewportControllerProvider.notifier).panBy(event.delta);
      return;
    }

    if ((event.buttons & kPrimaryMouseButton) == 0) return;

    final editor = ref.read(editorControllerProvider);
    final activeTool = ref.read(activeToolProvider);
    widget.toolRegistry.forType(activeTool).onPointerMove(editor, data);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isMiddleButtonPanning) {
      _isMiddleButtonPanning = false;
      return;
    }

    final editor = ref.read(editorControllerProvider);
    final activeTool = ref.read(activeToolProvider);
    final data = _buildPointerData(event.localPosition);
    widget.toolRegistry.forType(activeTool).onPointerUp(editor, data);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _isMiddleButtonPanning = false;
    final editor = ref.read(editorControllerProvider);
    final activeTool = ref.read(activeToolProvider);
    widget.toolRegistry.forType(activeTool).onCancel(editor);
  }

  @override
  Widget build(BuildContext context) {
    final activeTool = ref.watch(activeToolProvider);
    final transient = ref.watch(transientToolStateProvider);
    ref.watch(selectionControllerProvider);

    final editor = ref.read(editorControllerProvider);
    final SystemMouseCursor activeCursor;
    if (_isMiddleButtonPanning) {
      activeCursor = SystemMouseCursors.grabbing;
    } else if (transient.isSpacePanning) {
      activeCursor = SystemMouseCursors.grab;
    } else {
      activeCursor = widget.toolRegistry.forType(activeTool).cursor(editor);
    }

    return Container(
      color: AppColors.canvasBackdrop,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (size != _lastReportedSize && size.width > 0 && size.height > 0) {
            _lastReportedSize = size;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final doc = ref.read(currentDocumentProvider);
              ref.read(viewportControllerProvider.notifier).updateViewportSize(
                    size,
                    docWidth: doc.width,
                    docHeight: doc.height,
                  );
            });
          }

          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                MouseRegion(
                  cursor: activeCursor,
                  onHover: _onPointerHover,
                  onExit: (_) {
                    ref
                        .read(viewportControllerProvider.notifier)
                        .setCursorPosition(null);
                    ref
                        .read(selectionControllerProvider.notifier)
                        .setHoveredObject(null);
                  },
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerSignal: _onPointerSignal,
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerCancel,
                    child: const ArtboardWidget(),
                  ),
                ),

                // Intelligent Floating Object Tags
                const ObjectTagOverlay(),

                // Viewport-Projected Inline Multiline Text Editor
                const InlineTextEditorOverlay(),

                // Unobtrusive Floating Artwork Navigation & Tag Bar
                const ArtworkNavigationOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }
}
