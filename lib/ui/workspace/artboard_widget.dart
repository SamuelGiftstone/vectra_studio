import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/editor_providers.dart';
import '../../rendering/document_painter.dart';
import '../../rendering/selection_painter.dart';
import '../../rendering/viewport_transform.dart';

/// Stacked rendering surface separating document vector artwork ([DocumentPainter])
/// from transient editing/selection overlays ([SelectionPainter]).
class ArtboardWidget extends ConsumerWidget {
  const ArtboardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(currentDocumentProvider);
    final viewportState = ref.watch(viewportControllerProvider);
    final selectionState = ref.watch(selectionControllerProvider);
    final activeTool = ref.watch(activeToolProvider);
    final transientState = ref.watch(transientToolStateProvider);
    final activeTextSession = ref.watch(activeTextSessionProvider);

    final viewportTransform = ViewportTransform.fromState(viewportState);
    final editingTextId = activeTextSession?.objectId;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RepaintBoundary(
            child: CustomPaint(
              painter: DocumentPainter(
                document: document,
                viewport: viewportTransform,
                showGrid: viewportState.showGrid,
                gridSize: viewportState.gridSize,
                draftObject: transientState.draftObject,
                activeEditingTextId: editingTextId,
              ),
            ),
          ),
          RepaintBoundary(
            child: IgnorePointer(
              child: CustomPaint(
                painter: SelectionPainter(
                  document: document,
                  selection: selectionState,
                  activeTool: activeTool,
                  transient: transientState,
                  viewport: viewportTransform,
                  activeEditingTextId: editingTextId,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
