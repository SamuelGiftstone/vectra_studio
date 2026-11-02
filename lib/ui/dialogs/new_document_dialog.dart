import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/editor_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/color_utils.dart';
import '../../core/utils/validation_utils.dart';
import '../inspector/color_picker_dialog.dart';

/// Configuration returned when confirming [NewDocumentDialog].
class NewDocumentConfig {
  final String name;
  final double width;
  final double height;
  final Color backgroundColor;

  const NewDocumentConfig({
    required this.name,
    required this.width,
    required this.height,
    required this.backgroundColor,
  });
}

/// Dialog for creating a new vector document with presets or custom dimensions.
class NewDocumentDialog extends StatefulWidget {
  const NewDocumentDialog({super.key});

  static Future<NewDocumentConfig?> show(BuildContext context) {
    return showDialog<NewDocumentConfig>(
      context: context,
      builder: (_) => const NewDocumentDialog(),
    );
  }

  @override
  State<NewDocumentDialog> createState() => _NewDocumentDialogState();
}

class _NewDocumentDialogState extends State<NewDocumentDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  int _selectedPresetIndex = 0;
  Color _backgroundColor = AppColors.artboardDefaultBg;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final initialPreset = EditorConstants.artboardPresets.first;
    _nameController = TextEditingController(text: 'Untitled Artwork');
    _widthController =
        TextEditingController(text: initialPreset.width.round().toString());
    _heightController =
        TextEditingController(text: initialPreset.height.round().toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _applyPreset(int index) {
    final preset = EditorConstants.artboardPresets[index];
    setState(() {
      _selectedPresetIndex = index;
      _widthController.text = preset.width.round().toString();
      _heightController.text = preset.height.round().toString();
      _validationError = null;
    });
  }

  void _submit() {
    final parsedW = double.tryParse(_widthController.text.trim());
    final parsedH = double.tryParse(_heightController.text.trim());

    if (parsedW == null ||
        parsedH == null ||
        parsedW < EditorConstants.minArtboardSize ||
        parsedH < EditorConstants.minArtboardSize ||
        parsedW > EditorConstants.maxArtboardSize ||
        parsedH > EditorConstants.maxArtboardSize) {
      setState(() {
        _validationError =
            'Dimensions must be between ${EditorConstants.minArtboardSize.round()} and ${EditorConstants.maxArtboardSize.round()} px.';
      });
      return;
    }

    final docName = _nameController.text.trim().isEmpty
        ? 'Untitled Artwork'
        : _nameController.text.trim();

    Navigator.of(context).pop(
      NewDocumentConfig(
        name: docName,
        width: ValidationUtils.clampDouble(
          parsedW,
          EditorConstants.minArtboardSize,
          EditorConstants.maxArtboardSize,
        ),
        height: ValidationUtils.clampDouble(
          parsedH,
          EditorConstants.minArtboardSize,
          EditorConstants.maxArtboardSize,
        ),
        backgroundColor: _backgroundColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'New Vector Document',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose an artboard size preset or specify custom pixel dimensions.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text(
              'PRESETS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.generate(
                EditorConstants.artboardPresets.length,
                (index) {
                  final preset = EditorConstants.artboardPresets[index];
                  final isSelected = _selectedPresetIndex == index;
                  return InkWell(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                    onTap: () => _applyPreset(index),
                    child: Container(
                      width: 152,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.surfaceActive
                            : AppColors.secondarySurface,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            preset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${preset.width.round()} × ${preset.height.round()} px',
                            style: AppTheme.monoStyle(
                              fontSize: 10.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'DOCUMENT SETTINGS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                labelText: 'Document Name',
                labelStyle:
                    TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _widthController,
                    keyboardType: TextInputType.number,
                    style: AppTheme.monoStyle(fontSize: 12),
                    onChanged: (_) => setState(() => _selectedPresetIndex = -1),
                    decoration: const InputDecoration(
                      labelText: 'Width (px)',
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    style: AppTheme.monoStyle(fontSize: 12),
                    onChanged: (_) => setState(() => _selectedPresetIndex = -1),
                    decoration: const InputDecoration(
                      labelText: 'Height (px)',
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  onTap: () async {
                    final chosen = await ColorPickerDialog.show(
                      context,
                      initialColor: _backgroundColor,
                      title: 'Artboard Background',
                    );
                    if (chosen != null) {
                      setState(() => _backgroundColor = chosen);
                    }
                  },
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _backgroundColor,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: AppColors.border),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ColorUtils.toHex(_backgroundColor),
                          style: AppTheme.monoStyle(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_validationError != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _validationError!,
                style: const TextStyle(fontSize: 11.5, color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.mainBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                  ),
                  child: const Text('Create Document'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
