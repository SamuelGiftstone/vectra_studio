import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/editor_constants.dart';
import '../../editor/editor_commands.dart';
import '../../models/text_object.dart';
import '../../providers/editor_providers.dart';
import '../../rendering/font_catalog.dart';
import 'numeric_field.dart';

/// Inspector section for [TextObject] typography, text content, Point vs Area Frame
/// mode switching, alignment, weight, italic style, line height, and letter spacing.
class TextPropertiesSection extends ConsumerStatefulWidget {
  final TextObject textObject;

  const TextPropertiesSection({
    super.key,
    required this.textObject,
  });

  @override
  ConsumerState<TextPropertiesSection> createState() =>
      _TextPropertiesSectionState();
}

class _TextPropertiesSectionState extends ConsumerState<TextPropertiesSection> {
  late final TextEditingController _contentController;
  late final FocusNode _contentFocus;
  late String _boundObjectId;

  @override
  void initState() {
    super.initState();
    _boundObjectId = widget.textObject.id;
    _contentController = TextEditingController(text: widget.textObject.text);
    _contentFocus = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant TextPropertiesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.textObject.id != _boundObjectId) {
      _boundObjectId = widget.textObject.id;
      _contentController.text = widget.textObject.text;
    } else if (!_contentFocus.hasFocus &&
        _contentController.text != widget.textObject.text) {
      _contentController.text = widget.textObject.text;
    }
  }

  @override
  void dispose() {
    _contentFocus.removeListener(_handleFocusChange);
    _contentFocus.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_contentFocus.hasFocus) {
      _commitTextContent();
    }
  }

  void _commitTextContent() {
    final obj = widget.textObject;
    if (obj.id != _boundObjectId || obj.locked) return;
    final nextText = _contentController.text;
    if (nextText.trim().isEmpty) {
      _contentController.text = obj.text;
      return;
    }
    if (nextText == obj.text) return;

    ref.read(documentControllerProvider.notifier).executeEdit(
          label: 'Edit Text Content',
          mutator: (doc) => EditorCommands.updateTextObject(
            doc,
            obj.id,
            (curr) => curr.copyWith(text: nextText),
          ),
          beforeSelection: ref.read(selectedIdsProvider),
        );
  }

  @override
  Widget build(BuildContext context) {
    final obj = widget.textObject;
    final docCtrl = ref.read(documentControllerProvider.notifier);
    final toolCtrl = ref.read(toolControllerProvider.notifier);
    final editor = ref.read(editorControllerProvider);
    final selectedIds = ref.read(selectedIdsProvider);
    final activeSession = ref.watch(activeTextSessionProvider);
    final isInlineEditingThis = activeSession?.objectId == obj.id;
    final isLocked = obj.locked;

    // Ensure custom imported SVG font families and weights always exist in dropdown items
    final familyOptions = <String>[
      for (final opt in FontCatalog.curatedFonts) opt.family,
    ];
    final currentFamily = obj.fontFamily.trim().isEmpty
        ? EditorConstants.defaultFontFamily
        : obj.fontFamily.trim();
    if (!familyOptions.contains(currentFamily)) {
      familyOptions.insert(0, currentFamily);
    }

    final weightOptions = List<int>.of(FontCatalog.supportedWeights);
    if (!weightOptions.contains(obj.fontWeightValue)) {
      weightOptions
        ..add(obj.fontWeightValue)
        ..sort();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text(
              'TYPOGRAPHY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: isLocked
                  ? null
                  : () {
                      docCtrl.executeEdit(
                        label: obj.isAreaText
                            ? 'Convert to Point Text'
                            : 'Convert to Frame Text',
                        mutator: (doc) => EditorCommands.updateTextObject(
                          doc,
                          obj.id,
                          (curr) => curr.toggleAreaTextMode(),
                        ),
                        beforeSelection: selectedIds,
                      );
                    },
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  obj.isAreaText ? 'Area Frame' : 'Point Text',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Inline edit button + multiline content box
        SizedBox(
          width: double.infinity,
          height: 26,
          child: OutlinedButton.icon(
            onPressed: isLocked
                ? null
                : () {
                    if (isInlineEditingThis) {
                      editor.commitInlineTextEditing();
                    } else {
                      editor.beginInlineTextEditing(obj.id);
                    }
                  },
            icon: Icon(
              isInlineEditingThis ? AppIcons.check : AppIcons.text,
              size: 13,
            ),
            label: Text(
              isInlineEditingThis
                  ? 'Finish Inline Canvas Edit'
                  : 'Edit Inline on Canvas (Double-Click)',
              style: const TextStyle(fontSize: 11),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  isInlineEditingThis ? AppColors.accent : AppColors.textPrimary,
              side: BorderSide(
                color: isInlineEditingThis ? AppColors.accent : AppColors.border,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (!isInlineEditingThis)
          TextField(
            controller: _contentController,
            focusNode: _contentFocus,
            enabled: !isLocked,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(fontSize: 11.5, height: 1.35),
            decoration: const InputDecoration(
              hintText: 'Text content...',
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            ),
          ),
        if (!isInlineEditingThis) const SizedBox(height: 10),

        // Font Family Dropdown
        Container(
          height: AppDimensions.inputHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
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
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textPrimary,
              ),
              onChanged: isLocked
                  ? null
                  : (nextFamily) {
                      if (nextFamily == null) return;
                      docCtrl.executeEdit(
                        label: 'Change Font Family',
                        mutator: (doc) => EditorCommands.updateTextObject(
                          doc,
                          obj.id,
                          (curr) => curr.copyWith(fontFamily: nextFamily),
                        ),
                        beforeSelection: selectedIds,
                      );
                      toolCtrl.setTextDefaults(fontFamily: nextFamily);
                    },
              items: familyOptions.map((family) {
                return DropdownMenuItem<String>(
                  value: family,
                  child: Text(
                    family,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Font Size + Font Weight
        Row(
          children: <Widget>[
            SizedBox(
              width: 92,
              child: NumericInspectorField(
                ownerKey: '${obj.id}_font_size',
                label: 'Sz',
                value: obj.fontSize,
                decimals: 1,
                min: EditorConstants.minFontSize,
                max: EditorConstants.maxFontSize,
                enabled: !isLocked,
                onCommitted: (nextSize) {
                  docCtrl.executeEdit(
                    label: 'Change Font Size',
                    mutator: (doc) => EditorCommands.updateTextObject(
                      doc,
                      obj.id,
                      (curr) => curr.copyWith(fontSize: nextSize),
                    ),
                    beforeSelection: selectedIds,
                  );
                  toolCtrl.setTextDefaults(fontSize: nextSize);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: AppDimensions.inputHeight,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: obj.fontWeightValue,
                    isDense: true,
                    isExpanded: true,
                    dropdownColor: AppColors.secondarySurface,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textPrimary,
                    ),
                    onChanged: isLocked
                        ? null
                        : (nextWeight) {
                            if (nextWeight == null) return;
                            docCtrl.executeEdit(
                              label: 'Change Font Weight',
                              mutator: (doc) => EditorCommands.updateTextObject(
                                doc,
                                obj.id,
                                (curr) =>
                                    curr.copyWith(fontWeightValue: nextWeight),
                              ),
                              beforeSelection: selectedIds,
                            );
                            toolCtrl.setTextDefaults(fontWeight: nextWeight);
                          },
                    items: weightOptions.map((weight) {
                      return DropdownMenuItem<int>(
                        value: weight,
                        child: Text(
                          FontCatalog.weightLabel(weight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Style toggles (Bold, Italic) + Text Alignment (Left, Center, Right, Justify)
        Row(
          children: <Widget>[
            _IconToggleChip(
              icon: AppIcons.bold,
              tooltip: 'Bold',
              selected: obj.isBold,
              enabled: !isLocked,
              onTap: () {
                final nextWeight = obj.isBold ? 400 : 700;
                docCtrl.executeEdit(
                  label: obj.isBold ? 'Remove Bold' : 'Apply Bold',
                  mutator: (doc) => EditorCommands.updateTextObject(
                    doc,
                    obj.id,
                    (curr) => curr.copyWith(fontWeightValue: nextWeight),
                  ),
                  beforeSelection: selectedIds,
                );
                toolCtrl.setTextDefaults(fontWeight: nextWeight);
              },
            ),
            const SizedBox(width: 4),
            _IconToggleChip(
              icon: AppIcons.italic,
              tooltip: 'Italic',
              selected: obj.isItalic,
              enabled: !isLocked,
              onTap: () {
                final nextItalic = !obj.isItalic;
                docCtrl.executeEdit(
                  label: nextItalic ? 'Apply Italic' : 'Remove Italic',
                  mutator: (doc) => EditorCommands.updateTextObject(
                    doc,
                    obj.id,
                    (curr) => curr.copyWith(isItalic: nextItalic),
                  ),
                  beforeSelection: selectedIds,
                );
                toolCtrl.setTextDefaults(isItalic: nextItalic);
              },
            ),
            const Spacer(),
            _IconToggleChip(
              icon: AppIcons.alignLeft,
              tooltip: 'Align Left',
              selected: obj.textAlign == TextAlign.left ||
                  obj.textAlign == TextAlign.start,
              enabled: !isLocked,
              onTap: () => _setAlignment(TextAlign.left),
            ),
            const SizedBox(width: 4),
            _IconToggleChip(
              icon: AppIcons.alignCenter,
              tooltip: 'Align Center',
              selected: obj.textAlign == TextAlign.center,
              enabled: !isLocked,
              onTap: () => _setAlignment(TextAlign.center),
            ),
            const SizedBox(width: 4),
            _IconToggleChip(
              icon: AppIcons.alignRight,
              tooltip: 'Align Right',
              selected: obj.textAlign == TextAlign.right ||
                  obj.textAlign == TextAlign.end,
              enabled: !isLocked,
              onTap: () => _setAlignment(TextAlign.right),
            ),
            const SizedBox(width: 4),
            _IconToggleChip(
              icon: AppIcons.alignJustify,
              tooltip: 'Justify (Area Text)',
              selected: obj.textAlign == TextAlign.justify,
              enabled: !isLocked,
              onTap: () => _setAlignment(TextAlign.justify),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Line Height + Letter Spacing
        Row(
          children: <Widget>[
            Expanded(
              child: NumericInspectorField(
                ownerKey: '${obj.id}_line_height',
                label: 'LH',
                value: obj.lineHeight,
                decimals: 2,
                min: 0.6,
                max: 5.0,
                enabled: !isLocked,
                onCommitted: (lh) {
                  docCtrl.executeEdit(
                    label: 'Change Line Height',
                    mutator: (doc) => EditorCommands.updateTextObject(
                      doc,
                      obj.id,
                      (curr) => curr.copyWith(lineHeight: lh),
                    ),
                    beforeSelection: selectedIds,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumericInspectorField(
                ownerKey: '${obj.id}_letter_spacing',
                label: 'Trk',
                value: obj.letterSpacing,
                decimals: 1,
                min: -20.0,
                max: 100.0,
                enabled: !isLocked,
                onCommitted: (ls) {
                  docCtrl.executeEdit(
                    label: 'Change Letter Spacing',
                    mutator: (doc) => EditorCommands.updateTextObject(
                      doc,
                      obj.id,
                      (curr) => curr.copyWith(letterSpacing: ls),
                    ),
                    beforeSelection: selectedIds,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _setAlignment(TextAlign align) {
    final obj = widget.textObject;
    ref.read(documentControllerProvider.notifier).executeEdit(
          label: 'Change Text Alignment',
          mutator: (doc) => EditorCommands.updateTextObject(
            doc,
            obj.id,
            (curr) => curr.copyWith(textAlign: align),
          ),
          beforeSelection: ref.read(selectedIdsProvider),
        );
    ref.read(toolControllerProvider.notifier).setTextDefaults(textAlign: align);
  }
}

class _IconToggleChip extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _IconToggleChip({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: Container(
          width: 28,
          height: 26,
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
            size: 13.5,
            color: !enabled
                ? AppColors.textMuted
                : (selected ? AppColors.accent : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
