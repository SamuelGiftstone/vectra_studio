import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/painting.dart';
import 'package:xml/xml.dart';

import '../core/constants/editor_constants.dart';
import '../core/utils/color_utils.dart';
import '../core/utils/id_generator.dart';
import '../editor/object_naming_service.dart';
import '../math/geometry_math.dart';
import '../math/vec2.dart';
import '../models/anchor_point.dart';
import '../models/ellipse_object.dart';
import '../models/fill_style.dart';
import '../models/group_object.dart';
import '../models/line_object.dart';
import '../models/path_object.dart';
import '../models/rectangle_object.dart';
import '../models/stroke_style.dart';
import '../models/text_object.dart';
import '../models/vector_document.dart';
import '../models/vector_object.dart';
import 'storage_exceptions.dart';
import 'svg_path_parser.dart';

/// 2D 3x2 affine matrix `[a, b, c, d, e, f]` representing SVG coordinate transforms.
class _SvgAffine {
  final double a;
  final double b;
  final double c;
  final double d;
  final double e;
  final double f;

  const _SvgAffine(this.a, this.b, this.c, this.d, this.e, this.f);

  static const _SvgAffine identity = _SvgAffine(1, 0, 0, 1, 0, 0);

  bool get isIdentity =>
      (a - 1.0).abs() < 1e-6 &&
      b.abs() < 1e-6 &&
      c.abs() < 1e-6 &&
      (d - 1.0).abs() < 1e-6 &&
      e.abs() < 1e-6 &&
      f.abs() < 1e-6;

  bool get isPureTranslationOrUniformScale =>
      b.abs() < 1e-5 && c.abs() < 1e-5 && a > 0 && d > 0;

  double get scaleFactor {
    final sx = math.sqrt(a * a + b * b);
    final sy = math.sqrt(c * c + d * d);
    return (sx + sy) * 0.5;
  }

  double get rotationRadians => math.atan2(b, a);

  _SvgAffine multiply(_SvgAffine other) {
    return _SvgAffine(
      a * other.a + c * other.b,
      b * other.a + d * other.b,
      a * other.c + c * other.d,
      b * other.c + d * other.d,
      a * other.e + c * other.f + e,
      b * other.e + d * other.f + f,
    );
  }

  Vec2 applyPoint(Vec2 p) => Vec2(
        a * p.x + c * p.y + e,
        b * p.x + d * p.y + f,
      );

  Vec2 applyVector(Vec2 v) => Vec2(
        a * v.x + c * v.y,
        b * v.x + d * v.y,
      );
}

class _SvgInheritedContext {
  final FillStyle fill;
  final StrokeStyle stroke;
  final double opacity;
  final String fontFamily;
  final double fontSize;
  final int fontWeight;
  final bool isItalic;
  final TextAlign textAlign;
  final _SvgAffine transform;

  const _SvgInheritedContext({
    this.fill = const FillStyle(
      color: Color(0xFF000000),
      opacity: 1.0,
      isEnabled: true,
    ),
    this.stroke = StrokeStyle.none,
    this.opacity = 1.0,
    this.fontFamily = EditorConstants.defaultFontFamily,
    this.fontSize = 18.0,
    this.fontWeight = 400,
    this.isItalic = false,
    this.textAlign = TextAlign.left,
    this.transform = _SvgAffine.identity,
  });
}

/// Secure, editable SVG vector importer converting `<svg>`, `<g>`, `<rect>`,
/// `<circle>`, `<ellipse>`, `<line>`, `<polyline>`, `<polygon>`, `<path>`, and `<text>`
/// elements into editable VECTRA [VectorObject]s.
///
/// Security rules:
/// - Rejects external XML entities (`<!ENTITY`) and `<script>` blocks.
/// - Ignores external `http://` / `https://` resource URLs without making network calls.
class SvgImportService {
  const SvgImportService();

