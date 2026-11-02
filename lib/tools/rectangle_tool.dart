import '../core/utils/id_generator.dart';
import '../editor/editor_controller.dart';
import '../editor/tool_controller.dart';
import '../math/transform_math.dart';
import '../math/vec2.dart';
import '../models/rectangle_object.dart';
import '../models/vector_object.dart';
import 'editor_tool.dart';

/// Drag-to-create Rectangle Tool (`R`).
class RectangleTool extends ShapeDragTool {
  @override
  EditorToolType get type => EditorToolType.rectangle;

  @override
  String get creationHistoryLabel => 'Create Rectangle';

  @override
  VectorObject? buildShapeObject({
    required EditorController controller,
    required String id,
    required Vec2 startDoc,
    required Vec2 currentDoc,
    required bool isShiftPressed,
    required bool isAltPressed,
  }) {
    final bounds = TransformMath.dragBounds(
      startDoc,
      currentDoc,
      constrainSquare: isShiftPressed,
      fromCenter: isAltPressed,
    );
    if (bounds.width < 1.0 && bounds.height < 1.0) return null;

    final doc = controller.currentDocument;
    final toolState = controller.toolController.state;
    final objectId = id.isEmpty ? IdGenerator.objectId() : id;

    return RectangleObject(
      id: objectId,
      name: doc.nextObjectName(VectorObjectType.rectangle),
      layerId: doc.activeLayer.id,
      x: bounds.left,
      y: bounds.top,
      width: bounds.width < 1.0 ? 1.0 : bounds.width,
      height: bounds.height < 1.0 ? 1.0 : bounds.height,
      cornerRadius: toolState.rectangleCornerRadius,
      fill: toolState.defaultFill,
      stroke: toolState.defaultStroke,
    );
  }
}
