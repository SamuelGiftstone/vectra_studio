import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:vectora_studio_software/editor/artwork_bounds_service.dart';
import 'package:vectora_studio_software/editor/document_controller.dart';
import 'package:vectora_studio_software/editor/editor_controller.dart';
import 'package:vectora_studio_software/editor/selection_controller.dart';
import 'package:vectora_studio_software/editor/tool_controller.dart';
import 'package:vectora_studio_software/editor/viewport_controller.dart';
import 'package:vectora_studio_software/models/fill_style.dart';
import 'package:vectora_studio_software/models/group_object.dart';
import 'package:vectora_studio_software/models/rectangle_object.dart';
import 'package:vectora_studio_software/models/stroke_style.dart';
import 'package:vectora_studio_software/models/vector_document.dart';
import 'package:vectora_studio_software/storage/project_storage.dart';

void main() {
  group('ArtworkBoundsService & Find My Artwork Navigation', () {
    test('returns null on empty or fully hidden documents and falls back to artboard fit', () {
      final editor = EditorController(
        documentController: DocumentController(),
        selectionController: SelectionController(),
        toolController: ToolController(),
        viewportController: ViewportController(),
        projectStorage: const ProjectStorage(),
      );
      editor.viewportController.updateViewportSize(
        const Size(1200, 800),
        docWidth: editor.currentDocument.width,
        docHeight: editor.currentDocument.height,
      );

      expect(
        ArtworkBoundsService.computeVisibleArtworkBounds(editor.currentDocument),
        isNull,
      );

      // Pan far away, then invoke Find My Artwork on empty document -> fits artboard safely
      editor.viewportController.panBy(const Offset(-5000, -4000));
      editor.findMyArtwork();

      final vp = editor.viewportController.state;
      expect(vp.zoom.isFinite, isTrue);
      expect(vp.panOffset.dx.isFinite, isTrue);
      expect(vp.panOffset.dy.isFinite, isTrue);
    });

    test('computes exact union bounds including stroke padding, rotation, and nested groups while ignoring hidden items', () {
      var doc = VectorDocument.createNew(width: 1200, height: 800);

      // Far off-canvas group at (-1800, -900) plus a hidden outlier at (99999, 99999)
      doc = doc
          .addObject(
            GroupObject(
              id: 'far_group',
              name: 'Offscreen Cluster',
              layerId: '',
              children: <RectangleObject>[
                RectangleObject(
                  id: 'r_rot',
                  name: 'Rotated Box',
                  layerId: '',
                  x: -1800,
                  y: -900,
                  width: 200,
                  height: 100,
                  rotation: math.pi / 4,
                  fill: FillStyle.defaultFill,
                  stroke: const StrokeStyle(
                    color: Color(0xFF1E1B4B),
                    width: 10.0,
                    isEnabled: true,
                  ),
                ),
              ],
            ),
          )
          .addObject(
            const RectangleObject(
              id: 'hidden_outlier',
              name: 'Hidden Far Away',
              layerId: '',
              x: 99999,
              y: 99999,
              width: 500,
              height: 500,
              visible: false,
              fill: FillStyle.defaultFill,
              stroke: StrokeStyle.defaultStroke,
            ),
          );

      final bounds = ArtworkBoundsService.computeVisibleArtworkBounds(doc);
      expect(bounds, isNotNull);
      // Hidden object at 99999 must not pollute artwork bounds!
      expect(bounds!.maxX, lessThan(0));
      expect(bounds.minX, lessThan(-1780));
      expect(bounds.width, greaterThan(210)); // rotated 200x100 + 10px stroke

      // Fitting viewport to those off-canvas bounds brings the center of `far_group` to the screen center
      final vpCtrl = ViewportController();
      vpCtrl.updateViewportSize(
        const Size(1000, 700),
        docWidth: doc.width,
        docHeight: doc.height,
      );
      vpCtrl.fitBounds(bounds, padding: 60.0);

      final screenCenterOfArtwork = vpCtrl.state.documentToScreen(bounds.center);
      expect(screenCenterOfArtwork.dx, closeTo(500.0, 1.0));
      expect(screenCenterOfArtwork.dy, closeTo(350.0, 1.0));
    });
  });
}
