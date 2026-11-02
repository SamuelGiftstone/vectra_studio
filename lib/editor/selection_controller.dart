import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vector_document.dart';

/// Immutable selection and hover state shared across canvas, inspector, and layers panel.
class SelectionState {
  final Set<String> selectedIds;
  final int? selectedAnchorIndex;
  final String? hoveredObjectId;

  SelectionState({
    Set<String> selectedIds = const <String>{},
    this.selectedAnchorIndex,
    this.hoveredObjectId,
  }) : selectedIds = Set<String>.unmodifiable(selectedIds);

  bool get hasSelection => selectedIds.isNotEmpty;
  bool get isSingleSelection => selectedIds.length == 1;
  String? get primarySelectedId =>
      selectedIds.isNotEmpty ? selectedIds.first : null;

  bool isSelected(String objectId) => selectedIds.contains(objectId);

  SelectionState copyWith({
    Set<String>? selectedIds,
    int? selectedAnchorIndex,
    bool clearAnchorIndex = false,
    String? hoveredObjectId,
    bool clearHoveredObject = false,
  }) {
    return SelectionState(
      selectedIds: selectedIds ?? this.selectedIds,
      selectedAnchorIndex: clearAnchorIndex
          ? null
          : (selectedAnchorIndex ?? this.selectedAnchorIndex),
      hoveredObjectId:
          clearHoveredObject ? null : (hoveredObjectId ?? this.hoveredObjectId),
    );
  }
}

/// Manages selected vector object IDs, active path anchor index, and hover highlights.
class SelectionController extends StateNotifier<SelectionState> {
  SelectionController() : super(SelectionState());

  void selectSingle(String objectId, {int? anchorIndex}) {
    state = SelectionState(
      selectedIds: <String>{objectId},
      selectedAnchorIndex: anchorIndex,
      hoveredObjectId: state.hoveredObjectId,
    );
  }

  void toggleObject(String objectId) {
    final next = Set<String>.of(state.selectedIds);
    if (next.contains(objectId)) {
      next.remove(objectId);
    } else {
      next.add(objectId);
    }
    state = state.copyWith(
      selectedIds: next,
      clearAnchorIndex: true,
    );
  }

  void setSelectedIds(Set<String> ids, {int? anchorIndex}) {
    state = SelectionState(
      selectedIds: ids,
      selectedAnchorIndex: anchorIndex,
      hoveredObjectId: state.hoveredObjectId,
    );
  }

  void selectAnchor(int? anchorIndex) {
    if (anchorIndex == null) {
      state = state.copyWith(clearAnchorIndex: true);
    } else {
      state = state.copyWith(selectedAnchorIndex: anchorIndex);
    }
  }

  void clearSelection() {
    if (!state.hasSelection && state.selectedAnchorIndex == null) return;
    state = state.copyWith(
      selectedIds: const <String>{},
      clearAnchorIndex: true,
    );
  }

  void setHoveredObject(String? objectId) {
    if (state.hoveredObjectId == objectId) return;
    if (objectId == null) {
      state = state.copyWith(clearHoveredObject: true);
    } else {
      state = state.copyWith(hoveredObjectId: objectId);
    }
  }

  /// Removes any selected IDs that no longer exist or became hidden/locked.
  void reconcileWithDocument(VectorDocument document) {
    if (state.selectedIds.isEmpty) return;
    final validIds = state.selectedIds.where((id) {
      final obj = document.findObjectById(id);
      if (obj == null) return false;
      return document.isObjectEffectivelyVisible(id) &&
          !document.isObjectEffectivelyLocked(id);
    }).toSet();

    if (validIds.length != state.selectedIds.length) {
      state = state.copyWith(
        selectedIds: validIds,
        clearAnchorIndex: validIds.length != 1,
      );
    }
  }
}
