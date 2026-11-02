import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'bounds2d.dart';
import 'vec2.dart';

/// Enumeration of the 8 resize handles + rotation handle around a selection box.
enum ResizeHandle {
  topLeft,
  topCenter,
  topRight,
  middleRight,
  bottomRight,
  bottomCenter,
  bottomLeft,
  middleLeft,
}

/// Coordinate conversions, viewport transforms, and handle-based resize calculations.
class TransformMath {
  TransformMath._();

  /// Converts a viewport screen [Offset] into document coordinates given [panOffset] and [zoom].
  static Vec2 screenToDocument(
    Offset screenPoint, {
    required Offset panOffset,
    required double zoom,
  }) {
    final safeZoom = zoom <= 1e-6 ? 1.0 : zoom;
    return Vec2(
      (screenPoint.dx - panOffset.dx) / safeZoom,
      (screenPoint.dy - panOffset.dy) / safeZoom,
    );
  }

  /// Converts a document [Vec2] into viewport screen [Offset] given [panOffset] and [zoom].
  static Offset documentToScreen(
    Vec2 docPoint, {
    required Offset panOffset,
    required double zoom,
  }) {
    return Offset(
      docPoint.x * zoom + panOffset.dx,
      docPoint.y * zoom + panOffset.dy,
    );
  }

  /// Transforms a world document point into an object's unrotated local frame around [pivot].
  static Vec2 worldToLocal(Vec2 worldPoint, Vec2 pivot, double rotationRadians) {
    if (rotationRadians.abs() < 1e-9) return worldPoint;
    return worldPoint.rotateAround(pivot, -rotationRadians);
  }

  /// Transforms a point from an object's local frame back to world document coordinates.
  static Vec2 localToWorld(Vec2 localPoint, Vec2 pivot, double rotationRadians) {
    if (rotationRadians.abs() < 1e-9) return localPoint;
    return localPoint.rotateAround(pivot, rotationRadians);
  }

  /// Computes a drag-creation [Bounds2D] from [anchor] and [current] with optional
  /// square/proportional constraint ([constrainSquare]) and draw-from-center ([fromCenter]).
  static Bounds2D dragBounds(
    Vec2 anchor,
    Vec2 current, {
    bool constrainSquare = false,
    bool fromCenter = false,
  }) {
    var dx = current.x - anchor.x;
    var dy = current.y - anchor.y;

    if (constrainSquare) {
      final side = math.max(dx.abs(), dy.abs());
      dx = dx < 0 ? -side : side;
      dy = dy < 0 ? -side : side;
    }

    if (fromCenter) {
      return Bounds2D.fromLTWH(
        anchor.x - dx.abs(),
        anchor.y - dy.abs(),
        dx.abs() * 2.0,
        dy.abs() * 2.0,
      );
    }

    return Bounds2D.fromLTWH(anchor.x, anchor.y, dx, dy);
  }

  /// Returns the local position of each [ResizeHandle] on [bounds].
  static Vec2 handleLocalPosition(Bounds2D bounds, ResizeHandle handle) {
    final cx = (bounds.minX + bounds.maxX) * 0.5;
    final cy = (bounds.minY + bounds.maxY) * 0.5;
    switch (handle) {
      case ResizeHandle.topLeft:
        return Vec2(bounds.minX, bounds.minY);
      case ResizeHandle.topCenter:
        return Vec2(cx, bounds.minY);
      case ResizeHandle.topRight:
        return Vec2(bounds.maxX, bounds.minY);
      case ResizeHandle.middleRight:
        return Vec2(bounds.maxX, cy);
      case ResizeHandle.bottomRight:
        return Vec2(bounds.maxX, bounds.maxY);
      case ResizeHandle.bottomCenter:
        return Vec2(cx, bounds.maxY);
      case ResizeHandle.bottomLeft:
        return Vec2(bounds.minX, bounds.maxY);
      case ResizeHandle.middleLeft:
        return Vec2(bounds.minX, cy);
    }
  }

  /// Computes updated local [Bounds2D] when dragging [handle] to [localPointer]
  /// (expressed in the initial object's unrotated local frame).
  static Bounds2D computeResizedBounds({
    required Bounds2D initialBounds,
    required ResizeHandle handle,
    required Vec2 localPointer,
    bool keepAspectRatio = false,
    double minSize = 2.0,
  }) {
    var minX = initialBounds.minX;
    var minY = initialBounds.minY;
    var maxX = initialBounds.maxX;
    var maxY = initialBounds.maxY;

    switch (handle) {
      case ResizeHandle.topLeft:
        minX = math.min(localPointer.x, maxX - minSize);
        minY = math.min(localPointer.y, maxY - minSize);
        break;
      case ResizeHandle.topCenter:
        minY = math.min(localPointer.y, maxY - minSize);
        break;
      case ResizeHandle.topRight:
        maxX = math.max(localPointer.x, minX + minSize);
        minY = math.min(localPointer.y, maxY - minSize);
        break;
      case ResizeHandle.middleRight:
        maxX = math.max(localPointer.x, minX + minSize);
        break;
      case ResizeHandle.bottomRight:
        maxX = math.max(localPointer.x, minX + minSize);
        maxY = math.max(localPointer.y, minY + minSize);
        break;
      case ResizeHandle.bottomCenter:
        maxY = math.max(localPointer.y, minY + minSize);
        break;
      case ResizeHandle.bottomLeft:
        minX = math.min(localPointer.x, maxX - minSize);
        maxY = math.max(localPointer.y, minY + minSize);
        break;
      case ResizeHandle.middleLeft:
        minX = math.min(localPointer.x, maxX - minSize);
        break;
    }

    if (keepAspectRatio &&
        initialBounds.width > 1e-6 &&
        initialBounds.height > 1e-6) {
      final aspect = initialBounds.width / initialBounds.height;
      final newW = maxX - minX;
      final newH = maxY - minY;

      final isCorner = handle == ResizeHandle.topLeft ||
          handle == ResizeHandle.topRight ||
          handle == ResizeHandle.bottomRight ||
          handle == ResizeHandle.bottomLeft;

      if (isCorner) {
        if (newW / newH > aspect) {
          final targetH = newW / aspect;
          if (handle == ResizeHandle.topLeft || handle == ResizeHandle.topRight) {
            minY = maxY - targetH;
          } else {
            maxY = minY + targetH;
          }
        } else {
          final targetW = newH * aspect;
          if (handle == ResizeHandle.topLeft ||
              handle == ResizeHandle.bottomLeft) {
            minX = maxX - targetW;
          } else {
            maxX = minX + targetW;
          }
        }
      }
    }

    return Bounds2D(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }
}
