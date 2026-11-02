import 'vector_object.dart';

/// Ordered container of [VectorObject]s within a [VectorDocument].
///
/// Objects inside [objects] are stored in bottom-to-top painting order
/// (index `0` is painted first, `objects.last` is painted on top).
class VectorLayer {
  final String id;
  final String name;
  final bool visible;
  final bool locked;
  final bool expanded;
  final List<VectorObject> objects;

  VectorLayer({
    required this.id,
    required this.name,
    this.visible = true,
    this.locked = false,
    this.expanded = true,
    List<VectorObject> objects = const <VectorObject>[],
  }) : objects = List<VectorObject>.unmodifiable(objects);

  VectorLayer copyWith({
    String? id,
    String? name,
    bool? visible,
    bool? locked,
    bool? expanded,
    List<VectorObject>? objects,
  }) {
    return VectorLayer(
      id: id ?? this.id,
      name: name ?? this.name,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      expanded: expanded ?? this.expanded,
      objects: objects ?? this.objects,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'visible': visible,
        'locked': locked,
        'expanded': expanded,
        'objects': objects.map((o) => o.toJson()).toList(),
      };
}
