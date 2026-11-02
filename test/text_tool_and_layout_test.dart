import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vectora_studio_software/editor/document_controller.dart';
import 'package:vectora_studio_software/editor/editor_commands.dart';
import 'package:vectora_studio_software/editor/editor_controller.dart';
import 'package:vectora_studio_software/editor/selection_controller.dart';
import 'package:vectora_studio_software/editor/tool_controller.dart';
import 'package:vectora_studio_software/editor/viewport_controller.dart';
import 'package:vectora_studio_software/math/bounds2d.dart';
import 'package:vectora_studio_software/models/fill_style.dart';
import 'package:vectora_studio_software/models/text_object.dart';
import 'package:vectora_studio_software/models/vector_document.dart';
import 'package:vectora_studio_software/rendering/font_catalog.dart';
import 'package:vectora_studio_software/storage/document_deserializer.dart';
import 'package:vectora_studio_software/storage/document_serializer.dart';
import 'package:vectora_studio_software/storage/project_storage.dart';
import 'package:vectora_studio_software/storage/svg_exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FontCatalog.ensureOfflineSafeConfiguration();

  EditorController createTestEditor() {
    return EditorController(
      documentController: DocumentController(),
      selectionController: SelectionController(),
      toolController: ToolController(),
      viewportController: ViewportController(),
      projectStorage: const ProjectStorage(),
    );
  }

  group('Text Tool & Inline Editing Lifecycle', () {
    test('creates Point Text, updates live draft, and commits as a single undo entry', () {
      final editor = createTestEditor();

      editor.createAndBeginInlineText(x: 120, y: 80);
      expect(editor.activeTextSession, isNotNull);
      expect(editor.activeTextSession!.isNewlyCreated, isTrue);

      // Type multiple updates without polluting undo stack
      editor.updateInlineTextDraft('H');
      editor.updateInlineTextDraft('Hello');
      editor.updateInlineTextDraft('Hello\nVECTRA Studio');

      editor.commitInlineTextEditing();
      expect(editor.activeTextSession, isNull);
      expect(editor.currentDocument.objectCount, 1);

      final created =
          editor.currentDocument.allObjectsRecursive.single as TextObject;
      expect(created.name, 'Text 01');
      expect(created.text, 'Hello\nVECTRA Studio');
      expect(created.isAreaText, isFalse);
      expect(created.localBounds.width, greaterThan(20));
      expect(created.localBounds.height, greaterThan(20));

      // Single undo removes the entire created TextObject cleanly
      editor.undo();
      expect(editor.currentDocument.objectCount, 0);

      // Redo restores the committed TextObject
      editor.redo();
      expect(editor.currentDocument.objectCount, 1);
      expect(
        (editor.currentDocument.allObjectsRecursive.single as TextObject).text,
        'Hello\nVECTRA Studio',
      );
    });

    test('discards empty newly created inline text cleanly without ghost objects', () {
      final editor = createTestEditor();

      editor.createAndBeginInlineText(x: 200, y: 150);
      editor.updateInlineTextDraft('   ');
      editor.commitInlineTextEditing();

      expect(editor.activeTextSession, isNull);
      expect(editor.currentDocument.objectCount, 0);
      expect(editor.documentController.state.canUndo, isFalse);
    });

    test('canceling inline edit on existing TextObject restores original text', () {
      final editor = createTestEditor();

      editor.createAndBeginInlineText(x: 60, y: 60);
      editor.updateInlineTextDraft('Original Headline');
      editor.commitInlineTextEditing();

      final textId = editor.currentDocument.allObjectsRecursive.single.id;

      editor.beginInlineTextEditing(textId);
      editor.updateInlineTextDraft('Temporary Uncommitted Draft');
      expect(
        (editor.currentDocument.findObjectById(textId) as TextObject).text,
        'Temporary Uncommitted Draft',
      );

      // Escape cancels and reverts to 'Original Headline'
      editor.cancelInlineTextEditing();
      expect(editor.activeTextSession, isNull);
      expect(
        (editor.currentDocument.findObjectById(textId) as TextObject).text,
        'Original Headline',
      );
    });
  });

  group('TextObject Point vs Area Frame resizing, persistence, and SVG export', () {
    test('Point Text resize scales fontSize while Area Frame Text resize re-wraps box', () {
      const pointText = TextObject(
        id: 'pt_1',
        name: 'Text 01',
        layerId: 'l1',
        text: 'Scalable Display Title',
        x: 50,
        y: 50,
        fontSize: 24,
      );

      final initialPtBounds = pointText.localBounds;
      final doubledPt = pointText.resizeLocalBounds(
        Bounds2D.fromLTWH(
          50,
          50,
          initialPtBounds.width * 2.0,
          initialPtBounds.height * 2.0,
        ),
      );
      expect(doubledPt.isAreaText, isFalse);
      expect(doubledPt.fontSize, closeTo(48.0, 0.5));

      // Convert to Area Frame Text and resize width narrower so lines wrap taller
      final areaText = pointText.copyWith(
        text:
            'Vector typography inside a bounded rectangular frame wraps cleanly across lines.',
        frameWidth: 360,
        frameHeight: 80,
      );
      expect(areaText.isAreaText, isTrue);

      final narrowed = areaText.resizeLocalBounds(
        Bounds2D.fromLTWH(50, 50, 140, 90),
      );
      expect(narrowed.frameWidth, closeTo(140.0, 1e-6));
      expect(narrowed.fontSize, closeTo(24.0, 1e-6)); // fontSize stays fixed in Frame mode
      expect(narrowed.localBounds.height, greaterThanOrEqualTo(90.0));
    });

    test('round-trips TextObject in .vectra JSON and exports <text>/<tspan> SVG', () {
      var doc = VectorDocument.createNew(name: 'Typography Sheet');
      doc = doc.addObject(
        const TextObject(
          id: 'txt_hero',
          name: 'Headline',
          layerId: '',
          text: 'VECTRA\nPhase 2',
          x: 100,
          y: 120,
          fontFamily: 'Inter',
          fontSize: 36,
          fontWeightValue: 700,
          isItalic: true,
          textAlign: TextAlign.center,
          lineHeight: 1.3,
          letterSpacing: 1.5,
          fill: FillStyle(color: Color(0xFFA78BFA)),
        ),
      );

      doc = EditorCommands.updateTextObject(
        doc,
        'txt_hero',
        (t) => t.copyWith(fontSize: 40),
      );

      const serializer = DocumentSerializer();
      const deserializer = DocumentDeserializer();
      const exporter = SvgExporter();

      final json = serializer.serialize(doc);
      final restored = deserializer.deserialize(json);
      final restoredText = restored.findObjectById('txt_hero') as TextObject;

      expect(restoredText.text, 'VECTRA\nPhase 2');
      expect(restoredText.fontSize, 40);
      expect(restoredText.fontWeightValue, 700);
      expect(restoredText.isItalic, isTrue);
      expect(restoredText.textAlign, TextAlign.center);
      expect(restoredText.letterSpacing, closeTo(1.5, 1e-6));

      final svg = exporter.export(restored);
      expect(svg, contains('<text id="txt_hero"'));
      expect(svg, contains('font-weight="700"'));
      expect(svg, contains('font-style="italic"'));
      expect(svg, contains('<tspan'));
      expect(svg, contains('>VECTRA</tspan>'));
      expect(svg, contains('>Phase 2</tspan>'));
    });
  });
}
