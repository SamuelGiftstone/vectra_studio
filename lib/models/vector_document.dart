import 'package:flutter/painting.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/editor_constants.dart';
import '../core/utils/id_generator.dart';
import '../core/utils/validation_utils.dart';
import '../editor/object_naming_service.dart';
import 'group_object.dart';
import 'image_asset.dart';
import 'image_object.dart';
import 'vector_layer.dart';
import 'vector_object.dart';

/// Root editable vector document shared across canvas, tools, inspector, layers,
/// undo/redo history, `.vectra` persistence, and SVG/PNG/JPEG export.
class VectorDocument {
  final String id;
  final String name;
  final int version;
  final double width;
  final double height;
  final Color backgroundColor;
  final List<VectorLayer> layers;
  final String activeLayerId;
  final Map<String, ImageAsset> assets;
  final DateTime createdAt;
  final DateTime updatedAt;

  VectorDocument({
    required this.id,
    required this.name,
    this.version = EditorConstants.currentSchemaVersion,
    required this.width,
    required this.height,
    this.backgroundColor = AppColors.artboardDefaultBg,
    required List<VectorLayer> layers,
    required this.activeLayerId,
    Map<String, ImageAsset> assets = const <String, ImageAsset>{},
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : layers = List<VectorLayer>.unmodifiable(layers),
        assets = Map<String, ImageAsset>.unmodifiable(assets),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Creates a clean initial document with one default layer.
  factory VectorDocument.createNew({
    String name = 'Untitled Artwork',
    double width = EditorConstants.defaultArtboardWidth,
    double height = EditorConstants.defaultArtboardHeight,
    Color backgroundColor = AppColors.artboardDefaultBg,
  }) {
    final firstLayerId = IdGenerator.layerId();
    final now = DateTime.now();
    return VectorDocument(
      id: IdGenerator.documentId(),
      name: name.trim().isEmpty ? 'Untitled Artwork' : name.trim(),
      version: EditorConstants.currentSchemaVersion,
      width: ValidationUtils.clampDouble(
        width,
        EditorConstants.minArtboardSize,
        EditorConstants.maxArtboardSize,
      ),
      height: ValidationUtils.clampDouble(
        height,
        EditorConstants.minArtboardSize,
        EditorConstants.maxArtboardSize,
      ),
      backgroundColor: backgroundColor,
      layers: <VectorLayer>[
        VectorLayer(id: firstLayerId, name: 'Layer 1'),
      ],
      activeLayerId: firstLayerId,
      assets: const <String, ImageAsset>{},
      createdAt: now,
      updatedAt: now,
    );
  }

  /// All top-level objects across all layers in bottom-to-top painting order.
  List<VectorObject> get allObjects {
    final result = <VectorObject>[];
    for (final layer in layers) {
      result.addAll(layer.objects);
    }
    return result;
  }

  /// All objects across all layers including nested [GroupObject] children
  /// in bottom-to-top depth-first order.
  List<VectorObject> get allObjectsRecursive {
    final result = <VectorObject>[];
    void visit(List<VectorObject> list) {
      for (final obj in list) {
        result.add(obj);
        if (obj is GroupObject) {
          visit(obj.children);
        }
      }
    }

    for (final layer in layers) {
      visit(layer.objects);
    }
    return result;
  }

  /// Total count of top-level vector objects in the document.
  int get objectCount =>
      layers.fold<int>(0, (sum, layer) => sum + layer.objects.length);

  /// Returns the currently active [VectorLayer], falling back to the top-most layer.
  VectorLayer get activeLayer {
    for (final layer in layers) {
      if (layer.id == activeLayerId) return layer;
    }
    return layers.last;
  }

  ImageAsset? findAssetById(String assetId) => assets[assetId];

  VectorObject? findObjectById(String objectId) {
    VectorObject? search(List<VectorObject> list) {
      for (final obj in list) {
        if (obj.id == objectId) return obj;
        if (obj is GroupObject) {
          final found = search(obj.children);
          if (found != null) return found;
        }
      }
      return null;
    }

    for (final layer in layers) {
      final found = search(layer.objects);
      if (found != null) return found;
    }
    return null;
  }

  VectorLayer? findLayerById(String layerId) {
    for (final layer in layers) {
      if (layer.id == layerId) return layer;
    }
    return null;
  }

  VectorLayer? findLayerForObject(String objectId) {
    bool contains(List<VectorObject> list) {
      for (final obj in list) {
        if (obj.id == objectId) return true;
        if (obj is GroupObject && contains(obj.children)) return true;
      }
      return false;
    }

    for (final layer in layers) {
      if (contains(layer.objects)) return layer;
    }
    return null;
  }

  bool isObjectEffectivelyVisible(String objectId) {
    bool? checkInList(List<VectorObject> list, bool parentVisible) {
      for (final obj in list) {
        final selfVisible = parentVisible && obj.visible;
        if (obj.id == objectId) return selfVisible;
        if (obj is GroupObject) {
          final nested = checkInList(obj.children, selfVisible);
          if (nested != null) return nested;
        }
      }
      return null;
    }

    for (final layer in layers) {
      final found = checkInList(layer.objects, layer.visible);
      if (found != null) return found;
    }
    return false;
  }

  bool isObjectEffectivelyLocked(String objectId) {
    bool? checkInList(List<VectorObject> list, bool parentLocked) {
      for (final obj in list) {
        final selfLocked = parentLocked || obj.locked;
        if (obj.id == objectId) return selfLocked;
        if (obj is GroupObject) {
          final nested = checkInList(obj.children, selfLocked);
          if (nested != null) return nested;
        }
      }
      return null;
    }

    for (final layer in layers) {
      final found = checkInList(layer.objects, layer.locked);
      if (found != null) return found;
    }
    return true;
  }

  /// Generates a sequential human-friendly name for newly created objects
  /// (e.g., `Rectangle 01`, `Text 01`, `Group 01`, `Image 01`).
  String nextObjectName(VectorObjectType type, {String? customPrefix}) {
    return ObjectNamingService.nextSequentialName(
      type: type,
      layers: layers,
      customPrefix: customPrefix,
    );
  }

  VectorDocument copyWith({
    String? id,
    String? name,
    int? version,
    double? width,
    double? height,
    Color? backgroundColor,
    List<VectorLayer>? layers,
    String? activeLayerId,
    Map<String, ImageAsset>? assets,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VectorDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      width: width ?? this.width,
      height: height ?? this.height,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      layers: layers ?? this.layers,
      activeLayerId: activeLayerId ?? this.activeLayerId,
      assets: assets ?? this.assets,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Registers or updates an embedded [ImageAsset] in the document asset map.
  VectorDocument addAsset(ImageAsset asset) {
    final nextAssets = Map<String, ImageAsset>.of(assets);
    nextAssets[asset.id] = asset;
    return copyWith(assets: nextAssets);
  }

  /// Removes any [ImageAsset] entries not referenced by any [ImageObject] in the document.
  VectorDocument pruneUnusedAssets() {
    if (assets.isEmpty) return this;
    final usedIds = <String>{};
    for (final obj in allObjectsRecursive) {
      if (obj is ImageObject) {
        usedIds.add(obj.assetId);
      }
    }
    if (usedIds.length == assets.length &&
        assets.keys.every(usedIds.contains)) {
      return this;
    }
    final nextAssets = <String, ImageAsset>{
      for (final entry in assets.entries)
        if (usedIds.contains(entry.key)) entry.key: entry.value,
    };
    return copyWith(assets: nextAssets);
  }

  /// Appends [object] onto [targetLayerId] (or an unlocked active layer).
  VectorDocument addObject(VectorObject object, {String? targetLayerId}) {
    return addObjects(<VectorObject>[object], targetLayerId: targetLayerId);
  }

  /// Appends multiple [objects] onto [targetLayerId] (or an unlocked active layer).
  VectorDocument addObjects(
    List<VectorObject> objectsToAdd, {
    String? targetLayerId,
  }) {
    if (objectsToAdd.isEmpty) return this;

    var chosenLayerId = targetLayerId ?? activeLayer.id;
    final targetLayer = findLayerById(chosenLayerId);
    if (targetLayer == null || targetLayer.locked || !targetLayer.visible) {
      for (var i = layers.length - 1; i >= 0; i--) {
        if (!layers[i].locked && layers[i].visible) {
          chosenLayerId = layers[i].id;
          break;
        }
      }
    }

    final attached =
        objectsToAdd.map((o) => o.withLayerId(chosenLayerId)).toList();
    final updatedLayers = layers.map((layer) {
      if (layer.id != chosenLayerId) return layer;
      return layer.copyWith(objects: <VectorObject>[...layer.objects, ...attached]);
    }).toList();

    return copyWith(layers: updatedLayers, activeLayerId: chosenLayerId);
  }

  /// Updates a single object matching [objectId] anywhere in the layer/group hierarchy.
  VectorDocument updateObject(
    String objectId,
    VectorObject Function(VectorObject current) updater,
  ) {
    return updateObjects(<String>{objectId}, updater);
  }

  /// Updates multiple objects matching [objectIds] anywhere in the layer/group hierarchy.
  VectorDocument updateObjects(
    Set<String> objectIds,
    VectorObject Function(VectorObject current) updater,
  ) {
    if (objectIds.isEmpty) return this;
    var changed = false;

    List<VectorObject> transformList(List<VectorObject> list) {
      var listChanged = false;
      final out = <VectorObject>[];
      for (final obj in list) {
        var current = obj;
        if (objectIds.contains(current.id)) {
          current = updater(current);
          listChanged = true;
          changed = true;
        }
        if (current is GroupObject) {
          final updatedChildren = transformList(current.children);
          if (!identical(updatedChildren, current.children)) {
            current = current.copyWith(children: updatedChildren);
            listChanged = true;
            changed = true;
          }
        }
        out.add(current);
      }
      return listChanged ? out : list;
    }

    final updatedLayers = layers.map((layer) {
      final nextObjects = transformList(layer.objects);
      return identical(nextObjects, layer.objects)
          ? layer
          : layer.copyWith(objects: nextObjects);
    }).toList();

    if (!changed) return this;
    return copyWith(layers: updatedLayers);
  }

  /// Removes all objects whose IDs appear in [objectIds], including nested group children.
  VectorDocument removeObjects(Set<String> objectIds) {
    if (objectIds.isEmpty) return this;
    var changed = false;

    List<VectorObject> filterList(List<VectorObject> list) {
      var listChanged = false;
      final out = <VectorObject>[];
      for (final obj in list) {
        if (objectIds.contains(obj.id)) {
          listChanged = true;
          changed = true;
          continue;
        }
        if (obj is GroupObject) {
          final filteredChildren = filterList(obj.children);
          if (!identical(filteredChildren, obj.children)) {
            listChanged = true;
            changed = true;
            if (filteredChildren.isEmpty) {
              // Automatically drop empty group containers
              continue;
            }
            out.add(obj.copyWith(children: filteredChildren));
            continue;
          }
        }
        out.add(obj);
      }
      return listChanged ? out : list;
    }

    final updatedLayers = layers.map((layer) {
      final filtered = filterList(layer.objects);
      if (identical(filtered, layer.objects)) return layer;
      return layer.copyWith(objects: filtered);
    }).toList();

    if (!changed) return this;
    return copyWith(layers: updatedLayers);
  }

  /// Reorders an object within its parent layer or group (`delta = 1` moves toward front/top, `-1` moves backward).
  VectorDocument moveObjectInLayer(String objectId, int delta) {
    var changed = false;

    List<VectorObject> reorderList(List<VectorObject> list) {
      final idx = list.indexWhere((o) => o.id == objectId);
      if (idx != -1) {
        final newIdx = (idx + delta).clamp(0, list.length - 1);
        if (newIdx == idx) return list;
        final copy = List<VectorObject>.of(list);
        final item = copy.removeAt(idx);
        copy.insert(newIdx, item);
        changed = true;
        return copy;
      }

      var nestedChanged = false;
      final out = <VectorObject>[];
      for (final obj in list) {
        if (obj is GroupObject) {
          final updatedChildren = reorderList(obj.children);
          if (!identical(updatedChildren, obj.children)) {
            nestedChanged = true;
            out.add(obj.copyWith(children: updatedChildren));
            continue;
          }
        }
        out.add(obj);
      }
      return nestedChanged ? out : list;
    }

    final updatedLayers = layers.map((layer) {
      final nextObjects = reorderList(layer.objects);
      return identical(nextObjects, layer.objects)
          ? layer
          : layer.copyWith(objects: nextObjects);
    }).toList();

    if (!changed) return this;
    return copyWith(layers: updatedLayers);
  }

  /// Adds a new empty layer on top and makes it active.
  VectorDocument addLayer({String? customName}) {
    final newId = IdGenerator.layerId();
    final layerNumber = layers.length + 1;
    final name = customName ?? 'Layer $layerNumber';
    final nextLayers = <VectorLayer>[
      ...layers,
      VectorLayer(id: newId, name: name),
    ];
    return copyWith(layers: nextLayers, activeLayerId: newId);
  }

  /// Updates metadata/state of a [VectorLayer].
  VectorDocument updateLayer(
    String layerId,
    VectorLayer Function(VectorLayer current) updater,
  ) {
    final nextLayers = layers
        .map((layer) => layer.id == layerId ? updater(layer) : layer)
        .toList();
    return copyWith(layers: nextLayers);
  }

  /// Deletes a layer (preventing deletion of the last remaining layer).
  VectorDocument removeLayer(String layerId) {
    if (layers.length <= 1) return this;
    final nextLayers = layers.where((l) => l.id != layerId).toList();
    if (nextLayers.isEmpty) return this;
    final nextActive =
        activeLayerId == layerId ? nextLayers.last.id : activeLayerId;
    return copyWith(layers: nextLayers, activeLayerId: nextActive);
  }

  /// Reorders a layer (`delta = 1` moves layer higher in painting order, `-1` moves lower).
  VectorDocument moveLayer(String layerId, int delta) {
    final idx = layers.indexWhere((l) => l.id == layerId);
    if (idx == -1) return this;
    final newIdx = (idx + delta).clamp(0, layers.length - 1);
    if (newIdx == idx) return this;
    final nextLayers = List<VectorLayer>.of(layers);
    final item = nextLayers.removeAt(idx);
    nextLayers.insert(newIdx, item);
    return copyWith(layers: nextLayers);
  }
}
