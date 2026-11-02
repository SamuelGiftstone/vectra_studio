import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/editor_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/color_utils.dart';
import '../../models/text_object.dart';
import '../../models/vector_document.dart';
import '../../providers/editor_providers.dart';
import '../dialogs/workflow_dialogs.dart';
import 'color_picker_dialog.dart';
import 'fill_stroke_section.dart';
import 'numeric_field.dart';
import 'text_properties_section.dart';
import 'transform_section.dart';

/// Right-side Inspector panel synchronized with the current selection,
/// or displaying Artboard properties when no object is selected.
class PropertiesPanel extends ConsumerWidget {
  const PropertiesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedObjects = ref.watch(selectedObjectsProvider);
    final selectedIds = ref.watch(selectedIdsProvider);

    return Container(
      color: AppColors.primaryPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: AppColors.secondarySurface,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  AppIcons.sliders,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                const Text(
                  'INSPECTOR',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (selectedObjects.length > 1)
                  Text(
                    '${selectedObjects.length} selected',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.accent,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: selectedObjects.isEmpty
                  ? const _ArtboardInspectorView()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (selectedObjects.length == 1) ...<Widget>[
                          TransformSection(object: selectedObjects.first),
                          const Divider(height: 22, color: AppColors.border),
                          if (selectedObjects.first is TextObject) ...<Widget>[
                            TextPropertiesSection(
                              textObject: selectedObjects.first as TextObject,
                            ),
                            const Divider(height: 22, color: AppColors.border),
                          ],
                        ] else ...<Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  'Multiple Selection (${selectedObjects.length} objects)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (ref
                                  .read(editorControllerProvider)
                                  .canGroupSelection)
                                InkWell(
                                  onTap: () => ref
                                      .read(editorControllerProvider)
                                      .groupSelection(),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusSm,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentSubtle,
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusSm,
                                      ),
                                      border: Border.all(color: AppColors.accent),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Icon(
                                          AppIcons.group,
                                          size: 12,
                                          color: AppColors.accent,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Group',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Changes to Fill, Stroke, or Opacity apply to all selected objects.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Divider(height: 20, color: AppColors.border),
                        ],
                        FillStrokeSection(
                          primaryObject: selectedObjects.last,
                          targetIds: selectedIds,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtboardInspectorView extends ConsumerStatefulWidget {
  const _ArtboardInspectorView();

  @override
  ConsumerState<_ArtboardInspectorView> createState() =>
      _ArtboardInspectorViewState();
}

class _ArtboardInspectorViewState extends ConsumerState<_ArtboardInspectorView> {
  late final TextEditingController _docNameController;
  late final FocusNode _docNameFocus;
  late String _boundDocId;

  @override
  void initState() {
    super.initState();
    final doc = ref.read(currentDocumentProvider);
    _boundDocId = doc.id;
    _docNameController = TextEditingController(text: doc.name);
    _docNameFocus = FocusNode()..addListener(_handleFocus);
  }

  @override
  void dispose() {
    _docNameFocus.removeListener(_handleFocus);
    _docNameFocus.dispose();
    _docNameController.dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (!_docNameFocus.hasFocus) {
      _commitDocName();
    }
  }

  void _commitDocName() {
    final doc = ref.read(currentDocumentProvider);
    if (doc.id != _boundDocId) return;
    final trimmed = _docNameController.text.trim();
    if (trimmed.isEmpty) {
      _docNameController.text = doc.name;
      return;
    }
    if (trimmed == doc.name) return;

    ref.read(documentControllerProvider.notifier).executeEdit(
          label: 'Rename Document',
          mutator: (d) => d.copyWith(name: trimmed),
        );
  }

  @override
  Widget build(BuildContext context) {
    final VectorDocument doc = ref.watch(currentDocumentProvider);
    if (doc.id != _boundDocId) {
      _boundDocId = doc.id;
      _docNameController.text = doc.name;
    } else if (!_docNameFocus.hasFocus && _docNameController.text != doc.name) {
      _docNameController.text = doc.name;
    }

    final docCtrl = ref.read(documentControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'ARTBOARD DOCUMENT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: AppDimensions.inputHeight,
          child: TextField(
            controller: _docNameController,
            focusNode: _docNameFocus,
            style: const TextStyle(fontSize: 12),
            onSubmitted: (_) => _commitDocName(),
            decoration: const InputDecoration(hintText: 'Document Title'),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: NumericInspectorField(
                ownerKey: '${doc.id}_w',
                label: 'W',
                value: doc.width,
                decimals: 0,
                min: EditorConstants.minArtboardSize,
                max: EditorConstants.maxArtboardSize,
                onCommitted: (w) {
                  docCtrl.executeEdit(
                    label: 'Resize Artboard Width',
                    mutator: (d) => d.copyWith(width: w),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumericInspectorField(
                ownerKey: '${doc.id}_h',
                label: 'H',
                value: doc.height,
                decimals: 0,
                min: EditorConstants.minArtboardSize,
                max: EditorConstants.maxArtboardSize,
                onCommitted: (h) {
                  docCtrl.executeEdit(
                    label: 'Resize Artboard Height',
                    mutator: (d) => d.copyWith(height: h),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'BACKGROUND COLOR',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await ColorPickerDialog.show(
              context,
              initialColor: doc.backgroundColor,
              title: 'Artboard Background',
            );
            if (picked != null) {
              docCtrl.executeEdit(
                label: 'Change Artboard Background',
                mutator: (d) => d.copyWith(backgroundColor: picked),
              );
            }
          },
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
                    color: doc.backgroundColor,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppColors.border),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  ColorUtils.toHex(doc.backgroundColor),
                  style: AppTheme.monoStyle(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 24, color: AppColors.border),
        const Text(
          'ASSETS & EXPORT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    WorkflowDialogs.performImportRasterImage(context, ref),
                icon: const Icon(AppIcons.image, size: 13.5),
                label: const Text('Import Image', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => WorkflowDialogs.performImportSvg(context, ref),
                icon: const Icon(AppIcons.openFile, size: 13.5),
                label: const Text('Import SVG', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => WorkflowDialogs.performExportArtwork(context, ref),
            icon: const Icon(AppIcons.exportSvg, size: 14),
            label: const Text(
              'Export Artwork (SVG / PNG / JPEG)...',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.mainBackground,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
