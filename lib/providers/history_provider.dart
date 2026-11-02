import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'document_provider.dart';

/// Value object summarizing undo/redo availability and labels.
class HistoryAvailability {
  final bool canUndo;
  final bool canRedo;
  final String? undoLabel;
  final String? redoLabel;

  const HistoryAvailability({
    required this.canUndo,
    required this.canRedo,
    this.undoLabel,
    this.redoLabel,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryAvailability &&
          other.canUndo == canUndo &&
          other.canRedo == canRedo &&
          other.undoLabel == undoLabel &&
          other.redoLabel == redoLabel);

  @override
  int get hashCode => Object.hash(canUndo, canRedo, undoLabel, redoLabel);
}

/// Exposes undo/redo availability derived directly from [documentControllerProvider].
final historyAvailabilityProvider = Provider<HistoryAvailability>((ref) {
  final canUndo = ref.watch(documentControllerProvider.select((s) => s.canUndo));
  final canRedo = ref.watch(documentControllerProvider.select((s) => s.canRedo));
  final undoLabel =
      ref.watch(documentControllerProvider.select((s) => s.lastUndoLabel));
  final redoLabel =
      ref.watch(documentControllerProvider.select((s) => s.lastRedoLabel));

  return HistoryAvailability(
    canUndo: canUndo,
    canRedo: canRedo,
    undoLabel: undoLabel,
    redoLabel: redoLabel,
  );
});
