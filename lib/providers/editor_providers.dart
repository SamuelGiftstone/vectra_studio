import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/editor_controller.dart';
import '../storage/project_storage.dart';
import 'document_provider.dart';
import 'selection_provider.dart';
import 'tool_provider.dart';
import 'viewport_provider.dart';

export 'document_provider.dart';
export 'history_provider.dart';
export 'layers_provider.dart';
export 'selection_provider.dart';
export 'tool_provider.dart';
export 'viewport_provider.dart';

/// Dedicated local project storage service provider.
final projectStorageProvider = Provider<ProjectStorage>((ref) {
  return const ProjectStorage();
});

/// High-level [EditorController] coordinating document, selection, tool, viewport, and storage operations.
final editorControllerProvider = Provider<EditorController>((ref) {
  final docCtrl = ref.watch(documentControllerProvider.notifier);
  final selCtrl = ref.watch(selectionControllerProvider.notifier);
  final toolCtrl = ref.watch(toolControllerProvider.notifier);
  final viewCtrl = ref.watch(viewportControllerProvider.notifier);
  final storage = ref.watch(projectStorageProvider);

  return EditorController(
    documentController: docCtrl,
    selectionController: selCtrl,
    toolController: toolCtrl,
    viewportController: viewCtrl,
    projectStorage: storage,
  );
});
