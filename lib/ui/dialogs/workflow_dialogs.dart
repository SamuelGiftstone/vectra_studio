import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/editor_providers.dart';
import '../../storage/document_export_service.dart';
import 'export_artwork_dialog.dart';
import 'new_document_dialog.dart';
import 'svg_preview_dialog.dart';
import 'unsaved_changes_dialog.dart';

/// Shared UI workflow helpers for New, Open, Save, Save As, Image/SVG Import,
/// Multi-Format Artwork Export (SVG, PNG, JPEG), and safe Window Close.
class WorkflowDialogs {
  WorkflowDialogs._();

  /// Checks whether the current document has unsaved modifications and prompts the user if so.
  /// Returns `true` when it is safe to proceed with replacing or closing the document.
  static Future<bool> confirmDiscardOrSaveIfNeeded(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final isDirty = ref.read(isDocumentDirtyProvider);
    if (!isDirty) return true;

    final doc = ref.read(currentDocumentProvider);
    final decision = await UnsavedChangesDialog.show(
      context,
      documentName: doc.name,
    );

    switch (decision) {
      case UnsavedChangesDecision.cancel:
        return false;
      case UnsavedChangesDecision.discard:
        return true;
      case UnsavedChangesDecision.save:
        if (!context.mounted) return false;
        return performSave(context, ref);
    }
  }

  static Future<void> performNewDocument(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final canProceed = await confirmDiscardOrSaveIfNeeded(context, ref);
    if (!canProceed || !context.mounted) return;

    final config = await NewDocumentDialog.show(context);
    if (config == null) return;

    ref.read(editorControllerProvider).startNewDocument(
          name: config.name,
          width: config.width,
          height: config.height,
          backgroundColor: config.backgroundColor,
        );
  }

  static Future<void> performOpenProject(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final canProceed = await confirmDiscardOrSaveIfNeeded(context, ref);
    if (!canProceed || !context.mounted) return;

    try {
      await ref.read(editorControllerProvider).openProject();
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Unable to Open Project', e.toString());
      }
    }
  }

  static Future<bool> performSave(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      return await ref.read(editorControllerProvider).saveProject();
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Save Failed', e.toString());
      }
      return false;
    }
  }

  static Future<bool> performSaveAs(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      return await ref.read(editorControllerProvider).saveProjectAs();
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Save As Failed', e.toString());
      }
      return false;
    }
  }

  static Future<void> performImportRasterImage(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await ref.read(editorControllerProvider).importRasterImage();
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Image Import Failed', e.toString());
      }
    }
  }

  static Future<void> performImportSvg(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await ref.read(editorControllerProvider).importSvgFile();
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'SVG Import Failed', e.toString());
      }
    }
  }

  static Future<void> performExportArtwork(
    BuildContext context,
    WidgetRef ref, {
    ExportFormat initialFormat = ExportFormat.png,
  }) async {
    final doc = ref.read(currentDocumentProvider);
    final config = await ExportArtworkDialog.show(
      context,
      document: doc,
      initialFormat: initialFormat,
      onInspectSvgMarkup: () =>
          performExportSvg(context, ref, showPreviewFirst: true),
    );
    if (config == null || !context.mounted) return;

    try {
      final result =
          await ref.read(editorControllerProvider).exportArtwork(config);
      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.secondarySurface,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            content: Text(
              'Exported ${result.format.name.toUpperCase()} (${result.pixelWidth}×${result.pixelHeight}) → ${result.filePath}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Artwork Export Failed', e.toString());
      }
    }
  }

  static Future<void> performExportSvg(
    BuildContext context,
    WidgetRef ref, {
    bool showPreviewFirst = false,
  }) async {
    final editor = ref.read(editorControllerProvider);
    final doc = ref.read(currentDocumentProvider);

    if (showPreviewFirst) {
      final markup = editor.projectStorage.generateSvgPreview(doc);
      await SvgPreviewDialog.show(
        context,
        svgMarkup: markup,
        documentName: doc.name,
        onSaveToFile: () => _exportDirectSvg(context, ref),
      );
      return;
    }

    await _exportDirectSvg(context, ref);
  }

  static Future<void> _exportDirectSvg(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await ref.read(editorControllerProvider).exportSvg();
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'SVG Export Failed', e.toString());
      }
    }
  }

  static void _showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
        content: SizedBox(
          width: 360,
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.mainBackground,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
