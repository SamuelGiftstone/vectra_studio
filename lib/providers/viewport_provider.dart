import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/viewport_controller.dart';
import '../math/vec2.dart';

/// Manages viewport zoom, pan offset, grid visibility, tag display mode, and cursor document coordinates.
final viewportControllerProvider =
    StateNotifierProvider<ViewportController, ViewportState>((ref) {
  return ViewportController();
});

/// Exposes integer zoom percentage (e.g., `100` for `100%`).
final zoomPercentageProvider = Provider<int>((ref) {
  return ref.watch(viewportControllerProvider.select((s) => s.zoomPercentage));
});

/// Exposes whether the artboard pixel/unit grid is visible.
final showGridProvider = Provider<bool>((ref) {
  return ref.watch(viewportControllerProvider.select((s) => s.showGrid));
});

/// Exposes the current [TagDisplayMode] for floating object labels on the canvas.
final tagDisplayModeProvider = Provider<TagDisplayMode>((ref) {
  return ref.watch(
    viewportControllerProvider.select((s) => s.tagDisplayMode),
  );
});

/// Exposes the live document-space cursor coordinates for the status bar.
final cursorDocPositionProvider = Provider<Vec2?>((ref) {
  return ref.watch(
    viewportControllerProvider.select((s) => s.cursorDocPosition),
  );
});
