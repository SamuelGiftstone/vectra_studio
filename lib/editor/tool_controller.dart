import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/editor_constants.dart';
import '../math/bounds2d.dart';
import '../math/vec2.dart';
import '../models/anchor_point.dart';
import '../models/fill_style.dart';
import '../models/stroke_style.dart';
import '../models/vector_object.dart';
import 'text_editing_session.dart';

/// Available interactive editing tools in VECTRA Studio.
enum EditorToolType {
  selection,
  node,
  pen,
  text,
  rectangle,
  ellipse,
  line,
  polygon,
  star,
  hand;

  String get label {
    switch (this) {
      case EditorToolType.selection:
        return 'Selection';
      case EditorToolType.node:
        return 'Node Edit';
      case EditorToolType.pen:
        return 'Pen';
      case EditorToolType.text:
        return 'Text';
      case EditorToolType.rectangle:
        return 'Rectangle';
      case EditorToolType.ellipse:
        return 'Ellipse';
      case EditorToolType.line:
        return 'Line';
      case EditorToolType.polygon:
        return 'Polygon';
      case EditorToolType.star:
        return 'Star';
      case EditorToolType.hand:
        return 'Hand Pan';
    }
  }

  String get shortcutKey {
    switch (this) {
      case EditorToolType.selection:
        return 'V';
      case EditorToolType.node:
        return 'N';
      case EditorToolType.pen:
        return 'P';
      case EditorToolType.text:
        return 'T';
      case EditorToolType.rectangle:
        return 'R';
      case EditorToolType.ellipse:
        return 'E';
      case EditorToolType.line:
        return 'L';
      case EditorToolType.polygon:
        return 'G';
      case EditorToolType.star:
        return 'S';
      case EditorToolType.hand:
        return 'H';
    }
  }

  String get statusHint {
    switch (this) {
      case EditorToolType.selection:
        return 'Click to select, drag to move, drag handles to resize/rotate; double-click Text or Path to edit';
      case EditorToolType.node:
        return 'Drag anchors or Bézier handles; double-click anchor to toggle Smooth/Corner; Alt breaks handle';
      case EditorToolType.pen:
        return 'Click for corner anchor, drag for smooth Bézier handles; click start to close, Enter to finish, Esc to cancel';
      case EditorToolType.text:
        return 'Click to insert Point Text, or click-and-drag to create a wrapping Frame Text box (Esc cancels, Ctrl+Enter commits)';
      case EditorToolType.rectangle:
        return 'Drag to draw rectangle (Shift = square, Alt = from center)';
      case EditorToolType.ellipse:
        return 'Drag to draw ellipse (Shift = circle, Alt = from center)';
      case EditorToolType.line:
        return 'Drag to draw line segment (Shift = snap 45°)';
      case EditorToolType.polygon:
        return 'Drag to draw regular polygon (Shift = equal proportions)';
      case EditorToolType.star:
        return 'Drag to draw star (Shift = equal proportions)';
      case EditorToolType.hand:
        return 'Drag anywhere on the canvas to pan viewport';
    }
  }
}

/// Transient, non-persisted tool preview and construction state rendered on the canvas.
class TransientToolState {
  final VectorObject? draftObject;
  final Bounds2D? marqueeBounds;
  final List<AnchorPoint> penAnchors;
  final Vec2? penPreviewPoint;
  final bool isPenHoveringClose;
  final bool isPenDraggingHandle;
  final bool isSpacePanning;
  final bool isHandDragging;

  TransientToolState({
    this.draftObject,
    this.marqueeBounds,
    List<AnchorPoint> penAnchors = const <AnchorPoint>[],
    this.penPreviewPoint,
    this.isPenHoveringClose = false,
    this.isPenDraggingHandle = false,
    this.isSpacePanning = false,
    this.isHandDragging = false,
  }) : penAnchors = List<AnchorPoint>.unmodifiable(penAnchors);

  bool get hasActivePenPath => penAnchors.isNotEmpty;

  static final TransientToolState empty = TransientToolState();

  TransientToolState copyWith({
    VectorObject? draftObject,
    bool clearDraftObject = false,
    Bounds2D? marqueeBounds,
    bool clearMarquee = false,
    List<AnchorPoint>? penAnchors,
    Vec2? penPreviewPoint,
    bool clearPenPreview = false,
    bool? isPenHoveringClose,
    bool? isPenDraggingHandle,
    bool? isSpacePanning,
    bool? isHandDragging,
  }) {
    return TransientToolState(
      draftObject: clearDraftObject ? null : (draftObject ?? this.draftObject),
      marqueeBounds:
          clearMarquee ? null : (marqueeBounds ?? this.marqueeBounds),
      penAnchors: penAnchors ?? this.penAnchors,
      penPreviewPoint:
          clearPenPreview ? null : (penPreviewPoint ?? this.penPreviewPoint),
      isPenHoveringClose: isPenHoveringClose ?? this.isPenHoveringClose,
      isPenDraggingHandle: isPenDraggingHandle ?? this.isPenDraggingHandle,
      isSpacePanning: isSpacePanning ?? this.isSpacePanning,
      isHandDragging: isHandDragging ?? this.isHandDragging,
    );
  }
}

/// Full tool configuration, typography defaults, inline text session, and transient state.
class ToolState {
  final EditorToolType activeTool;
  final int polygonSides;
  final int starPoints;
  final double starInnerRatio;
  final double rectangleCornerRadius;
  final FillStyle defaultFill;
  final StrokeStyle defaultStroke;
  final String defaultFontFamily;
  final double defaultFontSize;
  final int defaultFontWeight;
  final bool defaultItalic;
  final TextAlign defaultTextAlign;
  final FillStyle defaultTextFill;
  final InlineTextEditingSession? activeTextSession;
  final TransientToolState transient;

