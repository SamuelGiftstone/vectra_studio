import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:vectora_studio_software/editor/document_controller.dart';
import 'package:vectora_studio_software/editor/editor_commands.dart';
import 'package:vectora_studio_software/editor/editor_controller.dart';
import 'package:vectora_studio_software/editor/object_naming_service.dart';
import 'package:vectora_studio_software/editor/selection_controller.dart';
import 'package:vectora_studio_software/editor/tool_controller.dart';
import 'package:vectora_studio_software/editor/viewport_controller.dart';
import 'package:vectora_studio_software/math/vec2.dart';
import 'package:vectora_studio_software/models/ellipse_object.dart';
import 'package:vectora_studio_software/models/fill_style.dart';
import 'package:vectora_studio_software/models/group_object.dart';
import 'package:vectora_studio_software/models/rectangle_object.dart';
import 'package:vectora_studio_software/models/stroke_style.dart';
import 'package:vectora_studio_software/models/vector_document.dart';
import 'package:vectora_studio_software/models/vector_object.dart';
import 'package:vectora_studio_software/storage/project_storage.dart';
import 'package:vectora_studio_software/ui/workspace/object_tag_overlay.dart';

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

  group('ObjectNamingService & Synchronized Renaming', () {
    test('generates zero-padded sequential names and prevents empty names', () {
      var doc = VectorDocument.createNew();
      expect(doc.nextObjectName(VectorObjectType.rectangle), 'Rectangle 01');

      doc = doc.addObject(
        RectangleObject(
          id: 'r1',
          name: doc.nextObjectName(VectorObjectType.rectangle),
          layerId: '',
          x: 10,
          y: 10,
          width: 80,
          height: 80,
          fill: FillStyle.defaultFill,
          stroke: StrokeStyle.defaultStroke,
        ),
      );
      expect(doc.nextObjectName(VectorObjectType.rectangle), 'Rectangle 02');
      expect(doc.nextObjectName(VectorObjectType.text), 'Text 01');
      expect(doc.nextObjectName(VectorObjectType.group), 'Group 01');
      expect(doc.nextObjectName(VectorObjectType.image), 'Image 01');

      expect(
        ObjectNamingService.sanitizeName('   ', fallbackName: 'Rectangle 01'),
        'Rectangle 01',
      );
      expect(
        ObjectNamingService.sanitizeName('  Primary CTA  ', fallbackName: 'Rectangle 01'),
        'Primary CTA',
      );
    });

    test('renameObject updates name with undo/redo and rejects blank input', () {
      final editor = createTestEditor();
      editor.documentController.executeEdit(
        label: 'Add Rect',
        mutator: (d) => d.addObject(
          const RectangleObject(
            id: 'r_hero',
            name: 'Rectangle 01',
            layerId: '',
            x: 0,
            y: 0,
            width: 100,
            height: 60,
            fill: FillStyle.defaultFill,
            stroke: StrokeStyle.defaultStroke,
          ),
        ),
      );

      editor.renameObject('r_hero', 'Hero Banner');
      expect(editor.currentDocument.findObjectById('r_hero')!.name, 'Hero Banner');

      // Blank input preserves existing name without pushing undo noise
      editor.renameObject('r_hero', '    ');
      expect(editor.currentDocument.findObjectById('r_hero')!.name, 'Hero Banner');

      editor.undo();
      expect(editor.currentDocument.findObjectById('r_hero')!.name, 'Rectangle 01');
    });
  });

  group('Grouping & Ungrouping Hierarchy', () {
    test('groups selected objects, transforms group as one unit, and ungroups preserving child IDs & transforms', () {
      final editor = createTestEditor();

      editor.documentController.executeEdit(
        label: 'Seed Shapes',
        mutator: (doc) => doc
            .addObject(
              const RectangleObject(
                id: 'card_bg',
                name: 'Card Background',
                layerId: '',
                x: 100,
                y: 100,
                width: 200,
                height: 100,
                fill: FillStyle.defaultFill,
                stroke: StrokeStyle.defaultStroke,
              ),
            )
            .addObject(
              const EllipseObject(
                id: 'card_icon',
                name: 'Card Icon',
                layerId: '',
                x: 120,
                y: 120,
                width: 40,
                height: 40,
                fill: FillStyle.defaultFill,
                stroke: StrokeStyle.defaultStroke,
              ),
            ),
      );

      editor.selectionController.setSelectedIds(const <String>{'card_bg', 'card_icon'});
      expect(editor.canGroupSelection, isTrue);

      editor.groupSelection();
      expect(editor.selectedIds.length, 1);

      final groupId = editor.selectedIds.single;
      final group = editor.currentDocument.findObjectById(groupId) as GroupObject;
      expect(group.name, 'Group 01');
      expect(group.children.length, 2);
      expect(group.children.map((c) => c.id).toList(), <String>['card_bg', 'card_icon']);

      // Translate and rotate the group as a single unit
      editor.documentController.executeEdit(
        label: 'Move & Rotate Group',
        mutator: (doc) {
          final moved = EditorCommands.translateObjects(
            doc,
            <String>{groupId},
            const Vec2(50, 30),
          );
          return EditorCommands.rotateObject(moved, groupId, math.pi / 2);
        },
        beforeSelection: <String>{groupId},
      );

      // Ungroup and verify children retain their IDs, baked rotation, and shifted positions
      expect(editor.canUngroupSelection, isTrue);
      editor.ungroupSelection();
      expect(editor.selectedIds, equals(const <String>{'card_bg', 'card_icon'}));
      expect(editor.currentDocument.findObjectById(groupId), isNull);

      final unpackedRect =
          editor.currentDocument.findObjectById('card_bg') as RectangleObject;
      final unpackedIcon =
          editor.currentDocument.findObjectById('card_icon') as EllipseObject;
      expect(unpackedRect.rotation, closeTo(math.pi / 2, 1e-6));
      expect(unpackedIcon.rotation, closeTo(math.pi / 2, 1e-6));

      // Undo Ungroup restores the GroupObject cleanly
      editor.undo();
      expect(editor.currentDocument.findObjectById(groupId), isA<GroupObject>());
    });
  });

  group('TagLayoutEngine Viewport Projection & Anti-Overlap', () {
    test('projects tags into screen coordinates, respects TagDisplayMode, and avoids collisions', () {
      var doc = VectorDocument.createNew();
      // Two overlapping objects at identical coordinates -> tags must de-overlap!
      doc = doc
          .addObject(
            const RectangleObject(
              id: 'a',
              name: 'Badge 01',
              layerId: '',
              x: 200,
              y: 200,
              width: 120,
              height: 80,
              fill: FillStyle.defaultFill,
              stroke: StrokeStyle.defaultStroke,
            ),
          )
          .addObject(
            const RectangleObject(
              id: 'b',
              name: 'Badge 02',
              layerId: '',
              x: 200,
              y: 200,
              width: 120,
              height: 80,
              fill: FillStyle.defaultFill,
              stroke: StrokeStyle.defaultStroke,
            ),
          );

      const viewportAll = ViewportState(
        zoom: 1.0,
        panOffset: Offset(50, 40),
        viewportSize: Size(1000, 700),
        tagDisplayMode: TagDisplayMode.all,
      );

      final allTags = TagLayoutEngine.computePlacements(
        document: doc,
        viewport: viewportAll,
        selectedIds: const <String>{'a'},
        hoveredObjectId: null,
      );
      expect(allTags.length, 2);
      expect(allTags[0].screenRect.overlaps(allTags[1].screenRect), isFalse);

      // Selected & Hover mode shows only 'a'
      final focusedTags = TagLayoutEngine.computePlacements(
        document: doc,
        viewport: viewportAll.copyWith(
          tagDisplayMode: TagDisplayMode.selectedAndHovered,
        ),
        selectedIds: const <String>{'a'},
        hoveredObjectId: null,
      );
      expect(focusedTags.length, 1);
      expect(focusedTags.single.object.id, 'a');

      // Hidden mode returns empty list
      final hiddenTags = TagLayoutEngine.computePlacements(
        document: doc,
        viewport: viewportAll.copyWith(tagDisplayMode: TagDisplayMode.hidden),
        selectedIds: const <String>{'a'},
        hoveredObjectId: 'b',
      );
      expect(hiddenTags, isEmpty);
    });
  });
}
