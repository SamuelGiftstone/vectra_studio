import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/document_controller.dart';
import '../models/vector_document.dart';

/// Primary Riverpod state notifier provider owning the editable [VectorDocument].
final documentControllerProvider =
    StateNotifierProvider<DocumentController, DocumentState>((ref) {
  return DocumentController();
});

/// Exposes the current [VectorDocument] and notifies listeners only when the document changes.
final currentDocumentProvider = Provider<VectorDocument>((ref) {
  return ref.watch(documentControllerProvider.select((s) => s.document));
});

/// Exposes whether the current document has unsaved edits.
final isDocumentDirtyProvider = Provider<bool>((ref) {
  return ref.watch(documentControllerProvider.select((s) => s.isDirty));
});

/// Exposes the currently bound `.vectra` file path on disk, if saved/opened.
final currentFilePathProvider = Provider<String?>((ref) {
  return ref.watch(documentControllerProvider.select((s) => s.filePath));
});

/// Exposes the latest workspace status message.
final statusMessageProvider = Provider<String>((ref) {
  return ref.watch(documentControllerProvider.select((s) => s.statusMessage));
});
