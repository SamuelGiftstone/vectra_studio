import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../editor/tool_controller.dart';
import '../../providers/editor_providers.dart';
import '../../tools/tool_registry.dart';
import '../dialogs/workflow_dialogs.dart';
import '../inspector/properties_panel.dart';
import '../layers/layers_panel.dart';
import '../statusbar/editor_statusbar.dart';
import '../titlebar/custom_titlebar.dart';
import '../toolbar/contextual_tool_bar.dart';
import '../toolbar/tool_panel.dart';
import 'canvas_viewport.dart';

/// Main desktop workspace layout and centralized keyboard shortcut dispatcher.
class EditorWorkspace extends ConsumerStatefulWidget {
  const EditorWorkspace({super.key});

  @override
  ConsumerState<EditorWorkspace> createState() => _EditorWorkspaceState();
}

class _EditorWorkspaceState extends ConsumerState<EditorWorkspace> {
  final FocusNode _workspaceFocusNode = FocusNode(debugLabel: 'EditorWorkspace');
  final ToolRegistry _toolRegistry = ToolRegistry();

  @override
  void dispose() {
    _workspaceFocusNode.dispose();
    super.dispose();
  }

  bool _isEditableTextFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorStateOfType<EditableTextState>() != null;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;

    // Release temporary Spacebar pan on KeyUp
    if (event is KeyUpEvent && key == LogicalKeyboardKey.space) {
      if (ref.read(transientToolStateProvider).isSpacePanning) {
        ref
            .read(toolControllerProvider.notifier)
            .updateTransient((t) => t.copyWith(isSpacePanning: false));
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final kb = HardwareKeyboard.instance;
    final isCtrl = kb.isControlPressed || kb.isMetaPressed;
    final isShift = kb.isShiftPressed;
    final isTyping = _isEditableTextFocused();
    final editor = ref.read(editorControllerProvider);

    // File & History Ctrl shortcuts work globally unless typing overrides standard text editing
    if (isCtrl) {
      if (key == LogicalKeyboardKey.keyS) {
        if (event is KeyDownEvent) {
          if (isShift) {
            WorkflowDialogs.performSaveAs(context, ref);
          } else {
            WorkflowDialogs.performSave(context, ref);
          }
        }
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.keyO && event is KeyDownEvent) {
        WorkflowDialogs.performOpenProject(context, ref);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.keyN && event is KeyDownEvent) {
        WorkflowDialogs.performNewDocument(context, ref);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.keyE && event is KeyDownEvent) {
        WorkflowDialogs.performExportArtwork(context, ref);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.keyI && isShift && event is KeyDownEvent) {
        WorkflowDialogs.performImportRasterImage(context, ref);
        return KeyEventResult.handled;
      }

      if (!isTyping) {
        if (key == LogicalKeyboardKey.keyZ) {
          if (isShift) {
            editor.redo();
          } else {
            editor.undo();
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyY) {
          editor.redo();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyG && event is KeyDownEvent) {
          if (isShift) {
            editor.ungroupSelection();
          } else {
            editor.groupSelection();
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyD && event is KeyDownEvent) {
          editor.duplicateSelection();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyA && event is KeyDownEvent) {
          editor.selectAllUnlocked();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.digit0 ||
            key == LogicalKeyboardKey.numpad0) {
          if (isShift) {
            editor.findMyArtwork();
          } else {
            final doc = ref.read(currentDocumentProvider);
            ref.read(viewportControllerProvider.notifier).fitArtboard(
                  docWidth: doc.width,
                  docHeight: doc.height,
                );
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.digit1 ||
            key == LogicalKeyboardKey.numpad1) {
          editor.resetView();
          return KeyEventResult.handled;
        }
        if ((key == LogicalKeyboardKey.quote ||
                key == LogicalKeyboardKey.quoteSingle) &&
            event is KeyDownEvent) {
          ref.read(viewportControllerProvider.notifier).toggleGrid();
          return KeyEventResult.handled;
        }
      }
    }

    // Do not intercept single-key shortcuts while typing inside a text field!
    if (isTyping) {
      if (key == LogicalKeyboardKey.escape) {
        FocusManager.instance.primaryFocus?.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Escape cancels unfinished Pen path or active drag
    if (key == LogicalKeyboardKey.escape && event is KeyDownEvent) {
      final activeTool = ref.read(activeToolProvider);
      _toolRegistry.forType(activeTool).onCancel(editor);
      return KeyEventResult.handled;
    }

    // Enter finishes an open Pen path
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        event is KeyDownEvent) {
      if (ref.read(activeToolProvider) == EditorToolType.pen &&
          ref.read(transientToolStateProvider).hasActivePenPath) {
        editor.commitActivePenPath(closed: false);
        return KeyEventResult.handled;
      }
    }

    // Delete / Backspace deletes selected anchor (in Node Tool) or selected objects
    if ((key == LogicalKeyboardKey.delete ||
            key == LogicalKeyboardKey.backspace) &&
        event is KeyDownEvent) {
      final activeTool = ref.read(activeToolProvider);
      final anchorIdx = ref.read(selectedAnchorIndexProvider);
      if (activeTool == EditorToolType.node && anchorIdx != null) {
        editor.deleteSelectedAnchor();
      } else {
        editor.deleteSelection();
      }
      return KeyEventResult.handled;
    }

    // Zoom with + / -
    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd) {
      ref.read(viewportControllerProvider.notifier).zoomIn();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      ref.read(viewportControllerProvider.notifier).zoomOut();
      return KeyEventResult.handled;
    }

    // Spacebar temporary pan
    if (key == LogicalKeyboardKey.space) {
      if (!ref.read(transientToolStateProvider).isSpacePanning) {
        ref
            .read(toolControllerProvider.notifier)
            .updateTransient((t) => t.copyWith(isSpacePanning: true));
      }
      return KeyEventResult.handled;
    }

    // Single-letter tool switching shortcuts
    if (!isCtrl && event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.keyV) {
        editor.activateTool(EditorToolType.selection);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyP) {
        editor.activateTool(EditorToolType.pen);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyT) {
        editor.activateTool(EditorToolType.text);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyN) {
        editor.activateTool(EditorToolType.node);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyR) {
        editor.activateTool(EditorToolType.rectangle);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyE) {
        editor.activateTool(EditorToolType.ellipse);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyL) {
        editor.activateTool(EditorToolType.line);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyG) {
        editor.activateTool(EditorToolType.polygon);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyS) {
        editor.activateTool(EditorToolType.star);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyH) {
        editor.activateTool(EditorToolType.hand);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyF) {
        if (editor.selectedIds.isNotEmpty) {
          editor.focusSelection();
        } else {
          editor.findMyArtwork();
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _workspaceFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: AppColors.mainBackground,
        body: Column(
          children: <Widget>[
            const CustomTitleBar(),
            Expanded(
              child: Row(
                children: <Widget>[
                  const ToolPanel(),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        const ContextualToolBar(),
                        Expanded(
                          child: CanvasViewport(toolRegistry: _toolRegistry),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: AppDimensions.rightSidebarWidth,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryPanel,
                      border: Border(
                        left: BorderSide(color: AppColors.border, width: 1),
                      ),
                    ),
                    child: const Column(
                      children: <Widget>[
                        Expanded(
                          flex: 55,
                          child: PropertiesPanel(),
                        ),
                        Expanded(
                          flex: 45,
                          child: LayersPanel(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const EditorStatusbar(),
          ],
        ),
      ),
    );
  }
}
