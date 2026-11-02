import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_icons.dart';
import '../../models/group_object.dart';
import '../../models/vector_layer.dart';
import '../../models/vector_object.dart';

/// Header row representing a [VectorLayer] in the Layers panel.
class LayerHeaderRow extends StatefulWidget {
  final VectorLayer layer;
  final bool isActive;
  final bool canDelete;
  final VoidCallback onSelect;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleVisible;
  final VoidCallback onToggleLocked;
  final ValueChanged<String> onRename;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;

  const LayerHeaderRow({
    super.key,
    required this.layer,
    required this.isActive,
    required this.canDelete,
    required this.onSelect,
    required this.onToggleExpand,
    required this.onToggleVisible,
    required this.onToggleLocked,
    required this.onRename,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  @override
  State<LayerHeaderRow> createState() => _LayerHeaderRowState();
}

class _LayerHeaderRowState extends State<LayerHeaderRow> {
  bool _isHovered = false;
  bool _isEditing = false;
  late final TextEditingController _renameController;

  @override
  void initState() {
    super.initState();
    _renameController = TextEditingController(text: widget.layer.name);
  }

  @override
  void didUpdateWidget(covariant LayerHeaderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.layer.name != widget.layer.name) {
      _renameController.text = widget.layer.name;
    }
  }

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  void _commitRename() {
    final trimmed = _renameController.text.trim();
    setState(() => _isEditing = false);
    if (trimmed.isNotEmpty && trimmed != widget.layer.name) {
      widget.onRename(trimmed);
    } else {
      _renameController.text = widget.layer.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        onDoubleTap: () {
          _renameController.text = widget.layer.name;
          setState(() => _isEditing = true);
        },
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.secondarySurface
                : (_isHovered ? AppColors.surfaceHover : Colors.transparent),
            border: Border(
              left: BorderSide(
                color: widget.isActive ? AppColors.accent : Colors.transparent,
                width: 2.5,
              ),
              bottom: const BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: Row(
            children: <Widget>[
              InkWell(
                onTap: widget.onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    widget.layer.expanded ? AppIcons.expand : AppIcons.collapse,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                AppIcons.layers,
                size: 13,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _isEditing
                    ? SizedBox(
                        height: 22,
                        child: TextField(
                          controller: _renameController,
                          autofocus: true,
                          style: const TextStyle(fontSize: 11.5),
                          onSubmitted: (_) => _commitRename(),
                          onTapOutside: (_) => _commitRename(),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        widget.layer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: widget.layer.visible
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
              ),
              if (_isHovered) ...<Widget>[
                _MiniIconButton(
                  icon: AppIcons.moveUp,
                  tooltip: 'Move Layer Up',
                  onTap: widget.onMoveUp,
                ),
                _MiniIconButton(
                  icon: AppIcons.moveDown,
                  tooltip: 'Move Layer Down',
                  onTap: widget.onMoveDown,
                ),
                if (widget.canDelete)
                  _MiniIconButton(
                    icon: AppIcons.delete,
                    tooltip: 'Delete Layer',
                    color: AppColors.danger,
                    onTap: widget.onDelete,
                  ),
              ],
              _MiniIconButton(
                icon: widget.layer.locked ? AppIcons.locked : AppIcons.unlocked,
                tooltip: widget.layer.locked ? 'Unlock Layer' : 'Lock Layer',
                color: widget.layer.locked
                    ? AppColors.warning
                    : (_isHovered ? AppColors.textSecondary : AppColors.textMuted),
                onTap: widget.onToggleLocked,
              ),
              _MiniIconButton(
                icon: widget.layer.visible ? AppIcons.visible : AppIcons.hidden,
                tooltip: widget.layer.visible ? 'Hide Layer' : 'Show Layer',
                color: widget.layer.visible
                    ? AppColors.textSecondary
                    : AppColors.textMuted,
                onTap: widget.onToggleVisible,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Child row representing an individual [VectorObject] inside a [VectorLayer].
class ObjectLayerRow extends StatefulWidget {
  final VectorObject object;
  final int depth;
  final bool isSelected;
  final bool layerHiddenOrLocked;
  final VoidCallback onSelect;
  final VoidCallback? onToggleGroupExpand;
  final VoidCallback onToggleVisible;
  final VoidCallback onToggleLocked;
  final ValueChanged<String> onRename;
  final VoidCallback onMoveForward;
  final VoidCallback onMoveBackward;
  final VoidCallback onDelete;

  const ObjectLayerRow({
    super.key,
    required this.object,
    this.depth = 0,
    required this.isSelected,
    required this.layerHiddenOrLocked,
    required this.onSelect,
    this.onToggleGroupExpand,
    required this.onToggleVisible,
    required this.onToggleLocked,
    required this.onRename,
    required this.onMoveForward,
    required this.onMoveBackward,
    required this.onDelete,
  });

  @override
  State<ObjectLayerRow> createState() => _ObjectLayerRowState();
}

class _ObjectLayerRowState extends State<ObjectLayerRow> {
  bool _isHovered = false;
  bool _isEditing = false;
  late final TextEditingController _renameController;

  @override
  void initState() {
    super.initState();
    _renameController = TextEditingController(text: widget.object.name);
  }

  @override
  void didUpdateWidget(covariant ObjectLayerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.object.name != widget.object.name) {
      _renameController.text = widget.object.name;
    }
  }

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  void _commitRename() {
    final trimmed = _renameController.text.trim();
    setState(() => _isEditing = false);
    if (trimmed.isNotEmpty && trimmed != widget.object.name) {
      widget.onRename(trimmed);
    } else {
      _renameController.text = widget.object.name;
    }
  }

  IconData _iconForType(VectorObjectType type) {
    switch (type) {
      case VectorObjectType.rectangle:
        return AppIcons.rectangle;
      case VectorObjectType.ellipse:
        return AppIcons.ellipse;
      case VectorObjectType.line:
        return AppIcons.line;
      case VectorObjectType.polygon:
        return AppIcons.polygon;
      case VectorObjectType.star:
        return AppIcons.star;
      case VectorObjectType.path:
        return AppIcons.node;
      case VectorObjectType.text:
        return AppIcons.text;
      case VectorObjectType.image:
        return AppIcons.image;
      case VectorObjectType.group:
        return AppIcons.group;
    }
  }

  @override
  Widget build(BuildContext context) {
    final obj = widget.object;
    final leftIndent = 18.0 + widget.depth * 14.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        onDoubleTap: () {
          _renameController.text = obj.name;
          setState(() => _isEditing = true);
        },
        child: Container(
          height: 28,
          padding: EdgeInsets.only(left: leftIndent, right: 6),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.surfaceActive
                : (_isHovered ? AppColors.surfaceHover : Colors.transparent),
            border: Border(
              left: BorderSide(
                color: widget.isSelected ? AppColors.accent : Colors.transparent,
                width: 2.0,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              if (obj is GroupObject)
                InkWell(
                  onTap: widget.onToggleGroupExpand,
                  borderRadius: BorderRadius.circular(3),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      obj.expanded ? AppIcons.expand : AppIcons.collapse,
                      size: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                const SizedBox(width: 4),
              const SizedBox(width: 3),
              Icon(
                _iconForType(obj.type),
                size: 13,
                color: widget.isSelected
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _isEditing
                    ? SizedBox(
                        height: 21,
                        child: TextField(
                          controller: _renameController,
                          autofocus: true,
                          style: const TextStyle(fontSize: 11.5),
                          onSubmitted: (_) => _commitRename(),
                          onTapOutside: (_) => _commitRename(),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        obj.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: widget.isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: (!obj.visible || widget.layerHiddenOrLocked)
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
              ),
              if (_isHovered || widget.isSelected) ...<Widget>[
                _MiniIconButton(
                  icon: AppIcons.moveUp,
                  tooltip: 'Bring Forward',
                  onTap: widget.onMoveForward,
                ),
                _MiniIconButton(
                  icon: AppIcons.moveDown,
                  tooltip: 'Send Backward',
                  onTap: widget.onMoveBackward,
                ),
                _MiniIconButton(
                  icon: AppIcons.rename,
                  tooltip: 'Rename Object',
                  onTap: () {
                    _renameController.text = obj.name;
                    setState(() => _isEditing = true);
                  },
                ),
                _MiniIconButton(
                  icon: AppIcons.delete,
                  tooltip: 'Delete Object',
                  color: AppColors.danger,
                  onTap: widget.onDelete,
                ),
              ],
              _MiniIconButton(
                icon: obj.locked ? AppIcons.locked : AppIcons.unlocked,
                tooltip: obj.locked ? 'Unlock Object' : 'Lock Object',
                color: obj.locked
                    ? AppColors.warning
                    : (_isHovered ? AppColors.textSecondary : AppColors.textMuted),
                onTap: widget.onToggleLocked,
              ),
              _MiniIconButton(
                icon: obj.visible ? AppIcons.visible : AppIcons.hidden,
                tooltip: obj.visible ? 'Hide Object' : 'Show Object',
                color:
                    obj.visible ? AppColors.textSecondary : AppColors.textMuted,
                onTap: widget.onToggleVisible,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    this.color = AppColors.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(3.5),
          child: Icon(icon, size: 12.5, color: color),
        ),
      ),
    );
  }
}
