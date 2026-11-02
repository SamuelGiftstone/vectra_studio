import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_icons.dart';
import '../../editor/tool_controller.dart';
import '../../providers/editor_providers.dart';
import '../dialogs/workflow_dialogs.dart';
import 'tool_button.dart';

/// Left vertical tool dock exposing all vector editing and navigation tools.
class ToolPanel extends ConsumerWidget {
  const ToolPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool = ref.watch(activeToolProvider);
    final showGrid = ref.watch(showGridProvider);
    final history = ref.watch(historyAvailabilityProvider);
    final editor = ref.read(editorControllerProvider);

    void select(EditorToolType tool) => editor.activateTool(tool);

    return Container(
      width: AppDimensions.leftToolbarWidth,
      decoration: const BoxDecoration(
        color: AppColors.primaryPanel,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: <Widget>[
          ToolButton(
            icon: AppIcons.selection,
            tooltip: 'Selection Tool (V)',
            isSelected: activeTool == EditorToolType.selection,
            onPressed: () => select(EditorToolType.selection),
          ),
          const SizedBox(height: 4),
          ToolButton(
            icon: AppIcons.node,
            tooltip: 'Node Tool — Edit Anchors & Bézier Handles (N)',
            isSelected: activeTool == EditorToolType.node,
            onPressed: () => select(EditorToolType.node),
          ),
          const SizedBox(height: 4),
          ToolButton(
            icon: AppIcons.pen,
            tooltip: 'Pen Tool — Draw Bézier Paths (P)',
            isSelected: activeTool == EditorToolType.pen,
            onPressed: () => select(EditorToolType.pen),
          ),
          const SizedBox(height: 4),
          ToolButton(
            icon: AppIcons.text,
            tooltip: 'Text Tool — Point & Area Frame Text (T)',
            isSelected: activeTool == EditorToolType.text,
            onPressed: () => select(EditorToolType.text),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Divider(height: 1, color: AppColors.border),
          ),
          ToolButton(
            icon: AppIcons.rectangle,
            tooltip: 'Rectangle Tool (R)',
            isSelected: activeTool == EditorToolType.rectangle,
            onPressed: () => select(EditorToolType.rectangle),
          ),
          const SizedBox(height: 4),
          ToolButton(
            icon: AppIcons.ellipse,
            tooltip: 'Ellipse Tool (E)',
            isSelected: activeTool == EditorToolType.ellipse,
            onPressed: () => select(EditorToolType.ellipse),
          ),
          const SizedBox(height: 4),
          ToolButton(
            icon: AppIcons.line,
            tooltip: 'Line Tool (L)',
            isSelected: activeTool == EditorToolType.line,
            onPressed: () => select(EditorToolType.line),
          ),
          const SizedBox(height: 4),
          ToolButton(
            icon: AppIcons.polygon,
            tooltip: 'Polygon Tool (G)',
            isSelected: activeTool == EditorToolType.polygon,
            onPressed: () => select(EditorToolType.polygon),
          ),
          const SizedBox(height: 4),
          ToolButton(
            icon: AppIcons.star,
            tooltip: 'Star Tool (S)',
            isSelected: activeTool == EditorToolType.star,
            onPressed: () => select(EditorToolType.star),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Divider(height: 1, color: AppColors.border),
          ),
          ToolButton(
            icon: AppIcons.hand,
            tooltip: 'Hand Pan Tool (H)',
            isSelected: activeTool == EditorToolType.hand,
            onPressed: () => select(EditorToolType.hand),
          ),
          const SizedBox(height: 4),
          ToolButton(
            icon: AppIcons.image,
            tooltip: 'Import Image — PNG, JPEG, WebP (Ctrl+Shift+I)',
            onPressed: () =>
                WorkflowDialogs.performImportRasterImage(context, ref),
          ),
          const Spacer(),
          ToolButton(
            icon: AppIcons.grid,
            tooltip: showGrid ? 'Hide Artboard Grid' : 'Show Artboard Grid',
            isSelected: showGrid,
            onPressed: () =>
                ref.read(viewportControllerProvider.notifier).toggleGrid(),
          ),
          const SizedBox(height: 4),
          ToolButton(
            icon: AppIcons.undo,
            tooltip: history.undoLabel != null
                ? 'Undo ${history.undoLabel} (Ctrl+Z)'
                : 'Undo (Ctrl+Z)',
            isEnabled: history.canUndo,
            onPressed: history.canUndo ? editor.undo : null,
          ),
          const SizedBox(height: 4),
          ToolButton(
            icon: AppIcons.redo,
            tooltip: history.redoLabel != null
                ? 'Redo ${history.redoLabel} (Ctrl+Shift+Z)'
                : 'Redo (Ctrl+Shift+Z)',
            isEnabled: history.canRedo,
            onPressed: history.canRedo ? editor.redo : null,
          ),
        ],
      ),
    );
  }
}
