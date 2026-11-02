import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/selection_controller.dart';
import '../models/vector_object.dart';
import 'document_provider.dart';

/// Manages selected object IDs, active path anchor index, and hover highlights.
final selectionControllerProvider =
    StateNotifierProvider<SelectionController, SelectionState>((ref) {
  return SelectionController();
});

/// Selected IDs set.
final selectedIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(selectionControllerProvider.select((s) => s.selectedIds));
});

/// Selected anchor index when editing a [PathObject] in the Node Tool.
final selectedAnchorIndexProvider = Provider<int?>((ref) {
  return ref.watch(
    selectionControllerProvider.select((s) => s.selectedAnchorIndex),
  );
});

/// Resolves the actual [VectorObject] models from [currentDocumentProvider]
/// matching [selectedIdsProvider] (single source of truth).
final selectedObjectsProvider = Provider<List<VectorObject>>((ref) {
  final doc = ref.watch(currentDocumentProvider);
  final ids = ref.watch(selectedIdsProvider);
  if (ids.isEmpty) return const <VectorObject>[];

  final result = <VectorObject>[];
  for (final obj in doc.allObjectsRecursive) {
    if (ids.contains(obj.id)) {
      result.add(obj);
    }
  }
  return result;
});


/// Exposes the primary selected [VectorObject] when one or more objects are selected.
final primarySelectedObjectProvider = Provider<VectorObject?>((ref) {
  final objects = ref.watch(selectedObjectsProvider);
  if (objects.isEmpty) return null;
  return objects.last;
});
