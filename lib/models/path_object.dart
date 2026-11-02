import '../core/utils/id_generator.dart';
import '../core/utils/validation_utils.dart';
import '../math/bezier_math.dart';
import '../math/bounds2d.dart';
import '../math/vec2.dart';
import 'anchor_point.dart';
import 'fill_style.dart';
import 'stroke_style.dart';
import 'vector_object.dart';

/// Editable cubic Bézier vector path composed of [AnchorPoint]s.
class PathObject extends VectorObject {
  final List<AnchorPoint> anchors;
  final bool closed;

  PathObject({
    required super.id,
    required super.name,
    required super.layerId,
    required List<AnchorPoint> anchors,
    required this.closed,
    required super.fill,
    required super.stroke,
    super.opacity,
    super.visible,
    super.locked,
    super.rotation,
  })  : anchors = List<AnchorPoint>.unmodifiable(anchors),
        super(type: VectorObjectType.path);

  /// Returns ordered [CubicSegment]s representing the curve geometry of this path.
  List<CubicSegment> get segments {
    if (anchors.length < 2) return const <CubicSegment>[];
    final result = <CubicSegment>[];
    for (var i = 0; i < anchors.length - 1; i++) {
      final a = anchors[i];
      final b = anchors[i + 1];
      result.add(
        CubicSegment(
          a.position,
          a.worldHandleOut,
          b.worldHandleIn,
          b.position,
        ),
      );
    }
    if (closed && anchors.length >= 2) {
      final last = anchors.last;
      final first = anchors.first;
      result.add(
        CubicSegment(
          last.position,
          last.worldHandleOut,
          first.worldHandleIn,
          first.position,
        ),
      );
    }
    return result;
  }

  @override
  Bounds2D get localBounds {
    if (anchors.isEmpty) return Bounds2D.zero;
    if (anchors.length == 1) {
      return Bounds2D.fromPoints(<Vec2>[anchors.first.position]);
    }
    final segs = segments;
    var acc = BezierMath.cubicBounds(
      segs.first.p0,
      segs.first.p1,
      segs.first.p2,
      segs.first.p3,
    );
    for (var i = 1; i < segs.length; i++) {
      final seg = segs[i];
      acc = acc.union(
        BezierMath.cubicBounds(seg.p0, seg.p1, seg.p2, seg.p3),
      );
    }
    return acc;
  }

  /// Samples polyline vertices across all Bézier segments (used for interior hit testing).
  List<Vec2> sampleOutline({int stepsPerSegment = 20}) {
    final segs = segments;
    if (segs.isEmpty) {
      return anchors.map((a) => a.position).toList();
    }
    final pts = <Vec2>[];
    for (var i = 0; i < segs.length; i++) {
      final seg = segs[i];
      final samples = BezierMath.sampleCubic(
        seg.p0,
        seg.p1,
        seg.p2,
        seg.p3,
        steps: seg.isLinear ? 1 : stepsPerSegment,
      );
      if (i == 0) {
        pts.addAll(samples);
      } else {
        pts.addAll(samples.skip(1));
      }
    }
    return pts;
  }

  PathObject copyWith({
    String? id,
    String? name,
    String? layerId,
    List<AnchorPoint>? anchors,
    bool? closed,
    FillStyle? fill,
    StrokeStyle? stroke,
    double? opacity,
    bool? visible,
    bool? locked,
    double? rotation,
  }) {
    return PathObject(
      id: id ?? this.id,
      name: name ?? this.name,
      layerId: layerId ?? this.layerId,
      anchors: anchors ?? this.anchors,
      closed: closed ?? this.closed,
      fill: fill ?? this.fill,
      stroke: stroke ?? this.stroke,
      opacity: ValidationUtils.clampDouble(opacity ?? this.opacity, 0.0, 1.0),
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      rotation: rotation ?? this.rotation,
    );
  }

  PathObject updateAnchorAt(
    int index,
    AnchorPoint Function(AnchorPoint current) updater,
  ) {
    if (index < 0 || index >= anchors.length) return this;
    final next = List<AnchorPoint>.of(anchors);
    next[index] = updater(next[index]);
    return copyWith(anchors: next);
  }

