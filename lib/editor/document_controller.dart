import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_object.dart';
import '../models/vector_document.dart';
import 'history_manager.dart';


/// Immutable state exposed by [DocumentController].
class DocumentState {
  final VectorDocument document;
  final String? filePath;
  final bool isDirty;
  final bool canUndo;
  final bool canRedo;
  final String? lastUndoLabel;
  final String? lastRedoLabel;
  final String statusMessage;

  const DocumentState({
    required this.document,
    this.filePath,
    this.isDirty = false,
    this.canUndo = false,
    this.canRedo = false,
    this.lastUndoLabel,
    this.lastRedoLabel,
    this.statusMessage = 'Ready',
  });

  DocumentState copyWith({
    VectorDocument? document,
    String? filePath,
    bool clearFilePath = false,
    bool? isDirty,
    bool? canUndo,
    bool? canRedo,
    String? lastUndoLabel,
    bool clearUndoLabel = false,
    String? lastRedoLabel,
    bool clearRedoLabel = false,
    String? statusMessage,
  }) {
    return DocumentState(
      document: document ?? this.document,
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      isDirty: isDirty ?? this.isDirty,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      lastUndoLabel:
          clearUndoLabel ? null : (lastUndoLabel ?? this.lastUndoLabel),
      lastRedoLabel:
          clearRedoLabel ? null : (lastRedoLabel ?? this.lastRedoLabel),
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

/// Owns the active [VectorDocument], project dirty state, file path,
/// and grouped undo/redo history transactions.
class DocumentController extends StateNotifier<DocumentState> {
  final HistoryManager _history;

  VectorDocument? _transactionSnapshot;
  Set<String> _transactionBeforeSelection = const <String>{};

  DocumentController({
    VectorDocument? initialDocument,
    HistoryManager? historyManager,
  })  : _history = historyManager ?? HistoryManager(),
        super(
          DocumentState(
            document: initialDocument ?? VectorDocument.createNew(),
          ),
        );

  bool get hasActiveTransaction => _transactionSnapshot != null;

  /// Executes an atomic edit, recording a single undo entry and marking the document modified.
  void executeEdit({
    required String label,
    required VectorDocument Function(VectorDocument current) mutator,
    Set<String> beforeSelection = const <String>{},
    Set<String>? afterSelection,
  }) {
    final before = state.document;
    final after = mutator(before);
    if (identical(before, after)) return;

    _history.record(
      HistoryEntry(
        label: label,
        beforeDocument: before,
        afterDocument: after,
        beforeSelection: beforeSelection,
        afterSelection: afterSelection ?? beforeSelection,
      ),
    );

    _syncState(
      document: after,
      isDirty: true,
      statusMessage: label,
    );
  }

  /// Begins a continuous drag/slider interaction without polluting undo history on every frame.
  void beginInteractiveTransaction({
    Set<String> currentSelection = const <String>{},
  }) {
    _transactionSnapshot ??= state.document;
    _transactionBeforeSelection = Set<String>.unmodifiable(currentSelection);
  }

  /// Applies a high-frequency transient update to the live document during an active gesture.
  void updateInteractiveDocument(VectorDocument updated) {
    _transactionSnapshot ??= state.document;
    state = state.copyWith(document: updated);
  }

  /// Finalizes an interactive gesture as a single undoable history operation.
  void commitInteractiveTransaction({
    required String label,
    Set<String>? afterSelection,
  }) {
    final before = _transactionSnapshot;
    _transactionSnapshot = null;

    if (before == null || identical(before, state.document)) {
      return;
    }

    _history.record(
      HistoryEntry(
        label: label,
        beforeDocument: before,
        afterDocument: state.document,
        beforeSelection: _transactionBeforeSelection,
        afterSelection: afterSelection ?? _transactionBeforeSelection,
      ),
    );

    _syncState(
      document: state.document,
      isDirty: true,
      statusMessage: label,
    );
  }

  /// Cancels an in-progress interactive gesture and restores the pre-drag document.
  void cancelInteractiveTransaction() {
    final before = _transactionSnapshot;
    _transactionSnapshot = null;
    if (before != null) {
      _syncState(
        document: before,
        statusMessage: 'Canceled operation',
      );
    }
  }

  /// Undoes the most recent edit and returns the restored selection set, if any.
  Set<String>? undo() {
    cancelInteractiveTransaction();
    final entry = _history.undo();
    if (entry == null) return null;

    _syncState(
      document: entry.beforeDocument,
      isDirty: true,
      statusMessage: 'Undo: ${entry.label}',
    );
    return entry.beforeSelection;
  }

  /// Redoes the most recently undone edit and returns the restored selection set, if any.
  Set<String>? redo() {
    cancelInteractiveTransaction();
    final entry = _history.redo();
    if (entry == null) return null;

    _syncState(
      document: entry.afterDocument,
      isDirty: true,
      statusMessage: 'Redo: ${entry.label}',
    );
    return entry.afterSelection;
  }

  /// Replaces the workspace with a brand-new or freshly opened [VectorDocument].
  void replaceDocument(
    VectorDocument newDocument, {
    String? filePath,
    String? statusMessage,
  }) {
    _transactionSnapshot = null;
    _history.clear();
    state = DocumentState(
      document: newDocument,
      filePath: filePath,
      isDirty: false,
      canUndo: false,
      canRedo: false,
      statusMessage: statusMessage ?? 'Loaded "${newDocument.name}"',
    );
  }

  /// Updates the active layer selection without creating a document mutation history step.
  void setActiveLayer(String layerId) {
    if (state.document.activeLayerId == layerId) return;
    if (state.document.findLayerById(layerId) == null) return;
    state = state.copyWith(
      document: state.document.copyWith(activeLayerId: layerId),
    );
  }

  /// Toggles UI expansion of a layer in the Layers panel without polluting undo history.
  void toggleLayerExpanded(String layerId) {
    final nextDoc = state.document.updateLayer(
      layerId,
      (l) => l.copyWith(expanded: !l.expanded),
    );
    state = state.copyWith(document: nextDoc);
  }

  /// Toggles UI expansion of a [GroupObject] in the Layers panel without polluting undo history.
  void toggleGroupExpanded(String groupId) {
    final nextDoc = state.document.updateObject(
      groupId,
      (obj) => obj is GroupObject ? obj.copyWith(expanded: !obj.expanded) : obj,
    );
    state = state.copyWith(document: nextDoc);
  }


  /// Marks the current document as saved to [savedFilePath].
  void markSaved(String savedFilePath) {
    state = state.copyWith(
      filePath: savedFilePath,
      isDirty: false,
      statusMessage: 'Saved project to $savedFilePath',
    );
  }

  void setStatusMessage(String message) {
    state = state.copyWith(statusMessage: message);
  }

  void _syncState({
    required VectorDocument document,
    bool? isDirty,
    String? statusMessage,
  }) {
    state = state.copyWith(
      document: document,
      isDirty: isDirty ?? state.isDirty,
      canUndo: _history.canUndo,
      canRedo: _history.canRedo,
      lastUndoLabel: _history.lastUndoLabel,
      clearUndoLabel: _history.lastUndoLabel == null,
      lastRedoLabel: _history.lastRedoLabel,
      clearRedoLabel: _history.lastRedoLabel == null,
      statusMessage: statusMessage ?? state.statusMessage,
    );
  }
}