  static const Map<String, Color> _namedColors = <String, Color>{
    'black': Color(0xFF000000),
    'white': Color(0xFFFFFFFF),
    'red': Color(0xFFFF0000),
    'green': Color(0xFF008000),
    'lime': Color(0xFF00FF00),
    'blue': Color(0xFF0000FF),
    'yellow': Color(0xFFFFFF00),
    'cyan': Color(0xFF00FFFF),
    'aqua': Color(0xFF00FFFF),
    'magenta': Color(0xFFFF00FF),
    'fuchsia': Color(0xFFFF00FF),
    'gray': Color(0xFF808080),
    'grey': Color(0xFF808080),
    'silver': Color(0xFFC0C0C0),
    'maroon': Color(0xFF800000),
    'olive': Color(0xFF808000),
    'purple': Color(0xFF800080),
    'teal': Color(0xFF008080),
    'navy': Color(0xFF000080),
    'orange': Color(0xFFFFA500),
    'coral': Color(0xFFFF7F50),
    'crimson': Color(0xFFDC143C),
    'gold': Color(0xFFFFD700),
    'indigo': Color(0xFF4B0082),
    'pink': Color(0xFFFFC0CB),
    'violet': Color(0xFFEE82EE),
    'skyblue': Color(0xFF87CEEB),
    'steelblue': Color(0xFF4682B4),
  };

  /// Prompts the user to pick a `.svg` file and imports it as editable vector objects.
  /// Returns `null` if canceled.
  Future<List<VectorObject>?> pickAndImportSvg(
    VectorDocument currentDocument,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Editable SVG Artwork',
      type: FileType.custom,
      allowedExtensions: const <String>[EditorConstants.svgExtension],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final picked = result.files.single;
    if (picked.path != null && picked.path!.isNotEmpty) {
      return importSvgFromFile(picked.path!, currentDocument);
    }
    if (picked.bytes != null && picked.bytes!.isNotEmpty) {
      final text = String.fromCharCodes(picked.bytes!);
      return parseSvgToObjects(text, currentDocument: currentDocument);
    }
    throw const ProjectStorageException(
      'Selected SVG file could not be read from disk.',
    );
  }

