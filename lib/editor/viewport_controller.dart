import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/editor_constants.dart';
import '../math/bounds2d.dart';
import '../math/transform_math.dart';
import '../math/vec2.dart';

/// Controls how floating object name tags are displayed over the viewport canvas.
enum TagDisplayMode {
  all,
  selectedAndHovered,
  hidden;

  String get label {
    switch (this) {
      case TagDisplayMode.all:
        return 'All Tags';
      case TagDisplayMode.selectedAndHovered:
        return 'Selected & Hover';
      case TagDisplayMode.hidden:
        return 'Hide Tags';
    }
  }

  TagDisplayMode get next {
    switch (this) {
      case TagDisplayMode.all:
        return TagDisplayMode.selectedAndHovered;
      case TagDisplayMode.selectedAndHovered:
        return TagDisplayMode.hidden;
      case TagDisplayMode.hidden:
        return TagDisplayMode.all;
    }
  }
}

/// Immutable viewport transform, grid, and floating tag configuration state.
class ViewportState {
  final double zoom;
  final Offset panOffset;
  final Size viewportSize;
  final bool showGrid;
  final double gridSize;
  final TagDisplayMode tagDisplayMode;
  final Vec2? cursorDocPosition;
  final bool hasInitializedFit;

  const ViewportState({
    this.zoom = 1.0,
    this.panOffset = const Offset(120, 80),
    this.viewportSize = Size.zero,
    this.showGrid = false,
    this.gridSize = EditorConstants.defaultGridSize,
    this.tagDisplayMode = TagDisplayMode.all,
    this.cursorDocPosition,
    this.hasInitializedFit = false,
  });

  int get zoomPercentage => (zoom * 100.0).round();

  Vec2 screenToDocument(Offset screenPoint) => TransformMath.screenToDocument(
        screenPoint,
        panOffset: panOffset,
        zoom: zoom,
      );

  Offset documentToScreen(Vec2 docPoint) => TransformMath.documentToScreen(
        docPoint,
        panOffset: panOffset,
        zoom: zoom,
      );

  ViewportState copyWith({
    double? zoom,
    Offset? panOffset,
    Size? viewportSize,
    bool? showGrid,
    double? gridSize,
    TagDisplayMode? tagDisplayMode,
    Vec2? cursorDocPosition,
    bool clearCursorPosition = false,
    bool? hasInitializedFit,
  }) {
    return ViewportState(
      zoom: zoom ?? this.zoom,
      panOffset: panOffset ?? this.panOffset,
      viewportSize: viewportSize ?? this.viewportSize,
      showGrid: showGrid ?? this.showGrid,
      gridSize: gridSize ?? this.gridSize,
      tagDisplayMode: tagDisplayMode ?? this.tagDisplayMode,
      cursorDocPosition: clearCursorPosition
          ? null
          : (cursorDocPosition ?? this.cursorDocPosition),
      hasInitializedFit: hasInitializedFit ?? this.hasInitializedFit,
    );
  }
}

/// Manages zoom, panning, artboard/artwork/selection fitting, floating tag display,
/// and screen/document coordinate conversion.
class ViewportController extends StateNotifier<ViewportState> {
  ViewportController() : super(const ViewportState());

  /// Updates the measured canvas viewport size and keeps the artboard centered on resize.
  void updateViewportSize(
    Size newSize, {
    required double docWidth,
    required double docHeight,
  }) {
    if (newSize.width <= 0 || newSize.height <= 0) return;

    if (!state.hasInitializedFit) {
      state = state.copyWith(viewportSize: newSize);
      fitArtboard(docWidth: docWidth, docHeight: docHeight);
      return;
    }

    if (state.viewportSize == newSize) return;
    final dx = (newSize.width - state.viewportSize.width) * 0.5;
    final dy = (newSize.height - state.viewportSize.height) * 0.5;
    state = state.copyWith(
      viewportSize: newSize,
      panOffset: state.panOffset + Offset(dx, dy),
    );
  }

