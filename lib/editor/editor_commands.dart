import '../core/utils/id_generator.dart';
import '../math/bounds2d.dart';
import '../math/vec2.dart';
import '../models/anchor_point.dart';
import '../models/fill_style.dart';
import '../models/group_object.dart';
import '../models/image_object.dart';
import '../models/path_object.dart';
import '../models/polygon_object.dart';
import '../models/rectangle_object.dart';
import '../models/star_object.dart';
import '../models/stroke_style.dart';
import '../models/text_object.dart';
import '../models/vector_document.dart';
import '../models/vector_object.dart';

/// Pure, reusable document editing operations invoked by controllers, tools, and UI panels.
class EditorCommands {
  EditorCommands._();

  static VectorDocument translateObjects(
    VectorDocument document,
    Set<String> objectIds,
    Vec2 delta,
  ) {
    if (objectIds.isEmpty || delta.isZero) return document;
    return document.updateObjects(objectIds, (obj) {
      if (document.isObjectEffectivelyLocked(obj.id)) return obj;
      return obj.translate(delta);
    });
  }

  static VectorDocument resizeObject(
    VectorDocument document,
    String objectId,
    Bounds2D newLocalBounds,
  ) {
    return document.updateObject(objectId, (obj) {
      if (document.isObjectEffectivelyLocked(obj.id)) return obj;
      return obj.resizeLocalBounds(newLocalBounds);
    });
  }

  static VectorDocument rotateObject(
    VectorDocument document,
    String objectId,
    double rotationRadians,
  ) {
    return document.updateObject(objectId, (obj) {
      if (document.isObjectEffectivelyLocked(obj.id)) return obj;
      return obj.withRotation(rotationRadians);
    });
  }

  static VectorDocument updateFill(
    VectorDocument document,
    Set<String> objectIds,
    FillStyle Function(FillStyle current) updater,
  ) {
    return document.updateObjects(
      objectIds,
      (obj) => obj.withFill(updater(obj.fill)),
    );
  }

  static VectorDocument updateStroke(
    VectorDocument document,
    Set<String> objectIds,
    StrokeStyle Function(StrokeStyle current) updater,
  ) {
    return document.updateObjects(
      objectIds,
      (obj) => obj.withStroke(updater(obj.stroke)),
    );
  }

  static VectorDocument updateOpacity(
    VectorDocument document,
    Set<String> objectIds,
    double opacity,
  ) {
    return document.updateObjects(
      objectIds,
      (obj) => obj.withOpacity(opacity),
    );
  }

  static VectorDocument updateTextObject(
    VectorDocument document,
    String objectId,
    TextObject Function(TextObject current) updater,
  ) {
    return document.updateObject(objectId, (obj) {
      if (obj is TextObject && !document.isObjectEffectivelyLocked(obj.id)) {
        return updater(obj);
      }
      return obj;
    });
  }

  static VectorDocument updateImageObject(
    VectorDocument document,
    String objectId,
    ImageObject Function(ImageObject current) updater,
  ) {
    return document.updateObject(objectId, (obj) {
      if (obj is ImageObject && !document.isObjectEffectivelyLocked(obj.id)) {
        return updater(obj);
      }
      return obj;
    });
  }

  static VectorDocument updateRectangleCornerRadius(
    VectorDocument document,
    String objectId,
    double cornerRadius,
  ) {
    return document.updateObject(objectId, (obj) {
      if (obj is RectangleObject) {
        return obj.copyWith(cornerRadius: cornerRadius);
      }
      return obj;
    });
  }

  static VectorDocument updatePolygonSides(
    VectorDocument document,
    String objectId,
    int sides,
  ) {
    return document.updateObject(objectId, (obj) {
      if (obj is PolygonObject) {
        return obj.copyWith(sides: sides);
      }
      return obj;
    });
  }

  static VectorDocument updateStarProperties(
    VectorDocument document,
    String objectId, {
    int? points,
    double? innerRadiusRatio,
  }) {
    return document.updateObject(objectId, (obj) {
      if (obj is StarObject) {
        return obj.copyWith(
          points: points,
          innerRadiusRatio: innerRadiusRatio,
        );
      }
      return obj;
    });
  }

  static VectorDocument updatePathAnchor(
    VectorDocument document,
    String pathId,
    int anchorIndex,
    AnchorPoint Function(AnchorPoint current) updater,
  ) {
    return document.updateObject(pathId, (obj) {
      if (obj is PathObject) {
        return obj.updateAnchorAt(anchorIndex, updater);
      }
      return obj;
    });
  }

  /// Duplicates [selectedIds] (including groups and nested children) with a slight offset
  /// and returns both the updated [VectorDocument] and the newly created object IDs.
  static ({VectorDocument document, Set<String> createdIds}) duplicateObjects(
    VectorDocument document,
    Set<String> selectedIds, {
    Vec2 offset = const Vec2(20.0, 20.0),
  }) {
    var nextDoc = document;
    final created = <String>{};

    for (final layer in document.layers) {
      if (layer.locked || !layer.visible) continue;
      for (final obj in layer.objects) {
        if (!selectedIds.contains(obj.id) || obj.locked) continue;
        final newId =
            obj is GroupObject ? IdGenerator.groupId() : IdGenerator.objectId();
        final clone = obj.duplicateWithNewId(
          newId: newId,
          newLayerId: layer.id,
          offset: offset,
        );
        nextDoc = nextDoc.addObject(clone, targetLayerId: layer.id);
        created.add(newId);
      }
    }

    return (document: nextDoc, createdIds: created);
  }
}