  /// Reads and imports an SVG file from [filePath].
  Future<List<VectorObject>> importSvgFromFile(
    String filePath,
    VectorDocument currentDocument,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ProjectStorageException('SVG file does not exist: $filePath');
    }
    final String content;
    try {
      content = await file.readAsString();
    } on IOException catch (e) {
      throw ProjectStorageException('Unable to read SVG file "$filePath": $e', e);
    }
    final baseName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last.replaceAll(RegExp(r'\.svg$', caseSensitive: false), '')
        : 'Imported SVG';
    return parseSvgToObjects(
      content,
      currentDocument: currentDocument,
      sourceName: baseName,
    );
  }

  /// Parses [svgContent] into editable [VectorObject]s ready to insert onto [currentDocument].
  List<VectorObject> parseSvgToObjects(
    String svgContent, {
    required VectorDocument currentDocument,
    String sourceName = 'Imported SVG',
  }) {
    final trimmed = svgContent.trim();
    if (trimmed.isEmpty) {
      throw const ProjectFormatException('The SVG file is empty.');
    }

    // Security check: reject DTD entity expansion & <script> elements
    if (RegExp(r'<!ENTITY\b', caseSensitive: false).hasMatch(trimmed)) {
      throw const ProjectFormatException(
        'Unsafe SVG rejected: XML external entity declarations are not permitted.',
      );
    }

    final XmlDocument xmlDoc;
    try {
      xmlDoc = XmlDocument.parse(trimmed);
    } on XmlException catch (e) {
      throw ProjectFormatException('Malformed SVG XML syntax: ${e.message}', e);
    }

    final root = xmlDoc.rootElement;
    if (root.name.local.toLowerCase() != 'svg') {
      throw ProjectFormatException(
        'Invalid SVG root element "<${root.name.local}>". Expected "<svg>".',
      );
    }

    if (root
        .descendants
        .whereType<XmlElement>()
        .any((el) => el.name.local.toLowerCase() == 'script')) {
      throw const ProjectFormatException(
        'Unsafe SVG rejected: embedded <script> elements are prohibited.',
      );
    }

    final targetLayerId = currentDocument.activeLayer.id;
    final usedNames = <String>{
      for (final obj in currentDocument.allObjectsRecursive) obj.name,
    };

    String allocateName(VectorObjectType type, {String? rawLabel}) {
      if (rawLabel != null && rawLabel.trim().isNotEmpty) {
        final clean = ObjectNamingService.sanitizeName(
          rawLabel,
          fallbackName: type.displayLabel,
        );
        usedNames.add(clean);
        return clean;
      }
      var index = 1;
      while (true) {
        final candidate =
            '${type.displayLabel} ${index.toString().padLeft(2, '0')}';
        if (!usedNames.contains(candidate)) {
          usedNames.add(candidate);
          return candidate;
        }
        index++;
      }
    }

    // Parse root viewBox offset if non-zero
    var rootTransform = _SvgAffine.identity;
    final viewBoxAttr = root.getAttribute('viewBox');
    if (viewBoxAttr != null && viewBoxAttr.trim().isNotEmpty) {
      final nums = _parseNumberList(viewBoxAttr);
      if (nums.length == 4 && (nums[0].abs() > 1e-4 || nums[1].abs() > 1e-4)) {
        rootTransform = _SvgAffine(1, 0, 0, 1, -nums[0], -nums[1]);
      }
    }

    final initialContext = _resolveContext(
      root,
      _SvgInheritedContext(transform: rootTransform),
    );

    final parsedObjects = <VectorObject>[];
    for (final child in root.children.whereType<XmlElement>()) {
      final converted = _convertElement(
        child,
        initialContext,
        targetLayerId: targetLayerId,
        allocateName: allocateName,
      );
      if (converted != null) {
        parsedObjects.add(converted);
      }
    }

    if (parsedObjects.isEmpty) {
      throw const ProjectFormatException(
        'No supported editable vector elements (<path>, <rect>, <circle>, <ellipse>, <line>, <polygon>, <polyline>, <text>) were found in the SVG.',
      );
    }

    // If multiple top-level objects were imported from an external SVG, group them
    // cleanly if > 1 so the imported artwork is immediately movable as a cohesive unit
    // while remaining 100% ungroupable into individual shapes/paths!
    if (parsedObjects.length > 1) {
      final group = GroupObject(
        id: IdGenerator.groupId(),
        name: allocateName(VectorObjectType.group, rawLabel: sourceName),
        layerId: targetLayerId,
        children: parsedObjects,
        expanded: true,
      );
      return <VectorObject>[group];
    }

    return parsedObjects;
  }

  VectorObject? _convertElement(
    XmlElement element,
    _SvgInheritedContext parentCtx, {
    required String targetLayerId,
    required String Function(VectorObjectType type, {String? rawLabel})
        allocateName,
  }) {
    final tag = element.name.local.toLowerCase();

    // Ignore non-rendered definitions/metadata/unsafe containers
    if (tag == 'defs' ||
        tag == 'title' ||
        tag == 'desc' ||
        tag == 'metadata' ||
        tag == 'clippath' ||
        tag == 'mask' ||
        tag == 'lineargradient' ||
        tag == 'radialgradient' ||
        tag == 'style' ||
        tag == 'foreignobject' ||
        tag == 'image') {
      return null;
    }

    final styleMap = _parseInlineStyle(element.getAttribute('style'));
    final display =
        (styleMap['display'] ?? element.getAttribute('display') ?? '').trim();
    if (display.toLowerCase() == 'none') {
      return null;
    }

    final ctx = _resolveContext(element, parentCtx, preParsedStyle: styleMap);
    final rawLabel = element.getAttribute('data-name') ??
        element.getAttribute('inkscape:label') ??
        element.getAttribute('id');

    final visibilityAttr =
        (styleMap['visibility'] ?? element.getAttribute('visibility') ?? '')
            .trim()
            .toLowerCase();
    final isVisible = visibilityAttr != 'hidden' && visibilityAttr != 'collapse';

    switch (tag) {
      case 'g':
      case 'svg':
        final children = <VectorObject>[];
        for (final child in element.children.whereType<XmlElement>()) {
          final parsed = _convertElement(
            child,
            ctx,
            targetLayerId: targetLayerId,
            allocateName: allocateName,
          );
          if (parsed != null) {
            children.add(parsed);
          }
        }
        if (children.isEmpty) return null;
        if (children.length == 1 && rawLabel == null) {
          return children.first;
        }
        return GroupObject(
          id: IdGenerator.groupId(),
          name: allocateName(VectorObjectType.group, rawLabel: rawLabel),
          layerId: targetLayerId,
          children: children,
          visible: isVisible,
        );

      case 'rect':
        final x = _readLength(element.getAttribute('x'));
        final y = _readLength(element.getAttribute('y'));
        final w = _readLength(element.getAttribute('width'));
        final h = _readLength(element.getAttribute('height'));
        if (w <= 0 || h <= 0) return null;
        final rx = _readLength(
          element.getAttribute('rx') ?? element.getAttribute('ry'),
        );

        if (ctx.transform.isPureTranslationOrUniformScale) {
          final p1 = ctx.transform.applyPoint(Vec2(x, y));
          final p2 = ctx.transform.applyPoint(Vec2(x + w, y + h));
          return RectangleObject(
            id: IdGenerator.objectId(),
            name: allocateName(VectorObjectType.rectangle, rawLabel: rawLabel),
            layerId: targetLayerId,
            x: math.min(p1.x, p2.x),
            y: math.min(p1.y, p2.y),
            width: (p2.x - p1.x).abs(),
            height: (p2.y - p1.y).abs(),
            cornerRadius: rx * ctx.transform.scaleFactor,
            fill: ctx.fill,
            stroke: _scaleStroke(ctx.stroke, ctx.transform.scaleFactor),
            opacity: ctx.opacity,
            visible: isVisible,
          );
        }

        // Rotated/skewed rect -> transform corners into an editable PathObject
        final corners = <Vec2>[
          ctx.transform.applyPoint(Vec2(x, y)),
          ctx.transform.applyPoint(Vec2(x + w, y)),
          ctx.transform.applyPoint(Vec2(x + w, y + h)),
          ctx.transform.applyPoint(Vec2(x, y + h)),
        ];
        return PathObject(
          id: IdGenerator.objectId(),
          name: allocateName(VectorObjectType.path, rawLabel: rawLabel),
          layerId: targetLayerId,
          anchors: corners
              .map((pt) => AnchorPoint.corner(id: IdGenerator.anchorId(), position: pt))
              .toList(),
          closed: true,
          fill: ctx.fill,
          stroke: _scaleStroke(ctx.stroke, ctx.transform.scaleFactor),
          opacity: ctx.opacity,
          visible: isVisible,
        );

      case 'circle':
        final cx = _readLength(element.getAttribute('cx'));
        final cy = _readLength(element.getAttribute('cy'));
        final r = _readLength(element.getAttribute('r'));
        if (r <= 0) return null;
        return _buildEllipse(
          cx: cx,
          cy: cy,
          rx: r,
          ry: r,
          ctx: ctx,
          targetLayerId: targetLayerId,
          name: allocateName(VectorObjectType.ellipse, rawLabel: rawLabel),
          isVisible: isVisible,
        );

      case 'ellipse':
        final cx = _readLength(element.getAttribute('cx'));
        final cy = _readLength(element.getAttribute('cy'));
        final rx = _readLength(element.getAttribute('rx'));
        final ry = _readLength(element.getAttribute('ry'));
        if (rx <= 0 || ry <= 0) return null;
        return _buildEllipse(
          cx: cx,
          cy: cy,
          rx: rx,
          ry: ry,
          ctx: ctx,
          targetLayerId: targetLayerId,
          name: allocateName(VectorObjectType.ellipse, rawLabel: rawLabel),
          isVisible: isVisible,
        );

      case 'line':
        final x1 = _readLength(element.getAttribute('x1'));
        final y1 = _readLength(element.getAttribute('y1'));
        final x2 = _readLength(element.getAttribute('x2'));
        final y2 = _readLength(element.getAttribute('y2'));
        final p1 = ctx.transform.applyPoint(Vec2(x1, y1));
        final p2 = ctx.transform.applyPoint(Vec2(x2, y2));
        return LineObject(
          id: IdGenerator.objectId(),
          name: allocateName(VectorObjectType.line, rawLabel: rawLabel),
          layerId: targetLayerId,
          start: p1,
          end: p2,
          fill: FillStyle.none,
          stroke: _scaleStroke(ctx.stroke, ctx.transform.scaleFactor),
          opacity: ctx.opacity,
          visible: isVisible,
        );

      case 'polygon':
      case 'polyline':
        final closed = tag == 'polygon';
        final pts = _parsePointsAttr(element.getAttribute('points') ?? '');
        if (pts.length < 2) return null;
        final anchors = pts
            .map(
              (pt) => AnchorPoint.corner(
                id: IdGenerator.anchorId(),
                position: ctx.transform.applyPoint(pt),
              ),
            )
            .toList();
        return PathObject(
          id: IdGenerator.objectId(),
          name: allocateName(VectorObjectType.path, rawLabel: rawLabel),
          layerId: targetLayerId,
          anchors: anchors,
          closed: closed,
          fill: closed ? ctx.fill : FillStyle.none,
          stroke: _scaleStroke(ctx.stroke, ctx.transform.scaleFactor),
          opacity: ctx.opacity,
          visible: isVisible,
        );

      case 'path':
        final d = element.getAttribute('d') ?? '';
        if (d.trim().isEmpty) return null;
        final subpaths = SvgPathParser.parse(d);
        if (subpaths.isEmpty) return null;

        final pathObjects = <PathObject>[];
        for (final sub in subpaths) {
          if (sub.anchors.length < 2) continue;
          final transformedAnchors = sub.anchors.map((a) {
            return a.copyWith(
              position: ctx.transform.applyPoint(a.position),
              handleIn: ctx.transform.applyVector(a.handleIn),
              handleOut: ctx.transform.applyVector(a.handleOut),
            );
          }).toList();

          pathObjects.add(
            PathObject(
              id: IdGenerator.objectId(),
              name: allocateName(
                VectorObjectType.path,
                rawLabel: pathObjects.isEmpty ? rawLabel : null,
              ),
              layerId: targetLayerId,
              anchors: transformedAnchors,
              closed: sub.closed,
              fill: sub.closed || ctx.fill.isEnabled ? ctx.fill : FillStyle.none,
              stroke: _scaleStroke(ctx.stroke, ctx.transform.scaleFactor),
              opacity: ctx.opacity,
              visible: isVisible,
            ),
          );
        }

        if (pathObjects.isEmpty) return null;
        if (pathObjects.length == 1) return pathObjects.first;
        return GroupObject(
          id: IdGenerator.groupId(),
          name: allocateName(VectorObjectType.group, rawLabel: rawLabel),
          layerId: targetLayerId,
          children: pathObjects,
          visible: isVisible,
        );

      case 'text':
        final extractedText = _extractSvgTextContent(element);
        if (extractedText.trim().isEmpty) return null;

        final attrX = _readLength(
          element.getAttribute('x') ??
              element.findElements('tspan').firstOrNull?.getAttribute('x'),
        );
        final attrY = _readLength(
          element.getAttribute('y') ??
              element.findElements('tspan').firstOrNull?.getAttribute('y'),
        );

        final scaledFontSize =
            (ctx.fontSize * ctx.transform.scaleFactor).clamp(
          EditorConstants.minFontSize,
          EditorConstants.maxFontSize,
        );
        // SVG <text y="..."> specifies the baseline; shift upward by ~0.82 * fontSize for top-left layout
        final topY = attrY - scaledFontSize * 0.82;
        final worldPos = ctx.transform.applyPoint(Vec2(attrX, topY));

        return TextObject(
          id: IdGenerator.objectId(),
          name: allocateName(VectorObjectType.text, rawLabel: rawLabel),
          layerId: targetLayerId,
          text: extractedText,
          x: worldPos.x,
          y: worldPos.y,
          fontFamily: ctx.fontFamily,
          fontSize: scaledFontSize,
          fontWeightValue: ctx.fontWeight,
          isItalic: ctx.isItalic,
          textAlign: ctx.textAlign,
          fill: ctx.fill,
          stroke: _scaleStroke(ctx.stroke, ctx.transform.scaleFactor),
          opacity: ctx.opacity,
          rotation: GeometryMath.normalizeRadians(ctx.transform.rotationRadians),
          visible: isVisible,
        );

      default:
        return null;
    }
  }

  EllipseObject _buildEllipse({
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    required _SvgInheritedContext ctx,
    required String targetLayerId,
    required String name,
    required bool isVisible,
  }) {
    final centerWorld = ctx.transform.applyPoint(Vec2(cx, cy));
    final sx = math.sqrt(ctx.transform.a * ctx.transform.a + ctx.transform.b * ctx.transform.b);
    final sy = math.sqrt(ctx.transform.c * ctx.transform.c + ctx.transform.d * ctx.transform.d);
    final w = math.max(1.0, rx * 2.0 * sx);
    final h = math.max(1.0, ry * 2.0 * sy);

    return EllipseObject(
      id: IdGenerator.objectId(),
      name: name,
      layerId: targetLayerId,
      x: centerWorld.x - w * 0.5,
      y: centerWorld.y - h * 0.5,
      width: w,
      height: h,
      fill: ctx.fill,
      stroke: _scaleStroke(ctx.stroke, ctx.transform.scaleFactor),
      opacity: ctx.opacity,
      rotation: GeometryMath.normalizeRadians(ctx.transform.rotationRadians),
      visible: isVisible,
    );
  }

  StrokeStyle _scaleStroke(StrokeStyle stroke, double scale) {
    if (!stroke.isEnabled) return stroke;
    return stroke.copyWith(width: stroke.width * scale);
  }

  _SvgInheritedContext _resolveContext(
    XmlElement element,
    _SvgInheritedContext parent, {
    Map<String, String>? preParsedStyle,
  }) {
    final style = preParsedStyle ?? _parseInlineStyle(element.getAttribute('style'));

    String? prop(String key) => style[key] ?? element.getAttribute(key);

    // Fill
    var fill = parent.fill;
    final rawFill = prop('fill');
    if (rawFill != null && rawFill.trim().isNotEmpty) {
      if (rawFill.trim().toLowerCase() == 'none' ||
          rawFill.trim().toLowerCase() == 'transparent') {
        fill = fill.copyWith(isEnabled: false);
      } else {
        final parsedColor = _parseSvgColor(rawFill);
        if (parsedColor != null) {
          fill = fill.copyWith(color: parsedColor, isEnabled: true);
        }
      }
    }
    final rawFillOpacity = prop('fill-opacity');
    if (rawFillOpacity != null) {
      final op = double.tryParse(rawFillOpacity.trim());
      if (op != null && op.isFinite) {
        fill = fill.copyWith(opacity: op.clamp(0.0, 1.0));
      }
    }

    // Stroke
    var stroke = parent.stroke;
    final rawStroke = prop('stroke');
    if (rawStroke != null && rawStroke.trim().isNotEmpty) {
      if (rawStroke.trim().toLowerCase() == 'none' ||
          rawStroke.trim().toLowerCase() == 'transparent') {
        stroke = stroke.copyWith(isEnabled: false);
      } else {
        final parsedColor = _parseSvgColor(rawStroke);
        if (parsedColor != null) {
          stroke = stroke.copyWith(color: parsedColor, isEnabled: true);
        }
      }
    }
    final rawStrokeWidth = prop('stroke-width');
    if (rawStrokeWidth != null) {
      final sw = _readLength(rawStrokeWidth, fallback: stroke.width);
      stroke = stroke.copyWith(width: math.max(0.0, sw));
    }
    final rawStrokeOpacity = prop('stroke-opacity');
    if (rawStrokeOpacity != null) {
      final sop = double.tryParse(rawStrokeOpacity.trim());
      if (sop != null && sop.isFinite) {
        stroke = stroke.copyWith(opacity: sop.clamp(0.0, 1.0));
      }
    }
    final rawLineCap = prop('stroke-linecap');
    if (rawLineCap != null) {
      stroke = stroke.copyWith(cap: VectorStrokeCap.fromName(rawLineCap.trim()));
    }
    final rawLineJoin = prop('stroke-linejoin');
    if (rawLineJoin != null) {
      stroke = stroke.copyWith(join: VectorStrokeJoin.fromName(rawLineJoin.trim()));
    }

    // Opacity
    var opacity = parent.opacity;
    final rawOpacity = prop('opacity');
    if (rawOpacity != null) {
      final op = double.tryParse(rawOpacity.trim());
      if (op != null && op.isFinite) {
        opacity = (opacity * op.clamp(0.0, 1.0)).clamp(0.0, 1.0);
      }
    }

    // Typography
    var fontFamily = parent.fontFamily;
    final rawFontFamily = prop('font-family');
    if (rawFontFamily != null && rawFontFamily.trim().isNotEmpty) {
      fontFamily = rawFontFamily
          .split(',')
          .first
          .replaceAll('"', '')
          .replaceAll("'", '')
          .trim();
    }

    var fontSize = parent.fontSize;
    final rawFontSize = prop('font-size');
    if (rawFontSize != null) {
      fontSize = _readLength(rawFontSize, fallback: fontSize).clamp(4.0, 1000.0);
    }

    var fontWeight = parent.fontWeight;
    final rawWeight = prop('font-weight')?.trim().toLowerCase();
    if (rawWeight != null && rawWeight.isNotEmpty) {
      if (rawWeight == 'bold' || rawWeight == 'bolder') {
        fontWeight = 700;
      } else if (rawWeight == 'normal' || rawWeight == 'regular') {
        fontWeight = 400;
      } else if (rawWeight == 'light' || rawWeight == 'lighter') {
        fontWeight = 300;
      } else {
        final parsedW = int.tryParse(rawWeight);
        if (parsedW != null) fontWeight = parsedW.clamp(100, 900);
      }
    }

    var isItalic = parent.isItalic;
    final rawFontStyle = prop('font-style')?.trim().toLowerCase();
    if (rawFontStyle != null) {
      isItalic = rawFontStyle == 'italic' || rawFontStyle == 'oblique';
    }

    var textAlign = parent.textAlign;
    final rawAnchor = prop('text-anchor')?.trim().toLowerCase();
    if (rawAnchor == 'middle') {
      textAlign = TextAlign.center;
    } else if (rawAnchor == 'end') {
      textAlign = TextAlign.right;
    } else if (rawAnchor == 'start') {
      textAlign = TextAlign.left;
    }

    // Transform
    var transform = parent.transform;
    final rawTransform = element.getAttribute('transform');
    if (rawTransform != null && rawTransform.trim().isNotEmpty) {
      transform = transform.multiply(_parseTransformList(rawTransform));
    }

    return _SvgInheritedContext(
      fill: fill,
      stroke: stroke,
      opacity: opacity,
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      isItalic: isItalic,
      textAlign: textAlign,
      transform: transform,
    );
  }

  String _extractSvgTextContent(XmlElement textElement) {
    final tspans = textElement.findElements('tspan').toList();
    if (tspans.isNotEmpty) {
      final lines = <String>[];
      for (final span in tspans) {
        lines.add(span.innerText);
      }
      return lines.join('\n');
    }
    return textElement.innerText.trim();
  }

  Map<String, String> _parseInlineStyle(String? styleAttr) {
    if (styleAttr == null || styleAttr.trim().isEmpty) {
      return const <String, String>{};
    }
    final map = <String, String>{};
    for (final declaration in styleAttr.split(';')) {
      final colon = declaration.indexOf(':');
      if (colon <= 0) continue;
      final k = declaration.substring(0, colon).trim().toLowerCase();
      final v = declaration.substring(colon + 1).trim();
      if (k.isNotEmpty && v.isNotEmpty) {
        map[k] = v;
      }
    }
    return map;
  }

  Color? _parseSvgColor(String raw) {
    final cleaned = raw.trim().toLowerCase();
    if (cleaned.isEmpty ||
        cleaned == 'none' ||
        cleaned.startsWith('url(')) {
      return null;
    }
    final named = _namedColors[cleaned];
    if (named != null) return named;

    if (cleaned.startsWith('#')) {
      return ColorUtils.tryParseHex(cleaned);
    }

    final rgbMatch = RegExp(
      r'^rgba?\(\s*([0-9.]+%?)\s*[,\s]\s*([0-9.]+%?)\s*[,\s]\s*([0-9.]+%?)(?:\s*[,/]\s*([0-9.]+%?))?\s*\)$',
    ).firstMatch(cleaned);
    if (rgbMatch != null) {
      int parseChannel(String s) {
        if (s.endsWith('%')) {
          final pct = double.tryParse(s.substring(0, s.length - 1)) ?? 0.0;
          return ((pct / 100.0) * 255.0).round().clamp(0, 255);
        }
        return (double.tryParse(s) ?? 0.0).round().clamp(0, 255);
      }

      final r = parseChannel(rgbMatch.group(1)!);
      final g = parseChannel(rgbMatch.group(2)!);
      final b = parseChannel(rgbMatch.group(3)!);
      var a = 255;
      final alphaGroup = rgbMatch.group(4);
      if (alphaGroup != null) {
        if (alphaGroup.endsWith('%')) {
          final pct =
              double.tryParse(alphaGroup.substring(0, alphaGroup.length - 1)) ??
                  100.0;
          a = ((pct / 100.0) * 255.0).round().clamp(0, 255);
        } else {
          final af = double.tryParse(alphaGroup) ?? 1.0;
          a = (af.clamp(0.0, 1.0) * 255.0).round();
        }
      }
      return Color.fromARGB(a, r, g, b);
    }

    return null;
  }

  double _readLength(String? raw, {double fallback = 0.0}) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    var s = raw.trim().toLowerCase();
    var multiplier = 1.0;
    if (s.endsWith('px')) {
      s = s.substring(0, s.length - 2);
    } else if (s.endsWith('pt')) {
      s = s.substring(0, s.length - 2);
      multiplier = 96.0 / 72.0;
    } else if (s.endsWith('pc')) {
      s = s.substring(0, s.length - 2);
      multiplier = 16.0;
    } else if (s.endsWith('mm')) {
      s = s.substring(0, s.length - 2);
      multiplier = 96.0 / 25.4;
    } else if (s.endsWith('cm')) {
      s = s.substring(0, s.length - 2);
      multiplier = 96.0 / 2.54;
    } else if (s.endsWith('in')) {
      s = s.substring(0, s.length - 2);
      multiplier = 96.0;
    }
    final val = double.tryParse(s.trim());
    if (val == null || !val.isFinite) return fallback;
    return val * multiplier;
  }

  List<double> _parseNumberList(String raw) {
    final matches = RegExp(r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?')
        .allMatches(raw);
    final out = <double>[];
    for (final m in matches) {
      final v = double.tryParse(m.group(0)!);
      if (v != null && v.isFinite) out.add(v);
    }
    return out;
  }

  List<Vec2> _parsePointsAttr(String raw) {
    final nums = _parseNumberList(raw);
    final pts = <Vec2>[];
    for (var i = 0; i + 1 < nums.length; i += 2) {
      pts.add(Vec2(nums[i], nums[i + 1]));
    }
    return pts;
  }

  _SvgAffine _parseTransformList(String raw) {
    final fnRegex = RegExp(r'([a-zA-Z]+)\s*\(([^)]*)\)');
    var acc = _SvgAffine.identity;

    for (final match in fnRegex.allMatches(raw)) {
      final fn = match.group(1)!.toLowerCase();
      final args = _parseNumberList(match.group(2)!);
      switch (fn) {
        case 'translate':
          if (args.isNotEmpty) {
            final tx = args[0];
            final ty = args.length >= 2 ? args[1] : 0.0;
            acc = acc.multiply(_SvgAffine(1, 0, 0, 1, tx, ty));
          }
          break;
        case 'scale':
          if (args.isNotEmpty) {
            final sx = args[0];
            final sy = args.length >= 2 ? args[1] : sx;
            acc = acc.multiply(_SvgAffine(sx, 0, 0, sy, 0, 0));
          }
          break;
        case 'rotate':
          if (args.isNotEmpty) {
            final rad = args[0] * math.pi / 180.0;
            final cosA = math.cos(rad);
            final sinA = math.sin(rad);
            if (args.length >= 3) {
              final cx = args[1];
              final cy = args[2];
              acc = acc
                  .multiply(_SvgAffine(1, 0, 0, 1, cx, cy))
                  .multiply(_SvgAffine(cosA, sinA, -sinA, cosA, 0, 0))
                  .multiply(_SvgAffine(1, 0, 0, 1, -cx, -cy));
            } else {
              acc = acc.multiply(_SvgAffine(cosA, sinA, -sinA, cosA, 0, 0));
            }
          }
          break;
        case 'matrix':
          if (args.length >= 6) {
            acc = acc.multiply(
              _SvgAffine(args[0], args[1], args[2], args[3], args[4], args[5]),
            );
          }
          break;
      }
    }

    return acc;
  }
}
