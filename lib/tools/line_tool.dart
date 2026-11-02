import 'dart:math' as math;

import '../core/utils/id_generator.dart';
import '../editor/editor_controller.dart';
import '../editor/tool_controller.dart';
import '../math/geometry_math.dart';
import '../math/vec2.dart';
import '../models/fill_style.dart';
import '../models/line_object.dart';
import '../models/vector_object.dart';
import 'editor_tool.dart';

/// Drag-to-create Line Tool (`L`) with optional 45° angle snapping when Shift is held.
class LineTool extends ShapeDragTool {
  @override
  EditorToolType get type => EditorToolType.line;

  @override
  String get creationHistoryLabel => 'Create Line';

  @override
  VectorObject? buildShapeObject({
    required EditorController controller,
    required String id,
    required Vec2 startDoc,
    required Vec2 currentDoc,
    required bool isShiftPressed,
    required bool isAltPressed,
  }) {
    var end = currentDoc;
    final rawVec = currentDoc - startDoc;
    final len = rawVec.length;
    if (len < 1.0) return null;

    if (isShiftPressed) {
      final rawAngle = math.atan2(rawVec.y, rawVec.x);
      final snapped = GeometryMath.snapAngleRadians(rawAngle, stepDegrees: 45.0);
      end = startDoc + Vec2(math.cos(snapped) * len, math.sin(snapped) * len);
    }

    final start = isAltPressed ? (startDoc - (end - startDoc)) : startDoc;
    final doc = controller.currentDocument;
    final toolState = controller.toolController.state;
    final stroke = toolState.defaultStroke.isVisible
        ? toolState.defaultStroke
        : toolState.defaultStroke.copyWith(isEnabled: true, width: 2.0);
    final objectId = id.isEmpty ? IdGenerator.objectId() : id;

    return LineObject(
      id: objectId,
      name: doc.nextObjectName(VectorObjectType.line),
      layerId: doc.activeLayer.id,
      start: start,
      end: end,
      fill: FillStyle.none,
      stroke: stroke,
    );
  }
}
