import '../math/bounds2d.dart';
import '../models/group_object.dart';
import '../models/vector_document.dart';
import '../models/vector_object.dart';

/// Computes accurate document-space bounding boxes across all visible artwork
/// (including stroke widths, rotated objects, text layout bounds, images, paths,
/// and nested groups) to power "Find My Artwork" and "Focus Selection".
class ArtworkBoundsService {
  ArtworkBoundsService._();

  /// Computes the tight union [Bounds2D] of all visible artwork objects in [document].
  ///
  /// Hidden layers and hidden objects are excluded.
  /// Returns `null` when the document contains zero visible objects so callers can
  /// fall back cleanly to the artboard bounds `(0, 0, document.width, document.height)`.
  static Bounds2D? computeVisibleArtworkBounds(VectorDocument document) {
    Bounds2D? union;

    for (final layer in document.layers) {
      if (!layer.visible) continue;
      for (final obj in layer.objects) {
        if (!obj.visible) continue;
        final objBounds = computeVisualBounds(obj);
        if (objBounds != null) {
          union = union == null ? objBounds : union.union(objBounds);
        }
      }
    }

    return union;
  }

  /// Computes the tight union [Bounds2D] of the currently selected visible objects.
  /// Returns `null` if no visible objects are selected.
  static Bounds2D? computeSelectionBounds(
    VectorDocument document,
    Set<String> selectedIds,
  ) {
    if (selectedIds.isEmpty) return null;
    Bounds2D? union;

    for (final id in selectedIds) {
      if (!document.isObjectEffectivelyVisible(id)) continue;
      final obj = document.findObjectById(id);
      if (obj == null) continue;
      final objBounds = computeVisualBounds(obj);
      if (objBounds != null) {
        union = union == null ? objBounds : union.union(objBounds);
      }
    }

    return union;
  }

  /// Computes the visual world [Bounds2D] of a single [VectorObject], accounting for
  /// stroke thickness, rotation, text layout bounds, image bounds, and group members.
  static Bounds2D? computeVisualBounds(VectorObject object) {
    if (!object.visible) return null;

    if (object is GroupObject) {
      final visibleChildren = object.children.where((c) => c.visible).toList();
      if (visibleChildren.isEmpty) return null;
      var maxStrokePad = 0.0;
      for (final child in visibleChildren) {
        if (child.stroke.isVisible && child.stroke.width * 0.5 > maxStrokePad) {
          maxStrokePad = child.stroke.width * 0.5;
        }
      }
      return object.worldBounds.inflate(maxStrokePad);
    }

    final strokePad =
        object.stroke.isVisible ? object.stroke.width * 0.5 : 0.0;
    return object.worldBounds.inflate(strokePad);
  }
}