  /// Fits and centers an arbitrary document-space [Bounds2D] inside the viewport
  /// with comfortable padding, clamped within safe zoom bounds.
  void fitBounds(
    Bounds2D bounds, {
    double padding = EditorConstants.fitViewportPadding,
    double maxAutoZoom = 4.0,
  }) {
    final vw = state.viewportSize.width;
    final vh = state.viewportSize.height;
    final bw = math.max(16.0, bounds.width);
    final bh = math.max(16.0, bounds.height);

    if (vw <= 10 || vh <= 10) {
      state = state.copyWith(
        zoom: 1.0,
        panOffset: Offset(80 - bounds.left, 60 - bounds.top),
      );
      return;
    }

    final availW = math.max(64.0, vw - padding * 2.0);
    final availH = math.max(64.0, vh - padding * 2.0);
    final targetZoom = math
        .min(availW / bw, availH / bh)
        .clamp(EditorConstants.minZoom, maxAutoZoom);

    final center = bounds.center;
    final panX = (vw * 0.5) - center.x * targetZoom;
    final panY = (vh * 0.5) - center.y * targetZoom;

    state = state.copyWith(
      zoom: targetZoom,
      panOffset: Offset(panX, panY),
      hasInitializedFit: true,
    );
  }

  /// Fits and centers the artboard inside the current viewport with comfortable margin.
  void fitArtboard({
    required double docWidth,
    required double docHeight,
  }) {
    if (docWidth <= 0 || docHeight <= 0) return;
    fitBounds(
      Bounds2D.fromLTWH(0, 0, docWidth, docHeight),
      padding: EditorConstants.fitViewportPadding,
      maxAutoZoom: 2.0,
    );
  }

  /// Resets zoom to 100% centered on the artboard.
  void resetZoomTo100({
    required double docWidth,
    required double docHeight,
  }) {
    final vw = state.viewportSize.width;
    final vh = state.viewportSize.height;
    if (vw <= 10 || vh <= 10) {
      state = state.copyWith(zoom: 1.0);
      return;
    }
    state = state.copyWith(
      zoom: 1.0,
      panOffset: Offset(
        (vw - docWidth) * 0.5,
        (vh - docHeight) * 0.5,
      ),
    );
  }

  void zoomIn() {
    final center = Offset(
      state.viewportSize.width * 0.5,
      state.viewportSize.height * 0.5,
    );
    zoomByFactor(EditorConstants.zoomStepFactor, focalScreenPoint: center);
  }

  void zoomOut() {
    final center = Offset(
      state.viewportSize.width * 0.5,
      state.viewportSize.height * 0.5,
    );
    zoomByFactor(1.0 / EditorConstants.zoomStepFactor, focalScreenPoint: center);
  }

  /// Zooms smoothly around [focalScreenPoint] so the document point under the cursor stays stationary.
  void zoomByFactor(double factor, {required Offset focalScreenPoint}) {
    final nextZoom = (state.zoom * factor).clamp(
      EditorConstants.minZoom,
      EditorConstants.maxZoom,
    );
    if ((nextZoom - state.zoom).abs() < 1e-6) return;

    final docBefore = state.screenToDocument(focalScreenPoint);
    final nextPan = Offset(
      focalScreenPoint.dx - docBefore.x * nextZoom,
      focalScreenPoint.dy - docBefore.y * nextZoom,
    );

    state = state.copyWith(
      zoom: nextZoom,
      panOffset: nextPan,
    );
  }

  void panBy(Offset screenDelta) {
    state = state.copyWith(panOffset: state.panOffset + screenDelta);
  }

  void toggleGrid() {
    state = state.copyWith(showGrid: !state.showGrid);
  }

  void setTagDisplayMode(TagDisplayMode mode) {
    if (state.tagDisplayMode == mode) return;
    state = state.copyWith(tagDisplayMode: mode);
  }

  void cycleTagDisplayMode() {
    state = state.copyWith(tagDisplayMode: state.tagDisplayMode.next);
  }

  void setCursorPosition(Vec2? docPosition) {
    if (docPosition == null) {
      state = state.copyWith(clearCursorPosition: true);
    } else {
      state = state.copyWith(cursorDocPosition: docPosition);
    }
  }
}
