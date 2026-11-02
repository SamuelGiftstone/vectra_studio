import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_icons.dart';
import '../../core/theme/app_theme.dart';

/// Dialog allowing users to inspect generated SVG vector markup, copy it, or save `.svg` to disk.
class SvgPreviewDialog extends StatelessWidget {
  final String svgMarkup;
  final String documentName;
  final Future<void> Function() onSaveToFile;

  const SvgPreviewDialog({
    super.key,
    required this.svgMarkup,
    required this.documentName,
    required this.onSaveToFile,
  });

  static Future<void> show(
    BuildContext context, {
    required String svgMarkup,
    required String documentName,
    required Future<void> Function() onSaveToFile,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => SvgPreviewDialog(
        svgMarkup: svgMarkup,
        documentName: documentName,
        onSaveToFile: onSaveToFile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 640,
        height: 480,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  AppIcons.exportSvg,
                  size: 18,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Export SVG — $documentName.svg',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(AppIcons.close, size: 16),
                  splashRadius: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Standards-compliant SVG 1.1 vector output generated directly from the document model.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    svgMarkup,
                    style: AppTheme.monoStyle(
                      fontSize: 11.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: svgMarkup));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('SVG markup copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(AppIcons.duplicate, size: 14),
                  label: const Text('Copy SVG'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await onSaveToFile();
                  },
                  icon: const Icon(AppIcons.exportSvg, size: 14),
                  label: const Text('Save .svg File...'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.mainBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
