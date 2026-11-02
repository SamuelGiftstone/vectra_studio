import 'dart:io' show Platform;

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_icons.dart';
import '../../providers/editor_providers.dart';
import '../dialogs/workflow_dialogs.dart';

bool get _isDesktopWindowSupported =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// Custom desktop window title bar powered by `bitsdojo_window` with File/Edit/View
/// menus, active `.vectra` document indicator, draggable title bar region,
/// and native Minimize / Maximize-Restore / Close controls.
class CustomTitleBar extends ConsumerStatefulWidget {
  const CustomTitleBar({super.key});

  @override
  ConsumerState<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends ConsumerState<CustomTitleBar> {
  void _maximizeOrRestore() {
    if (!_isDesktopWindowSupported) return;
    setState(() {
      appWindow.maximizeOrRestore();
    });
  }

  Future<void> _requestCloseWindow() async {
    final canClose =
        await WorkflowDialogs.confirmDiscardOrSaveIfNeeded(context, ref);
    if (!canClose) return;
    if (_isDesktopWindowSupported) {
      appWindow.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(currentDocumentProvider);
    final isDirty = ref.watch(isDocumentDirtyProvider);
    final filePath = ref.watch(currentFilePathProvider);
    final history = ref.watch(historyAvailabilityProvider);
    final selectedIds = ref.watch(selectedIdsProvider);
    final hasSelection = selectedIds.isNotEmpty;
    final showGrid = ref.watch(showGridProvider);
    final tagMode = ref.watch(tagDisplayModeProvider);
    final editor = ref.read(editorControllerProvider);

    final windowButtonColors = WindowButtonColors(
      normal: Colors.transparent,
      mouseOver: AppColors.surfaceHover,
      mouseDown: AppColors.surfaceActive,
      iconNormal: AppColors.textSecondary,
      iconMouseOver: AppColors.textPrimary,
      iconMouseDown: AppColors.textPrimary,
    );

    final closeButtonColors = WindowButtonColors(
      normal: Colors.transparent,
      mouseOver: AppColors.danger,
      mouseDown: const Color(0xFFB91C1C),
      iconNormal: AppColors.textSecondary,
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.white,
    );

    return Container(
      height: AppDimensions.titleBarHeight,
      decoration: const BoxDecoration(
        color: AppColors.mainBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: WindowTitleBarBox(
        child: Row(
          children: <Widget>[
            const SizedBox(width: 10),
            // Brand emblem
            Image.asset('assets/beautiful-gradient-logo-designs-23 (1).png', height: 20,),
            const Text(
              '',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 14),

            // FILE MENU
            _TitleMenuButton(
              label: 'File',
              items: <PopupMenuEntry<VoidCallback>>[
                _menuItem(
                  icon: AppIcons.newFile,
                  label: 'New Document...',
                  shortcut: 'Ctrl+N',
                  onTap: () => WorkflowDialogs.performNewDocument(context, ref),
                ),
                _menuItem(
                  icon: AppIcons.openFile,
                  label: 'Open Project (.vectra)...',
                  shortcut: 'Ctrl+O',
                  onTap: () => WorkflowDialogs.performOpenProject(context, ref),
                ),
                const PopupMenuDivider(height: 8),
                _menuItem(
                  icon: AppIcons.save,
                  label: 'Save Project',
                  shortcut: 'Ctrl+S',
                  onTap: () => WorkflowDialogs.performSave(context, ref),
                ),
                _menuItem(
                  icon: AppIcons.save,
                  label: 'Save Project As...',
                  shortcut: 'Ctrl+Shift+S',
                  onTap: () => WorkflowDialogs.performSaveAs(context, ref),
                ),
                const PopupMenuDivider(height: 8),
                _menuItem(
                  icon: AppIcons.image,
                  label: 'Import Image (PNG, JPEG, WebP)...',
                  shortcut: 'Ctrl+Shift+I',
                  onTap: () =>
                      WorkflowDialogs.performImportRasterImage(context, ref),
                ),
                _menuItem(
                  icon: AppIcons.openFile,
                  label: 'Import Editable SVG...',
                  shortcut: '',
                  onTap: () => WorkflowDialogs.performImportSvg(context, ref),
                ),
                const PopupMenuDivider(height: 8),
                _menuItem(
                  icon: AppIcons.exportSvg,
                  label: 'Export Artwork (SVG, PNG, JPEG)...',
                  shortcut: 'Ctrl+E',
                  onTap: () =>
                      WorkflowDialogs.performExportArtwork(context, ref),
                ),
                _menuItem(
                  icon: AppIcons.exportSvg,
                  label: 'Inspect & Copy SVG Markup...',
                  shortcut: '',
                  onTap: () => WorkflowDialogs.performExportSvg(
                    context,
                    ref,
                    showPreviewFirst: true,
                  ),
                ),
                if (_isDesktopWindowSupported) ...<PopupMenuEntry<VoidCallback>>[
                  const PopupMenuDivider(height: 8),
                  _menuItem(
                    icon: AppIcons.close,
                    label: 'Exit VECTRA Studio',
                    shortcut: 'Alt+F4',
                    onTap: _requestCloseWindow,
                  ),
                ],
              ],
            ),

            // EDIT MENU
            _TitleMenuButton(
              label: 'Edit',
              items: <PopupMenuEntry<VoidCallback>>[
                _menuItem(
                  icon: AppIcons.undo,
                  label: history.undoLabel != null
                      ? 'Undo ${history.undoLabel}'
                      : 'Undo',
                  shortcut: 'Ctrl+Z',
                  enabled: history.canUndo,
                  onTap: editor.undo,
                ),
                _menuItem(
                  icon: AppIcons.redo,
                  label: history.redoLabel != null
                      ? 'Redo ${history.redoLabel}'
                      : 'Redo',
                  shortcut: 'Ctrl+Shift+Z',
                  enabled: history.canRedo,
                  onTap: editor.redo,
                ),
                const PopupMenuDivider(height: 8),
                _menuItem(
                  icon: AppIcons.group,
                  label: 'Group Selection',
                  shortcut: 'Ctrl+G',
                  enabled: editor.canGroupSelection,
                  onTap: editor.groupSelection,
                ),
                _menuItem(
                  icon: AppIcons.ungroup,
                  label: 'Ungroup Selection',
                  shortcut: 'Ctrl+Shift+G',
                  enabled: editor.canUngroupSelection,
                  onTap: editor.ungroupSelection,
                ),
                const PopupMenuDivider(height: 8),
                _menuItem(
                  icon: AppIcons.duplicate,
                  label: 'Duplicate Selection',
                  shortcut: 'Ctrl+D',
                  enabled: hasSelection,
                  onTap: editor.duplicateSelection,
                ),
                _menuItem(
                  icon: AppIcons.delete,
                  label: 'Delete Selection',
                  shortcut: 'Del',
                  enabled: hasSelection,
                  onTap: editor.deleteSelection,
                ),
                const PopupMenuDivider(height: 8),
                _menuItem(
                  icon: AppIcons.selection,
                  label: 'Select All Unlocked',
                  shortcut: 'Ctrl+A',
                  onTap: editor.selectAllUnlocked,
                ),
              ],
            ),

            // VIEW MENU
            _TitleMenuButton(
              label: 'View',
              items: <PopupMenuEntry<VoidCallback>>[
                _menuItem(
                  icon: AppIcons.findArtwork,
                  label: 'Find My Artwork',
                  shortcut: 'Ctrl+Shift+0',
                  onTap: editor.findMyArtwork,
                ),
                _menuItem(
                  icon: AppIcons.focusSelection,
                  label: 'Focus Selection',
                  shortcut: 'F',
                  enabled: hasSelection,
                  onTap: editor.focusSelection,
                ),
                _menuItem(
                  icon: AppIcons.fitView,
                  label: 'Fit Artboard to Window',
                  shortcut: 'Ctrl+0',
                  onTap: () => ref
                      .read(viewportControllerProvider.notifier)
                      .fitArtboard(docWidth: doc.width, docHeight: doc.height),
                ),
                _menuItem(
                  icon: AppIcons.fitView,
                  label: 'Reset View (100%)',
                  shortcut: 'Ctrl+1',
                  onTap: editor.resetView,
                ),
                const PopupMenuDivider(height: 8),
                _menuItem(
                  icon: AppIcons.zoomIn,
                  label: 'Zoom In',
                  shortcut: '+',
                  onTap: () =>
                      ref.read(viewportControllerProvider.notifier).zoomIn(),
                ),
                _menuItem(
                  icon: AppIcons.zoomOut,
                  label: 'Zoom Out',
                  shortcut: '-',
                  onTap: () =>
                      ref.read(viewportControllerProvider.notifier).zoomOut(),
                ),
                const PopupMenuDivider(height: 8),
                _menuItem(
                  icon: AppIcons.tag,
                  label: 'Object Tags: ${tagMode.label}',
                  shortcut: '',
                  onTap: () => ref
                      .read(viewportControllerProvider.notifier)
                      .cycleTagDisplayMode(),
                ),
                _menuItem(
                  icon: AppIcons.grid,
                  label: showGrid ? 'Hide Artboard Grid' : 'Show Artboard Grid',
                  shortcut: "Ctrl+'",
                  onTap: () => ref
                      .read(viewportControllerProvider.notifier)
                      .toggleGrid(),
                ),
              ],
            ),

            // DRAGGABLE WINDOW REGION + DOCUMENT TITLE
            Expanded(
              child: MoveWindow(
                onDoubleTap: _maximizeOrRestore,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          '${doc.name}${isDirty ? ' *' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDirty
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (filePath != null) ...<Widget>[
                        const SizedBox(width: 6),
                        const Text(
                          '· .vectra',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Quick Save & Export buttons
            Tooltip(
              message: 'Save Project (Ctrl+S)',
              child: InkWell(
                onTap: () => WorkflowDialogs.performSave(context, ref),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Icon(
                    AppIcons.save,
                    size: 15,
                    color:
                        isDirty ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Tooltip(
              message: 'Export Artwork — SVG, PNG, JPEG (Ctrl+E)',
              child: InkWell(
                onTap: () =>
                    WorkflowDialogs.performExportArtwork(context, ref),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Icon(
                    AppIcons.exportSvg,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Native desktop window buttons powered by bitsdojo_window
            if (_isDesktopWindowSupported) ...<Widget>[
              MinimizeWindowButton(colors: windowButtonColors),
              appWindow.isMaximized
                  ? RestoreWindowButton(
                      colors: windowButtonColors,
                      onPressed: _maximizeOrRestore,
                    )
                  : MaximizeWindowButton(
                      colors: windowButtonColors,
                      onPressed: _maximizeOrRestore,
                    ),
              CloseWindowButton(
                colors: closeButtonColors,
                onPressed: _requestCloseWindow,
              ),
            ],
          ],
        ),
      ),
    );
  }

  PopupMenuItem<VoidCallback> _menuItem({
    required IconData icon,
    required String label,
    required String shortcut,
    bool enabled = true,
    required VoidCallback onTap,
  }) {
    return PopupMenuItem<VoidCallback>(
      enabled: enabled,
      height: 32,
      value: onTap,
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            size: 14,
            color: enabled ? AppColors.textSecondary : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
          if (shortcut.isNotEmpty) ...<Widget>[
            const SizedBox(width: 16),
            Text(
              shortcut,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TitleMenuButton extends StatelessWidget {
  final String label;
  final List<PopupMenuEntry<VoidCallback>> items;

  const _TitleMenuButton({
    required this.label,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<VoidCallback>(
      tooltip: '',
      offset: const Offset(0, 32),
      onSelected: (action) => action(),
      itemBuilder: (_) => items,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
