import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../editor/tool_controller.dart';
import '../../models/anchor_point.dart';
import '../../models/path_object.dart';
import '../../models/text_object.dart';
import '../../providers/editor_providers.dart';
import '../../rendering/font_catalog.dart';

/// Compact contextual options bar above the canvas exposing active tool parameters,
/// inline typography settings, grouping actions, and artwork navigation quick buttons.
class ContextualToolBar extends ConsumerWidget {
  const ContextualToolBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolState = ref.watch(toolControllerProvider);
    final selectedObjects = ref.watch(selectedObjectsProvider);
    final editor = ref.read(editorControllerProvider);
    final toolCtrl = ref.read(toolControllerProvider.notifier);

    return Container(
      height: AppDimensions.contextBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.primaryPanel,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(
            toolState.activeTool.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 16, color: AppColors.border),
          const SizedBox(width: 12),

          // Tool-specific controls
          if (toolState.activeTool == EditorToolType.rectangle) ...<Widget>[
            _StepperSetting(
              label: 'Corner Radius',
              valueText: '${toolState.rectangleCornerRadius.round()} px',
              onDecrement: () => toolCtrl.setRectangleCornerRadius(
                toolState.rectangleCornerRadius - 4,
              ),
              onIncrement: () => toolCtrl.setRectangleCornerRadius(
                toolState.rectangleCornerRadius + 4,
              ),
            ),
          ] else if (toolState.activeTool == EditorToolType.polygon) ...<Widget>[
            _StepperSetting(
              label: 'Sides',
              valueText: '${toolState.polygonSides}',
              onDecrement: () =>
                  toolCtrl.setPolygonSides(toolState.polygonSides - 1),
              onIncrement: () =>
                  toolCtrl.setPolygonSides(toolState.polygonSides + 1),
            ),
          ] else if (toolState.activeTool == EditorToolType.star) ...<Widget>[
            _StepperSetting(
              label: 'Points',
              valueText: '${toolState.starPoints}',
              onDecrement: () =>
                  toolCtrl.setStarPoints(toolState.starPoints - 1),
              onIncrement: () =>
                  toolCtrl.setStarPoints(toolState.starPoints + 1),
            ),
            const SizedBox(width: 14),
            _StepperSetting(
              label: 'Inner Ratio',
              valueText: '${(toolState.starInnerRatio * 100).round()}%',
              onDecrement: () =>
                  toolCtrl.setStarInnerRatio(toolState.starInnerRatio - 0.05),
              onIncrement: () =>
                  toolCtrl.setStarInnerRatio(toolState.starInnerRatio + 0.05),
            ),
          ] else if (toolState.activeTool == EditorToolType.text) ...<Widget>[
            if (toolState.activeTextSession != null) ...<Widget>[
              const Text(
                'Editing inline text — Enter for new line',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 10),
              _BarActionButton(
                icon: AppIcons.check,
                label: 'Finish (Ctrl+Enter)',
                onTap: editor.commitInlineTextEditing,
              ),
              const SizedBox(width: 6),
              _BarActionButton(
                icon: AppIcons.close,
                label: 'Cancel (Esc)',
                onTap: editor.cancelInlineTextEditing,
              ),
            ] else ...<Widget>[
              _CompactFontDropdown(
                currentFamily: toolState.defaultFontFamily,
                onChanged: (f) => toolCtrl.setTextDefaults(fontFamily: f),
              ),
              const SizedBox(width: 10),
              _StepperSetting(
                label: 'Size',
                valueText: '${toolState.defaultFontSize.round()} px',
                onDecrement: () => toolCtrl.setTextDefaults(
                  fontSize: toolState.defaultFontSize - 2,
                ),
                onIncrement: () => toolCtrl.setTextDefaults(
                  fontSize: toolState.defaultFontSize + 2,
                ),
              ),
              const SizedBox(width: 10),
              _BarIconToggle(
                icon: AppIcons.bold,
                tooltip: 'Default Bold',
                selected: toolState.defaultFontWeight >= 600,
                onTap: () => toolCtrl.setTextDefaults(
                  fontWeight: toolState.defaultFontWeight >= 600 ? 400 : 700,
                ),
              ),
              const SizedBox(width: 4),
              _BarIconToggle(
                icon: AppIcons.italic,
                tooltip: 'Default Italic',
                selected: toolState.defaultItalic,
                onTap: () => toolCtrl.setTextDefaults(
                  isItalic: !toolState.defaultItalic,
                ),
              ),
              const SizedBox(width: 10),
              const Flexible(
                child: Text(
                  'Click for Point Text · Drag box for Frame Text',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ] else if (toolState.activeTool == EditorToolType.pen) ...<Widget>[
            if (toolState.transient.hasActivePenPath) ...<Widget>[
              Text(
                '${toolState.transient.penAnchors.length} anchors placed',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              if (toolState.transient.penAnchors.length >= 2) ...<Widget>[
                _BarActionButton(
                  icon: AppIcons.check,
                  label: 'Finish Open (Enter)',
                  onTap: () => editor.commitActivePenPath(closed: false),
                ),
                const SizedBox(width: 6),
                _BarActionButton(
                  icon: AppIcons.polygon,
                  label: 'Close Path',
                  onTap: () => editor.commitActivePenPath(closed: true),
                ),
                const SizedBox(width: 6),
              ],
              _BarActionButton(
                icon: AppIcons.close,
                label: 'Cancel (Esc)',
                onTap: editor.cancelActiveOperation,
              ),
            ] else
              const Flexible(
                child: Text(
                  'Click to add corner points, or click-and-drag to pull smooth Bézier curve handles.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
          ] else if (toolState.activeTool == EditorToolType.node) ...<Widget>[
            if (selectedObjects.length == 1 &&
                selectedObjects.first is PathObject) ...<Widget>[
              _BarActionButton(
                icon: AppIcons.rectangle,
                label: 'Set Corner',
                onTap: () => editor.setSelectedAnchorNodeType(NodeType.corner),
              ),
              const SizedBox(width: 6),
              _BarActionButton(
                icon: AppIcons.ellipse,
                label: 'Set Smooth',
                onTap: () => editor.setSelectedAnchorNodeType(NodeType.smooth),
              ),
              const SizedBox(width: 10),
              const Flexible(
                child: Text(
                  'Tip: Double-click any curve segment to split & insert an anchor.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ] else
              const Flexible(
                child: Text(
                  'Select a Path object to edit its anchors and Bézier handles.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
          ] else if (selectedObjects.isNotEmpty) ...<Widget>[
            if (editor.canGroupSelection) ...<Widget>[
              _BarActionButton(
                icon: AppIcons.group,
                label: 'Group (Ctrl+G)',
                onTap: editor.groupSelection,
              ),
              const SizedBox(width: 6),
            ],
            if (editor.canUngroupSelection) ...<Widget>[
              _BarActionButton(
                icon: AppIcons.ungroup,
                label: 'Ungroup',
                onTap: editor.ungroupSelection,
              ),
              const SizedBox(width: 6),
            ],
            if (selectedObjects.length == 1 &&
                selectedObjects.first is TextObject &&
                toolState.activeTextSession == null) ...<Widget>[
              _BarActionButton(
                icon: AppIcons.text,
                label: 'Edit Text',
                onTap: () =>
                    editor.beginInlineTextEditing(selectedObjects.first.id),
              ),
              const SizedBox(width: 6),
            ],
            _BarActionButton(
              icon: AppIcons.duplicate,
              label: 'Duplicate',
              onTap: editor.duplicateSelection,
            ),
            const SizedBox(width: 6),
            _BarActionButton(
              icon: AppIcons.moveUp,
              label: 'Forward',
              onTap: () => editor.moveSelectedInLayer(1),
            ),
            const SizedBox(width: 6),
            _BarActionButton(
              icon: AppIcons.moveDown,
              label: 'Backward',
              onTap: () => editor.moveSelectedInLayer(-1),
            ),
            const SizedBox(width: 6),
            _BarActionButton(
              icon: AppIcons.delete,
              label: 'Delete',
              isDanger: true,
              onTap: editor.deleteSelection,
            ),
          ] else
            const Flexible(
              child: Text(
                'Select an object, press T for Text, or pick a drawing tool on the left.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ),

          const Spacer(),
          _BarActionButton(
            icon: AppIcons.findArtwork,
            label: 'Find Artwork',
            onTap: editor.findMyArtwork,
          ),
          const SizedBox(width: 6),
          _BarActionButton(
            icon: AppIcons.fitView,
            label: 'Fit Artboard',
            onTap: () {
              final doc = ref.read(currentDocumentProvider);
              ref.read(viewportControllerProvider.notifier).fitArtboard(
                    docWidth: doc.width,
                    docHeight: doc.height,
                  );
            },
          ),
        ],
      ),
    );
  }
}

class _CompactFontDropdown extends StatelessWidget {
  final String currentFamily;
  final ValueChanged<String> onChanged;

  const _CompactFontDropdown({
    required this.currentFamily,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final families = <String>[
      for (final f in FontCatalog.curatedFonts) f.family,
    ];
    if (!families.contains(currentFamily)) {
      families.insert(0, currentFamily);
    }

    return Container(
      height: 24,
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentFamily,
          isDense: true,
          isExpanded: true,
          dropdownColor: AppColors.secondarySurface,
          style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
          items: families
              .map(
                (f) => DropdownMenuItem<String>(
                  value: f,
                  child: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _BarIconToggle extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _BarIconToggle({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                selected ? AppColors.surfaceActive : AppColors.inputBackground,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Icon(
            icon,
            size: 12.5,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _StepperSetting extends StatelessWidget {
  final String label;
  final String valueText;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _StepperSetting({
    required this.label,
    required this.valueText,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 6),
        Container(
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              InkWell(
                onTap: onDecrement,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Icon(
                    AppIcons.remove,
                    size: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  valueText,
                  style: AppTheme.monoStyle(fontSize: 11),
                ),
              ),
              InkWell(
                onTap: onIncrement,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Icon(
                    AppIcons.add,
                    size: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDanger;
  final VoidCallback onTap;

  const _BarActionButton({
    required this.icon,
    required this.label,
    this.isDanger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDanger ? AppColors.danger : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDanger ? AppColors.dangerSubtle : AppColors.secondarySurface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12.5, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