  ToolState({
    this.activeTool = EditorToolType.selection,
    this.polygonSides = EditorConstants.defaultPolygonSides,
    this.starPoints = EditorConstants.defaultStarPoints,
    this.starInnerRatio = EditorConstants.defaultStarInnerRatio,
    this.rectangleCornerRadius = 0.0,
    this.defaultFill = FillStyle.defaultFill,
    this.defaultStroke = StrokeStyle.defaultStroke,
    this.defaultFontFamily = EditorConstants.defaultFontFamily,
    this.defaultFontSize = EditorConstants.defaultFontSize,
    this.defaultFontWeight = EditorConstants.defaultFontWeight,
    this.defaultItalic = false,
    this.defaultTextAlign = TextAlign.left,
    this.defaultTextFill = const FillStyle(
      color: Color(0xFF18181B),
      opacity: 1.0,
      isEnabled: true,
    ),
    this.activeTextSession,
    TransientToolState? transient,
  }) : transient = transient ?? TransientToolState.empty;

  ToolState copyWith({
    EditorToolType? activeTool,
    int? polygonSides,
    int? starPoints,
    double? starInnerRatio,
    double? rectangleCornerRadius,
    FillStyle? defaultFill,
    StrokeStyle? defaultStroke,
    String? defaultFontFamily,
    double? defaultFontSize,
    int? defaultFontWeight,
    bool? defaultItalic,
    TextAlign? defaultTextAlign,
    FillStyle? defaultTextFill,
    InlineTextEditingSession? activeTextSession,
    bool clearTextSession = false,
    TransientToolState? transient,
  }) {
    return ToolState(
      activeTool: activeTool ?? this.activeTool,
      polygonSides: polygonSides ?? this.polygonSides,
      starPoints: starPoints ?? this.starPoints,
      starInnerRatio: starInnerRatio ?? this.starInnerRatio,
      rectangleCornerRadius:
          rectangleCornerRadius ?? this.rectangleCornerRadius,
      defaultFill: defaultFill ?? this.defaultFill,
      defaultStroke: defaultStroke ?? this.defaultStroke,
      defaultFontFamily: defaultFontFamily ?? this.defaultFontFamily,
      defaultFontSize: defaultFontSize ?? this.defaultFontSize,
      defaultFontWeight: defaultFontWeight ?? this.defaultFontWeight,
      defaultItalic: defaultItalic ?? this.defaultItalic,
      defaultTextAlign: defaultTextAlign ?? this.defaultTextAlign,
      defaultTextFill: defaultTextFill ?? this.defaultTextFill,
      activeTextSession: clearTextSession
          ? null
          : (activeTextSession ?? this.activeTextSession),
      transient: transient ?? this.transient,
    );
  }
}

/// Manages active tool selection, shape/text defaults, inline text session, and transient overlays.
class ToolController extends StateNotifier<ToolState> {
  ToolController() : super(ToolState());

  void selectTool(EditorToolType tool) {
    if (state.activeTool == tool &&
        !state.transient.hasActivePenPath &&
        state.activeTextSession == null) {
      return;
    }
    state = state.copyWith(
      activeTool: tool,
      clearTextSession: true,
      transient: TransientToolState.empty,
    );
  }

  void setActiveTextSession(InlineTextEditingSession? session) {
    if (session == null) {
      state = state.copyWith(clearTextSession: true);
    } else {
      state = state.copyWith(activeTextSession: session);
    }
  }

  void setPolygonSides(int sides) {
    state = state.copyWith(
      polygonSides: sides.clamp(
        EditorConstants.minPolygonSides,
        EditorConstants.maxPolygonSides,
      ),
    );
  }

  void setStarPoints(int points) {
    state = state.copyWith(
      starPoints: points.clamp(
        EditorConstants.minStarPoints,
        EditorConstants.maxStarPoints,
      ),
    );
  }

  void setStarInnerRatio(double ratio) {
    state = state.copyWith(starInnerRatio: ratio.clamp(0.10, 0.92));
  }

  void setRectangleCornerRadius(double radius) {
    state = state.copyWith(rectangleCornerRadius: radius.clamp(0.0, 500.0));
  }

  void setDefaultFill(FillStyle fill) {
    state = state.copyWith(defaultFill: fill);
  }

  void setDefaultStroke(StrokeStyle stroke) {
    state = state.copyWith(defaultStroke: stroke);
  }

  void setTextDefaults({
    String? fontFamily,
    double? fontSize,
    int? fontWeight,
    bool? isItalic,
    TextAlign? textAlign,
    FillStyle? textFill,
  }) {
    state = state.copyWith(
      defaultFontFamily: fontFamily,
      defaultFontSize: fontSize?.clamp(
        EditorConstants.minFontSize,
        EditorConstants.maxFontSize,
      ),
      defaultFontWeight: fontWeight?.clamp(100, 900),
      defaultItalic: isItalic,
      defaultTextAlign: textAlign,
      defaultTextFill: textFill,
    );
  }

  void updateTransient(
    TransientToolState Function(TransientToolState current) updater,
  ) {
    state = state.copyWith(transient: updater(state.transient));
  }

  void clearTransient() {
    state = state.copyWith(transient: TransientToolState.empty);
  }
}
