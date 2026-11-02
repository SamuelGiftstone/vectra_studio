import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/editor_constants.dart';
import '../../editor/editor_commands.dart';
import '../../math/bounds2d.dart';
import '../../math/geometry_math.dart';
import '../../models/anchor_point.dart';
import '../../models/group_object.dart';
import '../../models/image_object.dart';
import '../../models/path_object.dart';
import '../../models/polygon_object.dart';
import '../../models/rectangle_object.dart';
import '../../models/star_object.dart';
import '../../models/vector_object.dart';
import '../../providers/editor_providers.dart';
import 'numeric_field.dart';

/// Inspector section displaying and editing object identity, visibility, lock state,
/// position (`X`, `Y`), dimensions (`W`, `H`), rotation (`°`), and shape-specific geometry.
class TransformSection extends ConsumerStatefulWidget {
  final VectorObject object;

  const TransformSection({
    super.key,
    required this.object,
  });

  @override
  ConsumerState<TransformSection> createState() => _TransformSectionState();
}

class _TransformSectionState extends ConsumerState<TransformSection> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocus;
  late String _boundObjectId;

  @override
  void initState() {
    super.initState();
    _boundObjectId = widget.object.id;
    _nameController = TextEditingController(text: widget.object.name);
    _nameFocus = FocusNode()..addListener(_onNameFocusChange);
  }

  @override
  void didUpdateWidget(covariant TransformSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.object.id != _boundObjectId) {
      _boundObjectId = widget.object.id;
      _nameController.text = widget.object.name;
    } else if (!_nameFocus.hasFocus &&
        _nameController.text != widget.object.name) {
      _nameController.text = widget.object.name;
    }
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onNameFocusChange);
    _nameFocus.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onNameFocusChange() {
    if (!_nameFocus.hasFocus) {
      _commitName();
    }
  }

  void _commitName() {
    if (widget.object.id != _boundObjectId) return;
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) {
      _nameController.text = widget.object.name;
      return;
    }
    if (trimmed == widget.object.name) return;

    ref.read(editorControllerProvider).renameObject(widget.object.id, trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final obj = widget.object;
    final docCtrl = ref.read(documentControllerProvider.notifier);
    final selectedIds = ref.read(selectedIdsProvider);
    final selectedAnchorIdx = ref.watch(selectedAnchorIndexProvider);
    final transform = obj.transform;
    final isLocked = obj.locked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Object header: type badge, editable name, visibility, lock
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentSubtle,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Text(
                obj.type.displayLabel.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: obj.visible ? 'Hide Object' : 'Show Object',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              padding: EdgeInsets.zero,
              icon: Icon(
                obj.visible ? AppIcons.visible : AppIcons.hidden,
                size: 15,
                color: obj.visible ? AppColors.textSecondary : AppColors.textMuted,
              ),
              onPressed: () {
                docCtrl.executeEdit(
                  label: obj.visible ? 'Hide Object' : 'Show Object',
                  mutator: (doc) =>
                      doc.updateObject(obj.id, (o) => o.withVisibility(!o.visible)),
                  beforeSelection: selectedIds,
                );
                ref
                    .read(selectionControllerProvider.notifier)
                    .reconcileWithDocument(ref.read(currentDocumentProvider));
              },
            ),
            IconButton(
              tooltip: obj.locked ? 'Unlock Object' : 'Lock Object',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              padding: EdgeInsets.zero,
              icon: Icon(
                obj.locked ? AppIcons.locked : AppIcons.unlocked,
                size: 15,
                color: obj.locked ? AppColors.warning : AppColors.textSecondary,
              ),
              onPressed: () {
                docCtrl.executeEdit(
                  label: obj.locked ? 'Unlock Object' : 'Lock Object',
                  mutator: (doc) =>
                      doc.updateObject(obj.id, (o) => o.withLocked(!o.locked)),
                  beforeSelection: selectedIds,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: AppDimensions.inputHeight,
          child: TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            style: const TextStyle(fontSize: 12),
            onSubmitted: (_) => _commitName(),
            decoration: const InputDecoration(
              hintText: 'Object Name',
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'TRANSFORM',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: NumericInspectorField(
                ownerKey: obj.id,
                label: 'X',
                value: transform.x,
                enabled: !isLocked,
                onCommitted: (nextX) {
                  final bounds = obj.localBounds;
                  final nextBounds = Bounds2D.fromLTWH(
                    nextX,
                    bounds.top,
                    bounds.width,
                    bounds.height,
                  );
                  docCtrl.executeEdit(
                    label: 'Change X Position',
                    mutator: (doc) =>
                        EditorCommands.resizeObject(doc, obj.id, nextBounds),
                    beforeSelection: selectedIds,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumericInspectorField(
                ownerKey: obj.id,
                label: 'Y',
                value: transform.y,
                enabled: !isLocked,
                onCommitted: (nextY) {
                  final bounds = obj.localBounds;
                  final nextBounds = Bounds2D.fromLTWH(
                    bounds.left,
                    nextY,
                    bounds.width,
                    bounds.height,
                  );
                  docCtrl.executeEdit(
                    label: 'Change Y Position',
                    mutator: (doc) =>
                        EditorCommands.resizeObject(doc, obj.id, nextBounds),
                    beforeSelection: selectedIds,
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: NumericInspectorField(
                ownerKey: obj.id,
                label: 'W',
                value: transform.width,
                min: 1.0,
                max: EditorConstants.maxArtboardSize,
                enabled: !isLocked,
                onCommitted: (nextW) {
                  final bounds = obj.localBounds;
                  final nextBounds = Bounds2D.fromLTWH(
                    bounds.left,
                    bounds.top,
                    nextW,
                    bounds.height,
                  );
                  docCtrl.executeEdit(
                    label: 'Change Width',
                    mutator: (doc) =>
                        EditorCommands.resizeObject(doc, obj.id, nextBounds),
                    beforeSelection: selectedIds,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumericInspectorField(
                ownerKey: obj.id,
                label: 'H',
                value: transform.height,
                min: 1.0,
                max: EditorConstants.maxArtboardSize,
                enabled: !isLocked,
                onCommitted: (nextH) {
                  final bounds = obj.localBounds;
                  final nextBounds = Bounds2D.fromLTWH(
                    bounds.left,
                    bounds.top,
                    bounds.width,
                    nextH,
                  );
                  docCtrl.executeEdit(
                    label: 'Change Height',
                    mutator: (doc) =>
                        EditorCommands.resizeObject(doc, obj.id, nextBounds),
                    beforeSelection: selectedIds,
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: NumericInspectorField(
                ownerKey: obj.id,
                label: 'R°',
                value: transform.rotationDegrees,
                min: -360.0,
                max: 360.0,
                enabled: !isLocked,
                onCommitted: (deg) {
                  final rad = GeometryMath.degreesToRadians(deg);
                  docCtrl.executeEdit(
                    label: 'Change Rotation',
                    mutator: (doc) =>
                        EditorCommands.rotateObject(doc, obj.id, rad),
                    beforeSelection: selectedIds,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            if (obj is RectangleObject)
              Expanded(
                child: NumericInspectorField(
                  ownerKey: obj.id,
                  label: 'Rad',
                  value: obj.cornerRadius,
                  min: 0.0,
                  max: 1000.0,
                  enabled: !isLocked,
                  onCommitted: (radius) {
                    docCtrl.executeEdit(
                      label: 'Change Corner Radius',
                      mutator: (doc) => EditorCommands.updateRectangleCornerRadius(
                        doc,
                        obj.id,
                        radius,
                      ),
                      beforeSelection: selectedIds,
                    );
                  },
                ),
              )
            else if (obj is PolygonObject)
              Expanded(
                child: NumericInspectorField(
                  ownerKey: obj.id,
                  label: 'Sides',
                  value: obj.sides.toDouble(),
                  decimals: 0,
                  min: EditorConstants.minPolygonSides.toDouble(),
                  max: EditorConstants.maxPolygonSides.toDouble(),
                  enabled: !isLocked,
                  onCommitted: (sides) {
                    docCtrl.executeEdit(
                      label: 'Change Polygon Sides',
                      mutator: (doc) => EditorCommands.updatePolygonSides(
                        doc,
                        obj.id,
                        sides.round(),
                      ),
                      beforeSelection: selectedIds,
                    );
                  },
                ),
              )
            else
              const Expanded(child: SizedBox()),
          ],
        ),
        if (obj is StarObject) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: NumericInspectorField(
                  ownerKey: obj.id,
                  label: 'Pts',
                  value: obj.points.toDouble(),
                  decimals: 0,
                  min: EditorConstants.minStarPoints.toDouble(),
                  max: EditorConstants.maxStarPoints.toDouble(),
                  enabled: !isLocked,
                  onCommitted: (pts) {
                    docCtrl.executeEdit(
                      label: 'Change Star Points',
                      mutator: (doc) => EditorCommands.updateStarProperties(
                        doc,
                        obj.id,
                        points: pts.round(),
                      ),
                      beforeSelection: selectedIds,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumericInspectorField(
                  ownerKey: obj.id,
                  label: 'In%',
                  value: obj.innerRadiusRatio * 100.0,
                  decimals: 0,
                  min: 10.0,
                  max: 92.0,
                  enabled: !isLocked,
                  onCommitted: (pct) {
                    docCtrl.executeEdit(
                      label: 'Change Star Inner Ratio',
                      mutator: (doc) => EditorCommands.updateStarProperties(
                        doc,
                        obj.id,
                        innerRadiusRatio: pct / 100.0,
                      ),
                      beforeSelection: selectedIds,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
        if (obj is PathObject) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text(
                '${obj.anchors.length} anchors · ${obj.closed ? 'Closed' : 'Open'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                onTap: isLocked
                    ? null
                    : () {
                        docCtrl.executeEdit(
                          label: obj.closed ? 'Open Path' : 'Close Path',
                          mutator: (doc) => doc.updateObject(
                            obj.id,
                            (curr) => curr is PathObject
                                ? curr.copyWith(closed: !curr.closed)
                                : curr,
                          ),
                          beforeSelection: selectedIds,
                        );
                      },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondarySurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    obj.closed ? 'Open Path' : 'Close Path',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (selectedAnchorIdx != null &&
              selectedAnchorIdx >= 0 &&
              selectedAnchorIdx < obj.anchors.length) ...<Widget>[
            const SizedBox(height: 8),
            _AnchorNodeControls(
              path: obj,
              anchorIndex: selectedAnchorIdx,
              enabled: !isLocked,
            ),
          ],
        ],
        if (obj is ImageObject) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text(
                'Source: ${obj.naturalWidth}×${obj.naturalHeight} px',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                onTap: isLocked
                    ? null
                    : () {
                        docCtrl.executeEdit(
                          label: obj.preserveAspectRatio
                              ? 'Unlock Image Aspect Ratio'
                              : 'Lock Image Aspect Ratio',
                          mutator: (doc) => EditorCommands.updateImageObject(
                            doc,
                            obj.id,
                            (curr) => curr.copyWith(
                              preserveAspectRatio: !curr.preserveAspectRatio,
                            ),
                          ),
                          beforeSelection: selectedIds,
                        );
                      },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: obj.preserveAspectRatio
                        ? AppColors.surfaceActive
                        : AppColors.secondarySurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(
                      color: obj.preserveAspectRatio
                          ? AppColors.accent
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    obj.preserveAspectRatio ? 'Aspect Locked' : 'Free Aspect',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: obj.preserveAspectRatio
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (obj is GroupObject) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text(
                '${obj.children.length} grouped item${obj.children.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                onTap: isLocked
                    ? null
                    : () => ref.read(editorControllerProvider).ungroupSelection(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondarySurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        AppIcons.ungroup,
                        size: 12,
                        color: AppColors.textPrimary,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Ungroup',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AnchorNodeControls extends ConsumerWidget {
  final PathObject path;
  final int anchorIndex;
  final bool enabled;

  const _AnchorNodeControls({
    required this.path,
    required this.anchorIndex,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchor = path.anchors[anchorIndex];
    final editor = ref.read(editorControllerProvider);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'ACTIVE ANCHOR #${anchorIndex + 1} (${anchor.nodeType.name.toUpperCase()})',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: _SmallActionChip(
                  label: 'Corner',
                  selected: anchor.nodeType == NodeType.corner,
                  onTap: enabled
                      ? () => editor.setSelectedAnchorNodeType(NodeType.corner)
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SmallActionChip(
                  label: 'Smooth',
                  selected: anchor.nodeType != NodeType.corner,
                  onTap: enabled
                      ? () => editor.setSelectedAnchorNodeType(NodeType.smooth)
                      : null,
                ),
              ),
              if (path.anchors.length > 2) ...<Widget>[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Delete Selected Anchor',
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    AppIcons.delete,
                    size: 14,
                    color: AppColors.danger,
                  ),
                  onPressed: enabled ? editor.deleteSelectedAnchor : null,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallActionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _SmallActionChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceActive : AppColors.inputBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
