import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';
import '../../models/group_object.dart';
import '../../models/vector_layer.dart';
import '../../models/vector_object.dart';
import '../../providers/editor_providers.dart';
import 'layer_row.dart';

/// Synchronized Layers & Objects hierarchy panel.
///
/// Displays layers, groups, and child vector objects in top-to-bottom visual
/// stacking order (top-most drawn item at the top of the list), with recursive
/// group expansion, Group/Ungroup header actions, and unified renaming.
class LayersPanel extends ConsumerWidget {
  const LayersPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layers = ref.watch(layersListProvider);
    final activeLayerId = ref.watch(activeLayerIdProvider);
    final selectedIds = ref.watch(selectedIdsProvider);
    final docCtrl = ref.read(documentControllerProvider.notifier);
    final selCtrl = ref.read(selectionControllerProvider.notifier);
    final editor = ref.read(editorControllerProvider);

    final canGroup = editor.canGroupSelection;
    final canUngroup = editor.canUngroupSelection;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primaryPanel,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: AppColors.secondarySurface,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  AppIcons.layers,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                const Text(
                  'LAYERS & OBJECTS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: 'Group Selection (Ctrl+G)',
                  child: InkWell(
                    onTap: canGroup ? editor.groupSelection : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        AppIcons.group,
                        size: 14,
                        color: canGroup
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Tooltip(
                  message: 'Ungroup Selection (Ctrl+Shift+G)',
                  child: InkWell(
                    onTap: canUngroup ? editor.ungroupSelection : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        AppIcons.ungroup,
                        size: 14,
                        color: canUngroup
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'New Layer',
                  child: InkWell(
                    onTap: () {
                      docCtrl.executeEdit(
                        label: 'Add Layer',
                        mutator: (doc) => doc.addLayer(),
                        beforeSelection: selectedIds,
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        AppIcons.add,
                        size: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: <Widget>[
                for (var l = layers.length - 1; l >= 0; l--) ...<Widget>[
                  LayerHeaderRow(
                    key: ValueKey<String>('lyr_${layers[l].id}'),
                    layer: layers[l],
                    isActive: layers[l].id == activeLayerId,
                    canDelete: layers.length > 1,
                    onSelect: () => docCtrl.setActiveLayer(layers[l].id),
                    onToggleExpand: () =>
                        docCtrl.toggleLayerExpanded(layers[l].id),
                    onToggleVisible: () {
                      final layer = layers[l];
                      docCtrl.executeEdit(
                        label: layer.visible ? 'Hide Layer' : 'Show Layer',
                        mutator: (doc) => doc.updateLayer(
                          layer.id,
                          (curr) => curr.copyWith(visible: !curr.visible),
                        ),
                        beforeSelection: selectedIds,
                      );
                      selCtrl.reconcileWithDocument(
                        ref.read(currentDocumentProvider),
                      );
                    },
                    onToggleLocked: () {
                      final layer = layers[l];
                      docCtrl.executeEdit(
                        label: layer.locked ? 'Unlock Layer' : 'Lock Layer',
                        mutator: (doc) => doc.updateLayer(
                          layer.id,
                          (curr) => curr.copyWith(locked: !curr.locked),
                        ),
                        beforeSelection: selectedIds,
                      );
                      selCtrl.reconcileWithDocument(
                        ref.read(currentDocumentProvider),
                      );
                    },
                    onRename: (nextName) {
                      final layerId = layers[l].id;
                      docCtrl.executeEdit(
                        label: 'Rename Layer',
                        mutator: (doc) => doc.updateLayer(
                          layerId,
                          (curr) => curr.copyWith(name: nextName),
                        ),
                        beforeSelection: selectedIds,
                      );
                    },
                    onMoveUp: () {
                      final layerId = layers[l].id;
                      docCtrl.executeEdit(
                        label: 'Move Layer Up',
                        mutator: (doc) => doc.moveLayer(layerId, 1),
                        beforeSelection: selectedIds,
                      );
                    },
                    onMoveDown: () {
                      final layerId = layers[l].id;
                      docCtrl.executeEdit(
                        label: 'Move Layer Down',
                        mutator: (doc) => doc.moveLayer(layerId, -1),
                        beforeSelection: selectedIds,
                      );
                    },
                    onDelete: () {
                      final layerId = layers[l].id;
                      docCtrl.executeEdit(
                        label: 'Delete Layer',
                        mutator: (doc) => doc.removeLayer(layerId),
                        beforeSelection: selectedIds,
                      );
                      selCtrl.reconcileWithDocument(
                        ref.read(currentDocumentProvider),
                      );
                    },
                  ),
                  if (layers[l].expanded)
                    if (layers[l].objects.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(26, 6, 12, 8),
                        child: Text(
                          'Empty layer — draw on the artboard to add objects',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    else
                      ..._buildObjectTreeRows(
                        ref: ref,
                        layer: layers[l],
                        objects: layers[l].objects,
                        depth: 0,
                        parentHiddenOrLocked:
                            !layers[l].visible || layers[l].locked,
                        selectedIds: selectedIds,
                      ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildObjectTreeRows({
    required WidgetRef ref,
    required VectorLayer layer,
    required List<VectorObject> objects,
    required int depth,
    required bool parentHiddenOrLocked,
    required Set<String> selectedIds,
  }) {
    final docCtrl = ref.read(documentControllerProvider.notifier);
    final selCtrl = ref.read(selectionControllerProvider.notifier);
    final editor = ref.read(editorControllerProvider);
    final rows = <Widget>[];

    for (var i = objects.length - 1; i >= 0; i--) {
      final obj = objects[i];
      final effectiveHiddenOrLocked =
          parentHiddenOrLocked || !obj.visible || obj.locked;

      rows.add(
        ObjectLayerRow(
          key: ValueKey<String>('obj_${obj.id}'),
          object: obj,
          depth: depth,
          isSelected: selectedIds.contains(obj.id),
          layerHiddenOrLocked: parentHiddenOrLocked,
          onSelect: () {
            docCtrl.setActiveLayer(layer.id);
            if (!effectiveHiddenOrLocked) {
              selCtrl.selectSingle(obj.id);
            }
          },
          onToggleGroupExpand: obj is GroupObject
              ? () => docCtrl.toggleGroupExpanded(obj.id)
              : null,
          onToggleVisible: () {
            docCtrl.executeEdit(
              label: obj.visible ? 'Hide Object' : 'Show Object',
              mutator: (doc) => doc.updateObject(
                obj.id,
                (curr) => curr.withVisibility(!curr.visible),
              ),
              beforeSelection: selectedIds,
            );
            selCtrl.reconcileWithDocument(ref.read(currentDocumentProvider));
          },
          onToggleLocked: () {
            docCtrl.executeEdit(
              label: obj.locked ? 'Unlock Object' : 'Lock Object',
              mutator: (doc) => doc.updateObject(
                obj.id,
                (curr) => curr.withLocked(!curr.locked),
              ),
              beforeSelection: selectedIds,
            );
            selCtrl.reconcileWithDocument(ref.read(currentDocumentProvider));
          },
          onRename: (nextName) => editor.renameObject(obj.id, nextName),
          onMoveForward: () {
            docCtrl.executeEdit(
              label: 'Bring Object Forward',
              mutator: (doc) => doc.moveObjectInLayer(obj.id, 1),
              beforeSelection: selectedIds,
            );
          },
          onMoveBackward: () {
            docCtrl.executeEdit(
              label: 'Send Object Backward',
              mutator: (doc) => doc.moveObjectInLayer(obj.id, -1),
              beforeSelection: selectedIds,
            );
          },
          onDelete: () {
            final nextSel = Set<String>.of(selectedIds)..remove(obj.id);
            docCtrl.executeEdit(
              label: 'Delete Object',
              mutator: (doc) => doc.removeObjects(<String>{obj.id}),
              beforeSelection: selectedIds,
              afterSelection: nextSel,
            );
            selCtrl.setSelectedIds(nextSel);
          },
        ),
      );

      if (obj is GroupObject && obj.expanded && obj.children.isNotEmpty) {
        rows.addAll(
          _buildObjectTreeRows(
            ref: ref,
            layer: layer,
            objects: obj.children,
            depth: depth + 1,
            parentHiddenOrLocked: effectiveHiddenOrLocked,
            selectedIds: selectedIds,
          ),
        );
      }
    }

    return rows;
  }
}
