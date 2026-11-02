import 'dart:ui';

import '../editor/viewport_controller.dart';
import '../math/transform_math.dart';
import '../math/vec2.dart';

/// Bridges [ViewportState] with Flutter's [Canvas] coordinate transformations.
class ViewportTransform {
  final Offset panOffset;
  final double zoom;

  const ViewportTransform({
    required this.panOffset,
    required this.zoom,
  });

  factory ViewportTransform.fromState(ViewportState state) {
    return ViewportTransform(
      panOffset: state.panOffset,
      zoom: state.zoom,
    );
  }

  /// Applies viewport pan and zoom directly onto [canvas] for document-space rendering.
  void applyToCanvas(Canvas canvas) {
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoom, zoom);
  }

  /// Maps a document-space [Vec2] (optionally rotated around [pivot]) into screen [Offset].
  Offset docToScreen(
    Vec2 docPoint, {
    Vec2? pivot,
    double rotationRadians = 0.0,
  }) {
    final worldPt = (pivot != null && rotationRadians.abs() > 1e-9)
        ? TransformMath.localToWorld(docPoint, pivot, rotationRadians)
        : docPoint;
    return TransformMath.documentToScreen(
      worldPt,
      panOffset: panOffset,
      zoom: zoom,
    );
  }

  /// Converts a screen-space pixel length to document units at the current zoom.
  double screenToDocLength(double screenPixels) {
    return screenPixels / (zoom <= 1e-6 ? 1.0 : zoom);
  }
}
