import '../core/utils/id_generator.dart';
import '../models/group_object.dart';
import '../models/vector_document.dart';
import '../models/vector_layer.dart';
import '../models/vector_object.dart';

/// Pure document-hierarchy operations for Grouping (`Ctrl+G`) and Ungrouping (`Ctrl+Shift+G`).
class GroupingService {
  GroupingService._();

  /// Returns `true` when [selectedIds] contains at least 2 unlocked, visible objects
  /// eligible to be combined into a [GroupObject].
  static bool canGroup(VectorDocument document, Set<String> selectedIds) {
    if (selectedIds.length < 2) return false;
    var eligible = 0;
    for (final layer in document.layers) {
      if (!layer.visible || layer.locked) continue;
      for (final obj in layer.objects) {
        if (selectedIds.contains(obj.id) && obj.visible && !obj.locked) {
          eligible++;
          if (eligible >= 2) return true;
        }
      }
    }
    return false;
  }

  /// Returns `true` when [selectedIds] contains at least one unlocked [GroupObject].
  static bool canUngroup(VectorDocument document, Set<String> selectedIds) {
    if (selectedIds.isEmpty) return false;
    for (final id in selectedIds) {
      final obj = document.findObjectById(id);
      if (obj is GroupObject &&
          document.isObjectEffectivelyVisible(id) &&
          !document.isObjectEffectivelyLocked(id)) {
        return true;
      }
    }
    return false;
  }

  /// Groups two or more selected top-level objects into a single [GroupObject],
  /// preserving their bottom-to-top relative stacking order, IDs, styles, and coordinates,
  /// and inserting the group at the z-order slot of the top-most grouped member.
  static ({VectorDocument document, String? groupId}) groupSelectedObjects(
    VectorDocument document,
    Set<String> selectedIds,
  ) {
    if (selectedIds.length < 2) {
      return (document: document, groupId: null);
    }

    final collected = <VectorObject>[];
    String? targetLayerId;
    int targetInsertIndex = 0;

    for (var l = 0; l < document.layers.length; l++) {
      final layer = document.layers[l];
      if (!layer.visible || layer.locked) continue;
      for (var i = 0; i < layer.objects.length; i++) {
        final obj = layer.objects[i];
        if (selectedIds.contains(obj.id) && obj.visible && !obj.locked) {
          collected.add(obj);
          targetLayerId = layer.id;
          targetInsertIndex = i;
        }
      }
    }

    if (collected.length < 2 || targetLayerId == null) {
      return (document: document, groupId: null);
    }

    final groupedIds = collected.map((o) => o.id).toSet();
    final groupId = IdGenerator.groupId();
    final groupName = document.nextObjectName(VectorObjectType.group);

    final normalizedChildren =
        collected.map((c) => c.withLayerId(targetLayerId!)).toList();

    final groupObject = GroupObject(
      id: groupId,
      name: groupName,
      layerId: targetLayerId,
      children: normalizedChildren,
      expanded: true,
    );

    final updatedLayers = <VectorLayer>[];
    for (final layer in document.layers) {
      if (layer.id != targetLayerId) {
        final remaining =
            layer.objects.where((o) => !groupedIds.contains(o.id)).toList();
        updatedLayers.add(
          remaining.length == layer.objects.length
              ? layer
              : layer.copyWith(objects: remaining),
        );
        continue;
      }

      // Insert the new group at the exact visual position of the highest selected object
      final nextObjects = <VectorObject>[];
      for (var i = 0; i < layer.objects.length; i++) {
        final obj = layer.objects[i];
        if (i == targetInsertIndex) {
          nextObjects.add(groupObject);
        }
        if (!groupedIds.contains(obj.id)) {
          nextObjects.add(obj);
        }
      }
      updatedLayers.add(layer.copyWith(objects: nextObjects));
    }

    return (
      document: document.copyWith(
        layers: updatedLayers,
        activeLayerId: targetLayerId,
      ),
      groupId: groupId,
    );
  }

  /// Ungroups all selected [GroupObject] instances in-place (both top-level and nested),
  /// baking any group rotation or opacity into the unpacked children and returning
  /// the restored child IDs.
  static ({VectorDocument document, Set<String> restoredChildIds})
      ungroupSelectedObjects(
    VectorDocument document,
    Set<String> selectedIds,
  ) {
    if (selectedIds.isEmpty) {
      return (document: document, restoredChildIds: const <String>{});
    }

    final restoredIds = <String>{};
    var changed = false;

    List<VectorObject> expandGroups(List<VectorObject> list, bool parentLocked) {
      var localChanged = false;
      final out = <VectorObject>[];

      for (final obj in list) {
        final isLocked = parentLocked || obj.locked;
        if (obj is GroupObject && !isLocked && selectedIds.contains(obj.id)) {
          final unpacked = obj.unpackChildrenForUngroup();
          for (final child in unpacked) {
            restoredIds.add(child.id);
          }
          out.addAll(unpacked);
          localChanged = true;
          changed = true;
          continue;
        }

        if (obj is GroupObject) {
          final updatedChildren = expandGroups(obj.children, isLocked);
          if (!identical(updatedChildren, obj.children)) {
            out.add(obj.copyWith(children: updatedChildren));
            localChanged = true;
            changed = true;
            continue;
          }
        }

        out.add(obj);
      }

      return localChanged ? out : list;
    }

    final updatedLayers = document.layers.map((layer) {
      if (!layer.visible || layer.locked) return layer;
      final nextObjects = expandGroups(layer.objects, layer.locked);
      return identical(nextObjects, layer.objects)
          ? layer
          : layer.copyWith(objects: nextObjects);
    }).toList();

    if (!changed) {
      return (document: document, restoredChildIds: const <String>{});
    }

    return (
      document: document.copyWith(layers: updatedLayers),
      restoredChildIds: restoredIds,
    );
  }
}
