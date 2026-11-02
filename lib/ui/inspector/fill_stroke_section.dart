import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/color_utils.dart';
import '../../editor/editor_commands.dart';
import '../../models/image_object.dart';
import '../../models/line_object.dart';
import '../../models/stroke_style.dart';
import '../../models/text_object.dart';
import '../../models/vector_object.dart';
import '../../providers/editor_providers.dart';
import 'color_picker_dialog.dart';
import 'numeric_field.dart';

/// Inspector section for Fill color/enable, Stroke color/width/cap/join, and Object Opacity.
class FillStrokeSection extends ConsumerWidget {
  final VectorObject primaryObject;
  final Set<String> targetIds;

  const FillStrokeSection({
    super.key,
    required this.primaryObject,
    required this.targetIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docCtrl = ref.read(documentControllerProvider.notifier);
    final toolCtrl = ref.read(toolControllerProvider.notifier);
    final isLocked = primaryObject.locked;
    final supportsFill =
        primaryObject is! LineObject && primaryObject is! ImageObject;
    final isText = primaryObject is TextObject;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // OPACITY SLIDER
        Row(
          children: <Widget>[
            const Text(
              'OPACITY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Text(
              '${(primaryObject.opacity * 100).round()}%',
              style: AppTheme.monoStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        Slider(
          value: primaryObject.opacity.clamp(0.0, 1.0),
          min: 0.0,
          max: 1.0,
          onChangeStart: isLocked
              ? null
              : (_) => docCtrl.beginInteractiveTransaction(
                    currentSelection: targetIds,
                  ),
          onChanged: isLocked
              ? null
              : (val) {
                  final nextDoc = EditorCommands.updateOpacity(
                    ref.read(currentDocumentProvider),
                    targetIds,
                    val,
                  );
                  docCtrl.updateInteractiveDocument(nextDoc);
                },
          onChangeEnd: isLocked
              ? null
              : (_) => docCtrl.commitInteractiveTransaction(
                    label: 'Change Opacity',
                    afterSelection: targetIds,
                  ),
        ),
        const Divider(height: 18, color: AppColors.border),

        // FILL SECTION
        if (supportsFill) ...<Widget>[
          Row(
            children: <Widget>[
              Text(
                isText ? 'TEXT COLOR' : 'FILL',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(
                  value: primaryObject.fill.isEnabled,
                  activeColor: AppColors.accent,
                  onChanged: isLocked
                      ? null
                      : (checked) {
                          final enabled = checked ?? true;
                          docCtrl.executeEdit(
                            label: enabled ? 'Enable Fill' : 'Disable Fill',
                            mutator: (doc) => EditorCommands.updateFill(
                              doc,
                              targetIds,
                              (f) => f.copyWith(isEnabled: enabled),
                            ),
                            beforeSelection: targetIds,
                          );
                          toolCtrl.setDefaultFill(
                            primaryObject.fill.copyWith(isEnabled: enabled),
                          );
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: _ColorSwatchButton(
                  color: primaryObject.fill.color,
                  isEnabled: primaryObject.fill.isEnabled && !isLocked,
                  onTap: () async {
                    final picked = await ColorPickerDialog.show(
                      context,
                      initialColor: primaryObject.fill.color,
                      title: isText ? 'Text Color' : 'Fill Color',
                    );
                    if (picked != null) {
                      final nextFill = primaryObject.fill.copyWith(
                        color: picked,
                        isEnabled: true,
                      );
                      docCtrl.executeEdit(
                        label: isText ? 'Change Text Color' : 'Change Fill Color',
                        mutator: (doc) => EditorCommands.updateFill(
                          doc,
                          targetIds,
                          (f) => f.copyWith(color: picked, isEnabled: true),
                        ),
                        beforeSelection: targetIds,
                      );
                      if (isText) {
                        toolCtrl.setTextDefaults(textFill: nextFill);
                      } else {
                        toolCtrl.setDefaultFill(nextFill);
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 84,
                child: NumericInspectorField(
                  ownerKey: '${primaryObject.id}_fill_alpha',
                  label: '%',
                  value: primaryObject.fill.opacity * 100.0,
                  decimals: 0,
                  min: 0,
                  max: 100,
                  enabled: primaryObject.fill.isEnabled && !isLocked,
                  onCommitted: (pct) {
                    docCtrl.executeEdit(
                      label: 'Change Fill Opacity',
                      mutator: (doc) => EditorCommands.updateFill(
                        doc,
                        targetIds,
                        (f) => f.copyWith(opacity: pct / 100.0),
                      ),
                      beforeSelection: targetIds,
                    );
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: AppColors.border),
        ],

        // STROKE SECTION
        Row(
          children: <Widget>[
            const Text(
              'STROKE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 20,
              width: 20,
              child: Checkbox(
                value: primaryObject.stroke.isEnabled,
                activeColor: AppColors.accent,
                onChanged: isLocked
                    ? null
                    : (checked) {
                        final enabled = checked ?? true;
                        docCtrl.executeEdit(
                          label: enabled ? 'Enable Stroke' : 'Disable Stroke',
                          mutator: (doc) => EditorCommands.updateStroke(
                            doc,
                            targetIds,
                            (s) => s.copyWith(isEnabled: enabled),
                          ),
                          beforeSelection: targetIds,
                        );
                        toolCtrl.setDefaultStroke(
                          primaryObject.stroke.copyWith(isEnabled: enabled),
                        );
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: _ColorSwatchButton(
                color: primaryObject.stroke.color,
                isEnabled: primaryObject.stroke.isEnabled && !isLocked,
                onTap: () async {
                  final picked = await ColorPickerDialog.show(
                    context,
                    initialColor: primaryObject.stroke.color,
                    title: 'Stroke Color',
                  );
                  if (picked != null) {
                    docCtrl.executeEdit(
                      label: 'Change Stroke Color',
                      mutator: (doc) => EditorCommands.updateStroke(
                        doc,
                        targetIds,
                        (s) => s.copyWith(color: picked, isEnabled: true),
                      ),
                      beforeSelection: targetIds,
                    );
                    toolCtrl.setDefaultStroke(
                      primaryObject.stroke.copyWith(
                        color: picked,
                        isEnabled: true,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 84,
              child: NumericInspectorField(
                ownerKey: '${primaryObject.id}_stroke_w',
                label: 'Px',
                value: primaryObject.stroke.width,
                decimals: 1,
                min: 0.0,
                max: 250.0,
                enabled: primaryObject.stroke.isEnabled && !isLocked,
                onCommitted: (w) {
                  docCtrl.executeEdit(
                    label: 'Change Stroke Width',
                    mutator: (doc) => EditorCommands.updateStroke(
                      doc,
                      targetIds,
                      (s) => s.copyWith(width: w),
                    ),
                    beforeSelection: targetIds,
                  );
                  toolCtrl.setDefaultStroke(
                    primaryObject.stroke.copyWith(width: w),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: _StrokeEnumDropdown<VectorStrokeCap>(
                label: 'Cap',
                value: primaryObject.stroke.cap,
                values: VectorStrokeCap.values,
                nameBuilder: (v) => v.name,
                enabled: primaryObject.stroke.isEnabled && !isLocked,
                onChanged: (cap) {
                  docCtrl.executeEdit(
                    label: 'Change Stroke Cap',
                    mutator: (doc) => EditorCommands.updateStroke(
                      doc,
                      targetIds,
                      (s) => s.copyWith(cap: cap),
                    ),
                    beforeSelection: targetIds,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StrokeEnumDropdown<VectorStrokeJoin>(
                label: 'Join',
                value: primaryObject.stroke.join,
                values: VectorStrokeJoin.values,
                nameBuilder: (v) => v.name,
                enabled: primaryObject.stroke.isEnabled && !isLocked,
                onChanged: (join) {
                  docCtrl.executeEdit(
                    label: 'Change Stroke Join',
                    mutator: (doc) => EditorCommands.updateStroke(
                      doc,
                      targetIds,
                      (s) => s.copyWith(join: join),
                    ),
                    beforeSelection: targetIds,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ColorSwatchButton extends StatelessWidget {
  final Color color;
  final bool isEnabled;
  final VoidCallback onTap;

  const _ColorSwatchButton({
    required this.color,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Container(
        height: AppDimensions.inputHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: isEnabled ? color : color.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: AppColors.border),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ColorUtils.toHex(color),
                style: AppTheme.monoStyle(
                  fontSize: 11.5,
                  color:
                      isEnabled ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrokeEnumDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> values;
  final String Function(T) nameBuilder;
  final bool enabled;
  final ValueChanged<T> onChanged;

  const _StrokeEnumDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.nameBuilder,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.inputHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isDense: true,
                isExpanded: true,
                dropdownColor: AppColors.secondarySurface,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textPrimary,
                ),
                onChanged: enabled
                    ? (next) {
                        if (next != null) onChanged(next);
                      }
                    : null,
                items: values
                    .map(
                      (item) => DropdownMenuItem<T>(
                        value: item,
                        child: Text(nameBuilder(item)),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
