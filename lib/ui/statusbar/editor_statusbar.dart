import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/editor_providers.dart';

/// Bottom workspace status bar displaying tool hints, live document coordinates,
/// object/selection counts, status messages, and zoom controls.
class EditorStatusbar extends ConsumerWidget {
  const EditorStatusbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool = ref.watch(activeToolProvider);
    final cursorDoc = ref.watch(cursorDocPositionProvider);
    final zoomPct = ref.watch(zoomPercentageProvider);
    final statusMsg = ref.watch(statusMessageProvider);
    final doc = ref.watch(currentDocumentProvider);
    final selectionCount = ref.watch(
      selectedIdsProvider.select((ids) => ids.length),
    );
    final viewportCtrl = ref.read(viewportControllerProvider.notifier);

    return Container(
      height: AppDimensions.statusBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: AppColors.mainBackground,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(
            activeTool.statusHint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            statusMsg,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          Container(width: 1, height: 12, color: AppColors.border),
          const SizedBox(width: 10),
          SizedBox(
            width: 128,
            child: Text(
              cursorDoc == null
                  ? 'X: —   Y: —'
                  : 'X: ${cursorDoc.x.toStringAsFixed(1)}  Y: ${cursorDoc.y.toStringAsFixed(1)}',
              style: AppTheme.monoStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Container(width: 1, height: 12, color: AppColors.border),
          const SizedBox(width: 10),
          Text(
            selectionCount > 0
                ? '$selectionCount / ${doc.objectCount} selected'
                : '${doc.objectCount} objects',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 12, color: AppColors.border),
          const SizedBox(width: 6),
          InkWell(
            onTap: viewportCtrl.zoomOut,
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(
                AppIcons.zoomOut,
                size: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          InkWell(
            onTap: () => viewportCtrl.resetZoomTo100(
              docWidth: doc.width,
              docHeight: doc.height,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '$zoomPct%',
                style: AppTheme.monoStyle(
                  fontSize: 11,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: viewportCtrl.zoomIn,
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(
                AppIcons.zoomIn,
                size: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
