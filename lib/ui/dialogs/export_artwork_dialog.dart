import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/editor_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/color_utils.dart';
import '../../models/vector_document.dart';
import '../../storage/document_export_service.dart';
import '../inspector/color_picker_dialog.dart';

/// Desktop modal dialog for configuring and executing SVG, PNG, or JPEG artwork export.
class ExportArtworkDialog extends StatefulWidget {
  final VectorDocument document;
  final ExportFormat initialFormat;
  final VoidCallback? onInspectSvgMarkup;

  const ExportArtworkDialog({
    super.key,
    required this.document,
    this.initialFormat = ExportFormat.png,
    this.onInspectSvgMarkup,
  });

  static Future<ExportConfig?> show(
    BuildContext context, {
    required VectorDocument document,
    ExportFormat initialFormat = ExportFormat.png,
    VoidCallback? onInspectSvgMarkup,
  }) {
    return showDialog<ExportConfig>(
      context: context,
      builder: (_) => ExportArtworkDialog(
        document: document,
        initialFormat: initialFormat,
        onInspectSvgMarkup: onInspectSvgMarkup,
      ),
    );
  }

  @override
  State<ExportArtworkDialog> createState() => _ExportArtworkDialogState();
}

class _ExportArtworkDialogState extends State<ExportArtworkDialog> {
  static const List<double> _scales = <double>[1.0, 2.0, 3.0, 4.0];

  late ExportFormat _format;
  double _scale = 1.0;
  bool _includeBackground = true;
  late Color _jpegBackground;
  int _jpegQuality = EditorConstants.defaultJpegQuality;

  @override
  void initState() {
    super.initState();
    _format = widget.initialFormat;
    _jpegBackground = widget.document.backgroundColor.alpha > 0
        ? widget.document.backgroundColor.withAlpha(255)
        : const Color(0xFFFFFFFF);
  }

  ExportConfig get _currentConfig => ExportConfig(
        format: _format,
        scale: _scale,
        includeBackground: _includeBackground,
        jpegBackgroundColor: _jpegBackground,
        jpegQuality: _jpegQuality,
      );

  @override
  Widget build(BuildContext context) {
    final config = _currentConfig;
    final outW = config.outputWidth(widget.document);
    final outH = config.outputHeight(widget.document);

    return Dialog(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  AppIcons.exportSvg,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  'Export Artwork',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Renders clean artwork from "${widget.document.name}" with zero editor overlays.',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // FORMAT TABS
            const Text(
              'FORMAT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: _FormatChoiceCard(
                    title: 'SVG',
                    subtitle: 'Vector',
                    selected: _format == ExportFormat.svg,
                    onTap: () => setState(() => _format = ExportFormat.svg),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FormatChoiceCard(
                    title: 'PNG',
                    subtitle: 'Lossless',
                    selected: _format == ExportFormat.png,
                    onTap: () => setState(() => _format = ExportFormat.png),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FormatChoiceCard(
                    title: 'JPEG',
                    subtitle: 'Compressed',
                    selected: _format == ExportFormat.jpeg,
                    onTap: () => setState(() => _format = ExportFormat.jpeg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // SCALE & OUTPUT RESOLUTION
            Row(
              children: <Widget>[
                const Text(
                  'RESOLUTION SCALE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                Text(
                  '$outW × $outH px',
                  style: AppTheme.monoStyle(
                    fontSize: 11.5,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: _scales.map((s) {
                final isSelected = (_scale - s).abs() < 0.01;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: s == _scales.last ? 0 : 6),
                    child: InkWell(
                      onTap: () => setState(() => _scale = s),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSm),
                      child: Container(
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.surfaceActive
                              : AppColors.inputBackground,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusSm),
                          border: Border.all(
                            color:
                                isSelected ? AppColors.accent : AppColors.border,
                          ),
                        ),
                        child: Text(
                          '${s.round()}x',
                          style: AppTheme.monoStyle(
                            fontSize: 11.5,
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // FORMAT-SPECIFIC OPTIONS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondarySurface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: _buildFormatOptions(context),
            ),
            const SizedBox(height: 18),

            // DIALOG ACTIONS
            Row(
              children: <Widget>[
                if (_format == ExportFormat.svg &&
                    widget.onInspectSvgMarkup != null)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onInspectSvgMarkup!();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                    ),
                    child: const Text('Inspect SVG Code...'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_currentConfig),
                  icon: const Icon(AppIcons.save, size: 14),
                  label: Text('Export .${_format.extension}'),
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

  Widget _buildFormatOptions(BuildContext context) {
    switch (_format) {
      case ExportFormat.svg:
        return Row(
          children: <Widget>[
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Include Artboard Background',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Exports shapes, Bézier paths, editable <text>, groups, and images.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Switch(
              value: _includeBackground,
              activeColor: AppColors.accent,
              onChanged: (v) => setState(() => _includeBackground = v),
            ),
          ],
        );

      case ExportFormat.png:
        final transparent = !_includeBackground;
        return Row(
          children: <Widget>[
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Transparent Background (Alpha)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Omits the artboard fill so artwork exports on clean RGBA alpha.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Switch(
              value: transparent,
              activeColor: AppColors.accent,
              onChanged: (isTransp) =>
                  setState(() => _includeBackground = !isTransp),
            ),
          ],
        );

      case ExportFormat.jpeg:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Opaque Background Color',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () async {
                    final picked = await ColorPickerDialog.show(
                      context,
                      initialColor: _jpegBackground,
                      title: 'JPEG Background Color',
                    );
                    if (picked != null && mounted) {
                      setState(() => _jpegBackground = picked.withAlpha(255));
                    }
                  },
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _jpegBackground,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: AppColors.border),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          ColorUtils.toHex(_jpegBackground),
                          style: AppTheme.monoStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Text(
                  'JPEG Quality',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '$_jpegQuality%',
                  style: AppTheme.monoStyle(
                    fontSize: 11.5,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            Slider(
              value: _jpegQuality.toDouble(),
              min: 10,
              max: 100,
              divisions: 18,
              onChanged: (v) => setState(() => _jpegQuality = v.round()),
            ),
          ],
        );
    }
  }
}

class _FormatChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _FormatChoiceCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceActive : AppColors.inputBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.accent : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
