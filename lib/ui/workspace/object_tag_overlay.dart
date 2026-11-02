import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_icons.dart';
import '../../editor/viewport_controller.dart';
import '../../math/vec2.dart';
import '../../models/group_object.dart';
import '../../models/vector_document.dart';
import '../../models/vector_object.dart';
import '../../providers/editor_providers.dart';

/// Computed screen-space placement for a floating object tag.
class ObjectTagPlacement {
  final VectorObject object;
  final Rect screenRect;
  final bool isSelected;
  final bool isHovered;

  const ObjectTagPlacement({
    required this.object,
    required this.screenRect,
    required this.isSelected,
    required this.isHovered,
  });
}

/// Deterministic layout & anti-overlap engine projecting object geometry bounds
/// into viewport screen coordinates for Floating Object Tags.
class TagLayoutEngine {
  TagLayoutEngine._();

  static const double tagHeight = 20.0;
  static const double minTagWidth = 56.0;
  static const double maxTagWidth = 176.0;

  /// Computes de-overlapped [ObjectTagPlacement]s for visible objects according to [mode].
  static List<ObjectTagPlacement> computePlacements({
    required VectorDocument document,
    required ViewportState viewport,
    required Set<String> selectedIds,
    required String? hoveredObjectId,
    String? activeEditingTextId,
  }) {
    if (viewport.tagDisplayMode == TagDisplayMode.hidden) {
      return const <ObjectTagPlacement>[];
    }

    final candidates = <VectorObject>[];
    final visitedIds = <String>{};

    for (final layer in document.layers) {
      if (!layer.visible) continue;
      for (final obj in layer.objects) {
        if (!obj.visible || obj.id == activeEditingTextId) continue;

        final isSelected = selectedIds.contains(obj.id);
        final isHovered = hoveredObjectId == obj.id;

        if (viewport.tagDisplayMode == TagDisplayMode.all ||
            isSelected ||
            isHovered) {
          candidates.add(obj);
          visitedIds.add(obj.id);
        }

        // Also surface nested child tag if a child inside a group is explicitly selected
        if (obj is GroupObject) {
          _collectSelectedNestedChildren(
            obj,
            selectedIds: selectedIds,
            hoveredObjectId: hoveredObjectId,
            activeEditingTextId: activeEditingTextId,
            visitedIds: visitedIds,
            sink: candidates,
          );
        }
      }
    }

    if (candidates.isEmpty) return const <ObjectTagPlacement>[];

    final placedRects = <Rect>[];
    final placements = <ObjectTagPlacement>[];

    for (final obj in candidates) {
      final wb = obj.worldBounds;
      final topLeftScreen = viewport.documentToScreen(Vec2(wb.minX, wb.minY));
      final bottomLeftScreen =
          viewport.documentToScreen(Vec2(wb.minX, wb.maxY));

      final estTextWidth = obj.name.length * 6.4 + 28.0;
      final width = estTextWidth.clamp(minTagWidth, maxTagWidth);

      // Prefer placing just above the object's top-left corner; flip below if clipped at top
      var x = topLeftScreen.dx;
      var y = topLeftScreen.dy - tagHeight - 5.0;
      if (y < 6.0 && viewport.viewportSize.height > 60) {
        y = bottomLeftScreen.dy + 5.0;
      }

      if (viewport.viewportSize.width > width + 16) {
        x = x.clamp(6.0, math.max(6.0, viewport.viewportSize.width - width - 6.0));
      }

      var candidateRect = Rect.fromLTWH(x, y, width, tagHeight);

      // Smart collision avoidance so nearby objects don't stack unreadably
      var attempts = 0;
      while (attempts < 10 &&
          placedRects.any((r) => r.inflate(2.5).overlaps(candidateRect))) {
        candidateRect = candidateRect.shift(const Offset(0, -(tagHeight + 3.0)));
        if (candidateRect.top < 4.0) {
          candidateRect = Rect.fromLTWH(
            x + (attempts + 1) * 14.0,
            bottomLeftScreen.dy + 5.0 + attempts * (tagHeight + 3.0),
            width,
            tagHeight,
          );
        }
        attempts++;
      }

      // Skip tags completely far offscreen to keep widget tree lightweight
      if (viewport.viewportSize != Size.zero) {
        final screenBounds = Offset.zero & viewport.viewportSize;
        if (!screenBounds.inflate(220.0).overlaps(candidateRect)) {
          continue;
        }
      }

      placedRects.add(candidateRect);
      placements.add(
        ObjectTagPlacement(
          object: obj,
          screenRect: candidateRect,
          isSelected: selectedIds.contains(obj.id),
          isHovered: hoveredObjectId == obj.id,
        ),
      );
    }

    return placements;
  }

