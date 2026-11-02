import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vectora_studio_software/editor/document_controller.dart';
import 'package:vectora_studio_software/editor/editor_commands.dart';
import 'package:vectora_studio_software/editor/editor_controller.dart';
import 'package:vectora_studio_software/editor/selection_controller.dart';
import 'package:vectora_studio_software/editor/tool_controller.dart';
import 'package:vectora_studio_software/editor/viewport_controller.dart';
import 'package:vectora_studio_software/math/vec2.dart';
import 'package:vectora_studio_software/models/fill_style.dart';
import 'package:vectora_studio_software/models/rectangle_object.dart';
import 'package:vectora_studio_software/models/stroke_style.dart';
import 'package:vectora_studio_software/storage/project_storage.dart';

void main() {
  EditorController createTestEditor() {
    return EditorController(
      documentController: DocumentController(),
      selectionController: SelectionController(),
      toolController: ToolController(),
      viewportController: ViewportController(),
      projectStorage: const ProjectStorage(),
    );
  }

  group('HistoryManager & DocumentController undo/redo workflows', () {
    test('undoes and redoes object creation, fill edits, and deletion', () {
      final editor = createTestEditor();
      final docCtrl = editor.documentController;
      final selCtrl = editor.selectionController;

      expect(docCtrl.state.isDirty, isFalse);
      expect(docCtrl.state.canUndo, isFalse);

      // 1. Add rectangle
      const rect = RectangleObject(
        id: 'rect_a',
        name: 'Rectangle 1',
        layerId: '',
        x: 100,
        y: 120,
        width: 200,
        height: 150,
        fill: FillStyle(color: Color(0xFFA78BFA)),
        stroke: StrokeStyle.defaultStroke,
      );
      docCtrl.executeEdit(
        label: 'Create Rectangle',
        mutator: (doc) => doc.addObject(rect),
        beforeSelection: const <String>{},
        afterSelection: const <String>{'rect_a'},
      );
      selCtrl.selectSingle('rect_a');

      expect(editor.currentDocument.objectCount, 1);
      expect(docCtrl.state.isDirty, isTrue);
      expect(docCtrl.state.canUndo, isTrue);

      // 2. Change Fill color
      docCtrl.executeEdit(
        label: 'Change Fill Color',
        mutator: (doc) => EditorCommands.updateFill(
          doc,
          const <String>{'rect_a'},
          (f) => f.copyWith(color: const Color(0xFF10B981)),
        ),
        beforeSelection: const <String>{'rect_a'},
      );

      expect(
        editor.currentDocument.findObjectById('rect_a')!.fill.color,
        const Color(0xFF10B981),
      );

      // 3. Undo fill edit -> restores original #A78BFA fill
      editor.undo();
      expect(
        editor.currentDocument.findObjectById('rect_a')!.fill.color,
        const Color(0xFFA78BFA),
      );
      expect(docCtrl.state.canRedo, isTrue);

      // 4. Undo creation -> restores empty document & clears selection
      editor.undo();
      expect(editor.currentDocument.objectCount, 0);
      expect(editor.selectedIds, isEmpty);
      expect(docCtrl.state.canUndo, isFalse);

      // 5. Redo creation -> restores rectangle & selection
      editor.redo();
      expect(editor.currentDocument.objectCount, 1);
      expect(editor.selectedIds, contains('rect_a'));

      // 6. Redo fill edit -> restores #10B981 fill
      editor.redo();
      expect(
        editor.currentDocument.findObjectById('rect_a')!.fill.color,
        const Color(0xFF10B981),
      );
    });

    test('groups multi-frame interactive drag into a single undo operation', () {
      final editor = createTestEditor();
      final docCtrl = editor.documentController;

      const rect = RectangleObject(
        id: 'drag_rect',
        name: 'Box',
        layerId: '',
        x: 50,
        y: 50,
        width: 100,
        height: 100,
        fill: FillStyle.defaultFill,
        stroke: StrokeStyle.defaultStroke,
      );
      docCtrl.executeEdit(
        label: 'Create Box',
        mutator: (doc) => doc.addObject(rect),
        afterSelection: const <String>{'drag_rect'},
      );
      editor.selectionController.selectSingle('drag_rect');

      final baseBeforeDrag = editor.currentDocument;
      docCtrl.beginInteractiveTransaction(
        currentSelection: const <String>{'drag_rect'},
      );

      // Simulate 12 pointer-move frames during a single drag
      for (var step = 1; step <= 12; step++) {
        final moved = EditorCommands.translateObjects(
          baseBeforeDrag,
          const <String>{'drag_rect'},
          Vec2(step * 10.0, step * 5.0),
        );
        docCtrl.updateInteractiveDocument(moved);
      }

      docCtrl.commitInteractiveTransaction(label: 'Move Object');

      final afterDrag =
          editor.currentDocument.findObjectById('drag_rect') as RectangleObject;
      expect(afterDrag.x, closeTo(170.0, 1e-6));
      expect(afterDrag.y, closeTo(110.0, 1e-6));

      // Single Undo must revert all 12 frames back to (50, 50)
      editor.undo();
      final reverted =
          editor.currentDocument.findObjectById('drag_rect') as RectangleObject;
      expect(reverted.x, closeTo(50.0, 1e-6));
      expect(reverted.y, closeTo(50.0, 1e-6));
    });

    test('canceling an interactive drag restores pre-drag state without adding history', () {
      final editor = createTestEditor();
      final docCtrl = editor.documentController;

      const rect = RectangleObject(
        id: 'cancel_rect',
        name: 'Box',
        layerId: '',
        x: 20,
        y: 30,
        width: 80,
        height: 80,
        fill: FillStyle.defaultFill,
        stroke: StrokeStyle.defaultStroke,
      );
      docCtrl.executeEdit(
        label: 'Create Box',
        mutator: (doc) => doc.addObject(rect),
      );

      final snapshot = editor.currentDocument;
      docCtrl.beginInteractiveTransaction();
      docCtrl.updateInteractiveDocument(
        EditorCommands.translateObjects(
          snapshot,
          const <String>{'cancel_rect'},
          const Vec2(200, 200),
        ),
      );

      // User presses Escape mid-drag
      docCtrl.cancelInteractiveTransaction();

      final restored =
          editor.currentDocument.findObjectById('cancel_rect') as RectangleObject;
      expect(restored.x, 20);
      expect(restored.y, 30);
      expect(docCtrl.state.lastUndoLabel, 'Create Box');
    });
  });
}
