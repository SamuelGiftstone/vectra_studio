import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/text_editing_session.dart';
import '../editor/tool_controller.dart';

/// Manages active [EditorToolType], tool parameters, inline text session, and transient drawing state.
final toolControllerProvider =
    StateNotifierProvider<ToolController, ToolState>((ref) {
  return ToolController();
});

/// Exposes only the currently active [EditorToolType].
final activeToolProvider = Provider<EditorToolType>((ref) {
  return ref.watch(toolControllerProvider.select((s) => s.activeTool));
});

/// Exposes transient drawing/marquee/pen construction state for canvas overlays.
final transientToolStateProvider = Provider<TransientToolState>((ref) {
  return ref.watch(toolControllerProvider.select((s) => s.transient));
});

/// Exposes the currently active inline canvas text editing session, if any.
final activeTextSessionProvider = Provider<InlineTextEditingSession?>((ref) {
  return ref.watch(toolControllerProvider.select((s) => s.activeTextSession));
});
