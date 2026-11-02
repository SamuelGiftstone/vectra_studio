import '../editor/tool_controller.dart';
import 'editor_tool.dart';
import 'ellipse_tool.dart';
import 'hand_tool.dart';
import 'line_tool.dart';
import 'node_tool.dart';
import 'pen_tool.dart';
import 'polygon_tool.dart';
import 'rectangle_tool.dart';
import 'selection_tool.dart';
import 'star_tool.dart';
import 'text_tool.dart';

/// Maintains one reusable instance of each [EditorTool] keyed by [EditorToolType].
class ToolRegistry {
  final Map<EditorToolType, EditorTool> _tools = <EditorToolType, EditorTool>{
    EditorToolType.selection: SelectionTool(),
    EditorToolType.node: NodeTool(),
    EditorToolType.pen: PenTool(),
    EditorToolType.text: TextTool(),
    EditorToolType.rectangle: RectangleTool(),
    EditorToolType.ellipse: EllipseTool(),
    EditorToolType.line: LineTool(),
    EditorToolType.polygon: PolygonTool(),
    EditorToolType.star: StarTool(),
    EditorToolType.hand: HandTool(),
  };

  EditorTool forType(EditorToolType type) => _tools[type]!;
}
