import 'dart:math' as math;

import '../core/utils/id_generator.dart';
import '../core/utils/validation_utils.dart';
import '../math/bounds2d.dart';
import '../math/geometry_math.dart';
import '../math/vec2.dart';
import 'fill_style.dart';
import 'stroke_style.dart';
import 'vector_object.dart';

/// Hierarchical container grouping two or more [VectorObject]s (including nested
/// [GroupObject]s) as a single selectable, movable, resizable, and rotatable unit.
class GroupObject extends VectorObject {
  final List<VectorObject> children;
  final bool expanded;

  GroupObject({
    required super.id,
    required super.name,
    required super.layerId,
    required List<VectorObject> children,
    this.expanded = true,
    super.fill = FillStyle.none,
    super.stroke = StrokeStyle.none,
    super.opacity = 1.0,
    super.visible = true,
    super.locked = false,
    super.rotation = 0.0,
  })  : children = List<VectorObject>.unmodifiable(children),
        super(type: VectorObjectType.group);

  @override
  Bounds2D get localBounds {
    final visibleOrAll = children.where((c) => c.visible).toList();
    final source = visibleOrAll.isNotEmpty ? visibleOrAll : children;
    if (source.isEmpty) {
      return const Bounds2D(minX: 0, minY: 0, maxX: 1, maxY: 1);
    }
    var union = source.first.worldBounds;
    for (var i = 1; i < source.length; i++) {
      union = union.union(source[i].worldBounds);
    }
    return union;
  }

  GroupObject copyWith({
    String? id,
    String? name,
    String? layerId,
    List<VectorObject>? children,
    bool? expanded,
    FillStyle? fill,
    StrokeStyle? stroke,
    double? opacity,
    bool? visible,
    bool? locked,
    double? rotation,
  }) {
    return GroupObject(
      id: id ?? this.id,
      name: name ?? this.name,
      layerId: layerId ?? this.layerId,
      children: children ?? this.children,
      expanded: expanded ?? this.expanded,
      fill: fill ?? this.fill,
      stroke: stroke ?? this.stroke,
      opacity: (opacity ?? this.opacity).clamp(0.0, 1.0),
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      rotation: rotation ?? this.rotation,
    );
  }

  /// Unpacks [children] into parent coordinate space, baking the group's [rotation]
  /// and [opacity] into each child so visual appearance is preserved on Ungroup.
  List<VectorObject> unpackChildrenForUngroup() {
    final groupPivot = center;
    final hasRotation = rotation.abs() > 1e-9;

    return children.map((child) {
      var next = child.withLayerId(layerId);
      if (opacity < 0.9999) {
        next = next.withOpacity((child.opacity * opacity).clamp(0.0, 1.0));
      }
      if (hasRotation) {
        final rotatedCenter = GeometryMath.rotatePoint(
          child.center,
          groupPivot,
          rotation,
        );
        final delta = rotatedCenter - child.center;
        next = next.translate(delta).withRotation(child.rotation + rotation);
      }
      return next;
    }).toList();
  }

  @override
  GroupObject translate(Vec2 delta) {
    if (delta.isZero) return this;
    return copyWith(
      children: children.map((c) => c.translate(delta)).toList(),
    );
  }

  @override
  GroupObject resizeLocalBounds(Bounds2D newBounds) {
    final oldBounds = localBounds;
    final oldW = math.max(1e-4, oldBounds.width);
    final oldH = math.max(1e-4, oldBounds.height);
    final scaleX = math.max(1.0, newBounds.width) / oldW;
    final scaleY = math.max(1.0, newBounds.height) / oldH;

    final resizedChildren = children.map((child) {
      final cb = child.localBounds;
      final relLeft = cb.left - oldBounds.left;
      final relTop = cb.top - oldBounds.top;
      final mappedBounds = Bounds2D.fromLTWH(
        newBounds.left + relLeft * scaleX,
        newBounds.top + relTop * scaleY,
        math.max(1.0, cb.width * scaleX),
        math.max(1.0, cb.height * scaleY),
      );
      return child.resizeLocalBounds(mappedBounds);
    }).toList();

    return copyWith(children: resizedChildren);
  }

  @override
  GroupObject withRotation(double newRotationRadians) =>
      copyWith(rotation: newRotationRadians);

  @override
  GroupObject withFill(FillStyle newFill) {
    return copyWith(
      fill: newFill,
      children: children.map((c) => c.withFill(newFill)).toList(),
    );
  }

  @override
  GroupObject withStroke(StrokeStyle newStroke) {
    return copyWith(
      stroke: newStroke,
      children: children.map((c) => c.withStroke(newStroke)).toList(),
    );
  }

  @override
  GroupObject withOpacity(double newOpacity) => copyWith(opacity: newOpacity);

  @override
  GroupObject withName(String newName) => copyWith(name: newName);

  @override
  GroupObject withVisibility(bool isVisible) => copyWith(visible: isVisible);

  @override
  GroupObject withLocked(bool isLocked) => copyWith(locked: isLocked);

  @override
  GroupObject withLayerId(String newLayerId) {
    return copyWith(
      layerId: newLayerId,
      children: children.map((c) => c.withLayerId(newLayerId)).toList(),
    );
  }

  @override
  GroupObject duplicateWithNewId({
    required String newId,
    String? newLayerId,
    Vec2 offset = Vec2.zero,
  }) {
    final targetLayer = newLayerId ?? layerId;
    final clonedChildren = children
        .map(
          (c) => c.duplicateWithNewId(
            newId: c is GroupObject ? IdGenerator.groupId() : IdGenerator.objectId(),
            newLayerId: targetLayer,
            offset: offset,
          ),
        )
        .toList();
    return copyWith(
      id: newId,
      name: '$name Copy',
      layerId: targetLayer,
      children: clonedChildren,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseFieldsToJson(),
        'expanded': expanded,
        'children': children.map((c) => c.toJson()).toList(),
      };

  factory GroupObject.fromJson(
    Map<String, dynamic> json, {
    required VectorObject Function(Map<String, dynamic> childJson) childParser,
  }) {
    final rawChildren = json['children'];
    if (rawChildren != null && rawChildren is! List) {
      throw const FormatException('GroupObject "children" must be a JSON list.');
    }

    final layerId = (json['layerId'] as String?) ?? '';
    final parsedChildren = <VectorObject>[];
    if (rawChildren is List) {
      for (final item in rawChildren) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Malformed child inside GroupObject.');
        }
        parsedChildren.add(childParser(item).withLayerId(layerId));
      }
    }

    return GroupObject(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Group',
      layerId: layerId,
      children: parsedChildren,
      expanded: json['expanded'] is bool ? json['expanded'] as bool : true,
      fill: FillStyle.fromJson(
        json['fill'] as Map<String, dynamic>?,
        fallback: FillStyle.none,
      ),
      stroke: StrokeStyle.fromJson(
        json['stroke'] as Map<String, dynamic>?,
        fallback: StrokeStyle.none,
      ),
      opacity: ValidationUtils.optionalDouble(json['opacity'], 1.0).clamp(
        0.0,
        1.0,
      ),
      visible: json['visible'] is bool ? json['visible'] as bool : true,
      locked: json['locked'] is bool ? json['locked'] as bool : false,
      rotation: ValidationUtils.optionalDouble(json['rotation'], 0.0),
    );
  }
}
