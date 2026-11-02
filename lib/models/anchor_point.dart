import '../math/vec2.dart';

/// Node continuity behavior for a Bézier path anchor.
enum NodeType {
  /// Independent incoming and outgoing handles (sharp cusp or straight segment).
  corner,

  /// Collinear incoming and outgoing handles preserving independent handle lengths.
  smooth,

  /// Collinear handles with mirrored equal lengths.
  symmetric;

  static NodeType fromName(String? raw) {
    return NodeType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => NodeType.corner,
    );
  }
}

/// Editable anchor point in a [PathObject].
///
/// [handleIn] and [handleOut] are stored as relative offsets from [position]:
/// - Absolute incoming control point = `position + handleIn`
/// - Absolute outgoing control point = `position + handleOut`
/// - `Vec2.zero` indicates a retracted handle (linear tangent on that side).
class AnchorPoint {
  final String id;
  final Vec2 position;
  final Vec2 handleIn;
  final Vec2 handleOut;
  final NodeType nodeType;

  const AnchorPoint({
    required this.id,
    required this.position,
    this.handleIn = Vec2.zero,
    this.handleOut = Vec2.zero,
    this.nodeType = NodeType.corner,
  });

  const AnchorPoint.corner({
    required this.id,
    required this.position,
  })  : handleIn = Vec2.zero,
        handleOut = Vec2.zero,
        nodeType = NodeType.corner;

  Vec2 get worldHandleIn => position + handleIn;
  Vec2 get worldHandleOut => position + handleOut;

  bool get hasHandleIn => !handleIn.isZero;
  bool get hasHandleOut => !handleOut.isZero;

  AnchorPoint copyWith({
    String? id,
    Vec2? position,
    Vec2? handleIn,
    Vec2? handleOut,
    NodeType? nodeType,
  }) {
    return AnchorPoint(
      id: id ?? this.id,
      position: position ?? this.position,
      handleIn: handleIn ?? this.handleIn,
      handleOut: handleOut ?? this.handleOut,
      nodeType: nodeType ?? this.nodeType,
    );
  }

  /// Translates the anchor position in document coordinates; relative handles follow automatically.
  AnchorPoint translate(Vec2 delta) => copyWith(position: position + delta);

  /// Updates the outgoing handle in world space while enforcing [nodeType] alignment rules.
  AnchorPoint withWorldHandleOut(Vec2 worldTarget, {bool breakSmooth = false}) {
    final newOut = worldTarget - position;
    if (breakSmooth) {
      return copyWith(handleOut: newOut, nodeType: NodeType.corner);
    }
    if (nodeType == NodeType.symmetric) {
      return copyWith(handleOut: newOut, handleIn: -newOut);
    }
    if (nodeType == NodeType.smooth && !newOut.isZero) {
      final inLen = handleIn.length;
      final alignedIn = inLen > 1e-6 ? (-newOut.normalized * inLen) : -newOut;
      return copyWith(handleOut: newOut, handleIn: alignedIn);
    }
    return copyWith(handleOut: newOut);
  }

  /// Updates the incoming handle in world space while enforcing [nodeType] alignment rules.
  AnchorPoint withWorldHandleIn(Vec2 worldTarget, {bool breakSmooth = false}) {
    final newIn = worldTarget - position;
    if (breakSmooth) {
      return copyWith(handleIn: newIn, nodeType: NodeType.corner);
    }
    if (nodeType == NodeType.symmetric) {
      return copyWith(handleIn: newIn, handleOut: -newIn);
    }
    if (nodeType == NodeType.smooth && !newIn.isZero) {
      final outLen = handleOut.length;
      final alignedOut = outLen > 1e-6 ? (-newIn.normalized * outLen) : -newIn;
      return copyWith(handleIn: newIn, handleOut: alignedOut);
    }
    return copyWith(handleIn: newIn);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'position': position.toJson(),
        'handleIn': handleIn.toJson(),
        'handleOut': handleOut.toJson(),
        'nodeType': nodeType.name,
      };

  factory AnchorPoint.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final posMap = json['position'];
    if (id == null || id.isEmpty || posMap is! Map<String, dynamic>) {
      throw const FormatException('Malformed AnchorPoint JSON.');
    }
    final inMap = json['handleIn'];
    final outMap = json['handleOut'];
    return AnchorPoint(
      id: id,
      position: Vec2.fromJson(posMap),
      handleIn: inMap is Map<String, dynamic> ? Vec2.fromJson(inMap) : Vec2.zero,
      handleOut:
          outMap is Map<String, dynamic> ? Vec2.fromJson(outMap) : Vec2.zero,
      nodeType: NodeType.fromName(json['nodeType'] as String?),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnchorPoint &&
          other.id == id &&
          other.position == position &&
          other.handleIn == handleIn &&
          other.handleOut == handleOut &&
          other.nodeType == nodeType);

  @override
  int get hashCode => Object.hash(id, position, handleIn, handleOut, nodeType);
}