  PathObject removeAnchorAt(int index) {
    if (anchors.length <= 2 || index < 0 || index >= anchors.length) {
      return this;
    }
    final next = List<AnchorPoint>.of(anchors)..removeAt(index);
    return copyWith(anchors: next);
  }

  @override
  PathObject translate(Vec2 delta) {
    return copyWith(
      anchors: anchors.map((a) => a.translate(delta)).toList(),
    );
  }

  @override
  PathObject resizeLocalBounds(Bounds2D newBounds) {
    final oldBounds = localBounds;
    final sx = oldBounds.width < 1e-6 ? 1.0 : newBounds.width / oldBounds.width;
    final sy =
        oldBounds.height < 1e-6 ? 1.0 : newBounds.height / oldBounds.height;

    final scaledAnchors = anchors.map((anchor) {
      final normX = oldBounds.width < 1e-6
          ? 0.0
          : (anchor.position.x - oldBounds.minX) / oldBounds.width;
      final normY = oldBounds.height < 1e-6
          ? 0.0
          : (anchor.position.y - oldBounds.minY) / oldBounds.height;

      final newPos = Vec2(
        newBounds.minX + normX * newBounds.width,
        newBounds.minY + normY * newBounds.height,
      );
      final newIn = Vec2(anchor.handleIn.x * sx, anchor.handleIn.y * sy);
      final newOut = Vec2(anchor.handleOut.x * sx, anchor.handleOut.y * sy);

      return anchor.copyWith(
        position: newPos,
        handleIn: newIn,
        handleOut: newOut,
      );
    }).toList();

    return copyWith(anchors: scaledAnchors);
  }

  @override
  PathObject withRotation(double newRotationRadians) =>
      copyWith(rotation: newRotationRadians);

  @override
  PathObject withFill(FillStyle newFill) => copyWith(fill: newFill);

  @override
  PathObject withStroke(StrokeStyle newStroke) => copyWith(stroke: newStroke);

  @override
  PathObject withOpacity(double newOpacity) => copyWith(opacity: newOpacity);

  @override
  PathObject withName(String newName) => copyWith(name: newName);

  @override
  PathObject withVisibility(bool isVisible) => copyWith(visible: isVisible);

  @override
  PathObject withLocked(bool isLocked) => copyWith(locked: isLocked);

  @override
  PathObject withLayerId(String newLayerId) => copyWith(layerId: newLayerId);

  @override
  PathObject duplicateWithNewId({
    required String newId,
    String? newLayerId,
    Vec2 offset = Vec2.zero,
  }) {
    final clonedAnchors = anchors
        .map(
          (a) => a.copyWith(
            id: IdGenerator.anchorId(),
            position: a.position + offset,
          ),
        )
        .toList();
    return copyWith(
      id: newId,
      name: '$name Copy',
      layerId: newLayerId ?? layerId,
      anchors: clonedAnchors,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseFieldsToJson(),
        'closed': closed,
        'anchors': anchors.map((a) => a.toJson()).toList(),
      };

  factory PathObject.fromJson(Map<String, dynamic> json) {
    final rawAnchors = json['anchors'];
    if (rawAnchors is! List || rawAnchors.isEmpty) {
      throw const FormatException('PathObject requires a non-empty anchors list.');
    }
    final parsedAnchors = rawAnchors.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid anchor entry in PathObject.');
      }
      return AnchorPoint.fromJson(item);
    }).toList();

    return PathObject(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Path',
      layerId: (json['layerId'] as String?) ?? '',
      anchors: parsedAnchors,
      closed: json['closed'] is bool ? json['closed'] as bool : false,
      fill: FillStyle.fromJson(
        (json['fill'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      stroke: StrokeStyle.fromJson(
        (json['stroke'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      visible: json['visible'] is bool ? json['visible'] as bool : true,
      locked: json['locked'] is bool ? json['locked'] as bool : false,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
