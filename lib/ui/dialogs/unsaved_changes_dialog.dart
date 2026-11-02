import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_icons.dart';

/// User decision when attempting to close or replace a modified document.
enum UnsavedChangesDecision {
  save,
  discard,
  cancel,
}

/// Modal confirmation dialog warning before discarding unsaved `.vectra` changes.
class UnsavedChangesDialog extends StatelessWidget {
  final String documentName;

  const UnsavedChangesDialog({
    super.key,
    required this.documentName,
  });

  static Future<UnsavedChangesDecision> show(
    BuildContext context, {
    required String documentName,
  }) async {
    final result = await showDialog<UnsavedChangesDecision>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UnsavedChangesDialog(documentName: documentName),
    );
    return result ?? UnsavedChangesDecision.cancel;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      title: Row(
        children: <Widget>[
          const Icon(
            AppIcons.warning,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Unsaved Changes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Text(
          'Save changes to "$documentName" before continuing? Your edits will be lost if you discard them.',
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(UnsavedChangesDecision.cancel),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
          ),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.of(context).pop(UnsavedChangesDecision.discard),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
          ),
          child: const Text("Don't Save"),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(UnsavedChangesDecision.save),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.mainBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
          ),
          child: const Text('Save Project'),
        ),
      ],
    );
  }
}
