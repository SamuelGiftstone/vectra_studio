import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../editor/viewport_controller.dart';
import '../../providers/editor_providers.dart';

/// Compact floating viewport navigation & tag control bar anchored at the
/// bottom-right of the canvas.
///
/// Provides one-click access to **Find My Artwork**, **Focus Selection**,
/// **Reset 100% View**, and **Object Tag Display Mode**.
class ArtworkNavigationOverlay extends ConsumerWidget {
  const ArtworkNavigationOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoomPct = ref.watch(zoomPercentageProvider);
    final tagMode = ref.watch(tagDisplayModeProvider);
    final hasSelection = ref.watch(
      selectionControllerProvider.select((s) => s.hasSelection),
    );
    final editor = ref.read(editorControllerProvider);
    final viewCtrl = ref.read(viewportControllerProvider.notifier);

    return Positioned(
      right: 14,
      bottom: 14,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {},
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryPanel.withOpacity(0.95),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Find My Artwork primary navigation action
              Tooltip(
                message: 'Find My Artwork — Fit All Visible Objects (Ctrl+Shift+0)',
                child: InkWell(
                  onTap: editor.findMyArtwork,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          AppIcons.findArtwork,
                          size: 13,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Find My Artwork',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 15,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: AppColors.border,
              ),

              // Focus Selection
              Tooltip(
                message: 'Focus Selection (F)',
                child: InkWell(
                  onTap: hasSelection ? editor.focusSelection : null,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Icon(
                      AppIcons.focusSelection,
                      size: 13,
                      color: hasSelection
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),

              // Zoom Out / Reset 100% / Zoom In
              Tooltip(
                message: 'Zoom Out (-)',
                child: InkWell(
                  onTap: viewCtrl.zoomOut,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                    child: Icon(
                      AppIcons.zoomOut,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: 'Click to Reset View to 100% (Ctrl+1)',
                child: InkWell(
                  onTap: editor.resetView,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      '$zoomPct%',
                      style: AppTheme.monoStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: 'Zoom In (+)',
                child: InkWell(
                  onTap: viewCtrl.zoomIn,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                    child: Icon(
                      AppIcons.zoomIn,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 15,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: AppColors.border,
              ),

              // Floating Object Tag Display Mode Toggle
              Tooltip(
                message: 'Object Tags: ${tagMode.label} (click to cycle)',
                child: InkWell(
                  onTap: viewCtrl.cycleTagDisplayMode,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          AppIcons.tag,
                          size: 12.5,
                          color: tagMode == TagDisplayMode.hidden
                              ? AppColors.textMuted
                              : AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tagMode.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: tagMode == TagDisplayMode.hidden
                                ? AppColors.textMuted
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