  static void _collectSelectedNestedChildren(
    GroupObject group, {
    required Set<String> selectedIds,
    required String? hoveredObjectId,
    required String? activeEditingTextId,
    required Set<String> visitedIds,
    required List<VectorObject> sink,
  }) {
    for (final child in group.children) {
      if (!child.visible || child.id == activeEditingTextId) continue;
      if ((selectedIds.contains(child.id) || hoveredObjectId == child.id) &&
          !visitedIds.contains(child.id)) {
        visitedIds.add(child.id);
        sink.add(child);
      }
      if (child is GroupObject) {
        _collectSelectedNestedChildren(
          child,
          selectedIds: selectedIds,
          hoveredObjectId: hoveredObjectId,
          activeEditingTextId: activeEditingTextId,
          visitedIds: visitedIds,
          sink: sink,
        );
      }
    }
  }
}

/// Interactive viewport overlay rendering compact floating object tags with
/// click-to-select and double-click inline rename synchronized with Layers & Inspector.
class ObjectTagOverlay extends ConsumerStatefulWidget {
  const ObjectTagOverlay({super.key});

  @override
  ConsumerState<ObjectTagOverlay> createState() => _ObjectTagOverlayState();
}

class _ObjectTagOverlayState extends ConsumerState<ObjectTagOverlay> {
  String? _renamingObjectId;
  final TextEditingController _renameController = TextEditingController();
  final FocusNode _renameFocusNode = FocusNode(debugLabel: 'ObjectTagRename');

  @override
  void dispose() {
    _renameFocusNode.dispose();
    _renameController.dispose();
    super.dispose();
  }

  void _startRename(VectorObject obj) {
    setState(() {
      _renamingObjectId = obj.id;
      _renameController.value = TextEditingValue(
        text: obj.name,
        selection: TextSelection(baseOffset: 0, extentOffset: obj.name.length),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _renameFocusNode.requestFocus();
      }
    });
  }

  void _commitRename() {
    final targetId = _renamingObjectId;
    if (targetId == null) return;
    final raw = _renameController.text;
    setState(() => _renamingObjectId = null);
    ref.read(editorControllerProvider).renameObject(targetId, raw);
  }

  void _cancelRename() {
    setState(() => _renamingObjectId = null);
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
    final document = ref.watch(currentDocumentProvider);
    final viewport = ref.watch(viewportControllerProvider);
    final selection = ref.watch(selectionControllerProvider);
    final activeTextSession = ref.watch(activeTextSessionProvider);

    final placements = TagLayoutEngine.computePlacements(
      document: document,
      viewport: viewport,
      selectedIds: selection.selectedIds,
      hoveredObjectId: selection.hoveredObjectId,
      activeEditingTextId: activeTextSession?.objectId,
    );

    if (placements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        for (final item in placements)
          Positioned(
            key: ValueKey<String>('tag_${item.object.id}'),
            left: item.screenRect.left,
            top: item.screenRect.top,
            child: _buildTagChip(item, document),
          ),
      ],
    );
  }

  Widget _buildTagChip(ObjectTagPlacement item, VectorDocument document) {
    final obj = item.object;
    final isRenaming = _renamingObjectId == obj.id;
    final isLocked = document.isObjectEffectivelyLocked(obj.id);
    final borderColor = item.isSelected
        ? AppColors.accent
        : (item.isHovered ? AppColors.accentHover : AppColors.border);
    final bgColor = item.isSelected
        ? AppColors.primaryPanel.withOpacity(0.95)
        : AppColors.mainBackground.withOpacity(0.86);

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {},
      child: GestureDetector(
        onTap: () {
          if (isRenaming) return;
          final editor = ref.read(editorControllerProvider);
          if (editor.activeTextSession != null) {
            editor.commitInlineTextEditing();
          }
          if (isLocked) return;

          final isShift = HardwareKeyboard.instance.isShiftPressed;
          if (isShift) {
            ref.read(selectionControllerProvider.notifier).toggleObject(obj.id);
          } else {
            ref.read(selectionControllerProvider.notifier).selectSingle(obj.id);
          }
          ref.read(documentControllerProvider.notifier).setActiveLayer(obj.layerId);
        },
        onDoubleTap: () {
          if (isLocked) return;
          _startRename(obj);
        },
        child: Container(
          height: TagLayoutEngine.tagHeight,
          constraints: BoxConstraints(
            minWidth: TagLayoutEngine.minTagWidth,
            maxWidth: isRenaming ? 190.0 : TagLayoutEngine.maxTagWidth,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(
              color: borderColor,
              width: item.isSelected ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                _iconForType(obj.type),
                size: 10.5,
                color: item.isSelected
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              if (isRenaming)
                SizedBox(
                  width: 120,
                  height: 18,
                  child: Focus(
                    onKeyEvent: (_, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.escape) {
                        _cancelRename();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _renameController,
                      focusNode: _renameFocusNode,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textPrimary,
                      ),
                      onSubmitted: (_) => _commitRename(),
                      onTapOutside: (_) => _commitRename(),
                      decoration: const InputDecoration(
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 2),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: Text(
                    obj.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          item.isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: item.isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              if (isLocked && !isRenaming) ...<Widget>[
                const SizedBox(width: 4),
                const Icon(
                  AppIcons.locked,
                  size: 9.5,
                  color: AppColors.warning,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
