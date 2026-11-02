import '../core/constants/editor_constants.dart';
import '../models/vector_document.dart';

/// Immutable record of a single undoable editing operation.
class HistoryEntry {
  final String label;
  final VectorDocument beforeDocument;
  final VectorDocument afterDocument;
  final Set<String> beforeSelection;
  final Set<String> afterSelection;

  HistoryEntry({
    required this.label,
    required this.beforeDocument,
    required this.afterDocument,
    Set<String> beforeSelection = const <String>{},
    Set<String> afterSelection = const <String>{},
  })  : beforeSelection = Set<String>.unmodifiable(beforeSelection),
        afterSelection = Set<String>.unmodifiable(afterSelection);
}

/// Manages bounded undo and redo stacks using immutable [VectorDocument] snapshots.
class HistoryManager {
  final int maxEntries;
  final List<HistoryEntry> _undoStack = <HistoryEntry>[];
  final List<HistoryEntry> _redoStack = <HistoryEntry>[];

  HistoryManager({this.maxEntries = EditorConstants.maxHistoryEntries});

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;

  String? get lastUndoLabel =>
      _undoStack.isNotEmpty ? _undoStack.last.label : null;

  String? get lastRedoLabel =>
      _redoStack.isNotEmpty ? _redoStack.last.label : null;

  /// Records a completed editing transition and clears the redo stack.
  void record(HistoryEntry entry) {
    if (identical(entry.beforeDocument, entry.afterDocument)) {
      return;
    }
    _undoStack.add(entry);
    if (_undoStack.length > maxEntries) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  /// Pops the most recent [HistoryEntry] and pushes it onto the redo stack.
  HistoryEntry? undo() {
    if (_undoStack.isEmpty) return null;
    final entry = _undoStack.removeLast();
    _redoStack.add(entry);
    return entry;
  }

  /// Pops the most recent undone [HistoryEntry] and returns it to the undo stack.
  HistoryEntry? redo() {
    if (_redoStack.isEmpty) return null;
    final entry = _redoStack.removeLast();
    _undoStack.add(entry);
    return entry;
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
