import '../models/vector_document.dart';

/// Represents an active inline canvas text creation or editing session.
///
/// Holds pre-session snapshot metadata so that committing produces a single
/// atomic undo history entry, while pressing `Escape` cleanly cancels uncommitted
/// creation or reverts draft text changes.
class InlineTextEditingSession {
  final String objectId;
  final bool isNewlyCreated;
  final VectorDocument preSessionDocument;
  final Set<String> preSessionSelection;
  final String initialText;

  InlineTextEditingSession({
    required this.objectId,
    required this.isNewlyCreated,
    required this.preSessionDocument,
    required Set<String> preSessionSelection,
    required this.initialText,
  }) : preSessionSelection = Set<String>.unmodifiable(preSessionSelection);
}
