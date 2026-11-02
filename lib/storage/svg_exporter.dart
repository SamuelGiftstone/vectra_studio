import 'package:flutter/painting.dart';

import '../core/utils/color_utils.dart';
import '../core/utils/validation_utils.dart';
import '../math/geometry_math.dart';
import '../math/vec2.dart';
import '../models/ellipse_object.dart';
import '../models/group_object.dart';
import '../models/image_object.dart';
import '../models/line_object.dart';
import '../models/path_object.dart';
import '../models/polygon_object.dart';
import '../models/rectangle_object.dart';
import '../models/star_object.dart';
import '../models/text_object.dart';
import '../models/vector_document.dart';
import '../models/vector_layer.dart';
import '../models/vector_object.dart';
import '../rendering/text_layout_service.dart';

/// Exports an editable [VectorDocument] into clean, standards-compliant SVG 1.1 markup.
///
/// Supports primitive shapes, cubic Bézier `<path>` objects, `<text>` / `<tspan>`
/// typography (both point text and word-wrapped frame text), recursive `<g>` groups,
/// and embedded data-URI `<image>` elements.
///
/// Hidden layers, hidden objects, and editor-only UI overlays (tags, handles, grid)
/// are strictly excluded.
class SvgExporter {
  const SvgExporter();

  String export(
    VectorDocument document, {
    bool includeBackground = true,
    double scale = 1.0,
  }) {
    final safeScale = scale.clamp(0.1, 16.0);
    final viewW = ValidationUtils.formatCompact(document.width);
    final viewH = ValidationUtils.formatCompact(document.height);
    final outW = ValidationUtils.formatCompact(document.width * safeScale);
    final outH = ValidationUtils.formatCompact(document.height * safeScale);
    final escapedTitle = ValidationUtils.escapeXml(document.name);

    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" width="$outW" height="$outH" viewBox="0 0 $viewW $viewH">',
      )
      ..writeln('  <title>$escapedTitle</title>');

    if (includeBackground && document.backgroundColor.alpha > 0) {
      final bgHex = ColorUtils.toSvgHex(document.backgroundColor);
      final bgAlpha = document.backgroundColor.alpha / 255.0;
      final opacityAttr = bgAlpha < 0.999
          ? ' fill-opacity="${ValidationUtils.formatCompact(bgAlpha, decimals: 3)}"'
          : '';
      buffer.writeln(
        '  <rect width="$viewW" height="$viewH" fill="$bgHex"$opacityAttr />',
      );
    }

    for (final layer in document.layers) {
      if (!layer.visible) continue;
      _writeLayer(buffer, document, layer);
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  void _writeLayer(
    StringBuffer buffer,
    VectorDocument document,
    VectorLayer layer,
  ) {
    final visibleObjects = layer.objects.where((o) => o.visible).toList();
    if (visibleObjects.isEmpty) return;

    final layerId = ValidationUtils.escapeXml(layer.id);
    final layerName = ValidationUtils.escapeXml(layer.name);
    buffer.writeln('  <g id="$layerId" data-layer-name="$layerName">');
    for (final obj in visibleObjects) {
      _writeObject(buffer, document, obj, indent: '    ');
    }
    buffer.writeln('  </g>');
  }

  void _writeObject(
    StringBuffer buffer,
    VectorDocument document,
    VectorObject obj, {
    required String indent,
  }) {
    if (!obj.visible) return;

    final idAttr = 'id="${ValidationUtils.escapeXml(obj.id)}"';
    final nameAttr = 'data-name="${ValidationUtils.escapeXml(obj.name)}"';

    if (obj is GroupObject) {
      final visibleChildren = obj.children.where((c) => c.visible).toList();
      if (visibleChildren.isEmpty) return;
      final groupAttrs = StringBuffer();
      if (obj.opacity < 0.999) {
        groupAttrs.write(
          ' opacity="${ValidationUtils.formatCompact(obj.opacity, decimals: 3)}"',
        );
      }
      if (obj.rotation.abs() > 1e-6) {
        final deg = _num(GeometryMath.radiansToDegrees(obj.rotation));
        final c = obj.center;
        groupAttrs.write(' transform="rotate($deg ${_num(c.x)} ${_num(c.y)})"');
      }
      buffer.writeln('$indent<g $idAttr $nameAttr$groupAttrs>');
      for (final child in visibleChildren) {
        _writeObject(buffer, document, child, indent: '$indent  ');
      }
      buffer.writeln('$indent</g>');
      return;
    }

    if (obj is TextObject) {
      _writeTextObject(buffer, obj, idAttr: idAttr, nameAttr: nameAttr, indent: indent);
      return;
    }

    if (obj is ImageObject) {
      _writeImageObject(
        buffer,
        document,
        obj,
        idAttr: idAttr,
        nameAttr: nameAttr,
        indent: indent,
      );
      return;
    }

    final commonAttrs = _buildPaintAndTransformAttributes(obj);

    if (obj is RectangleObject) {
      final x = _num(obj.x);
      final y = _num(obj.y);
      final w = _num(obj.width);
      final h = _num(obj.height);
      final r = obj.effectiveCornerRadius;
      final radiusAttr = r > 1e-4 ? ' rx="${_num(r)}" ry="${_num(r)}"' : '';
      buffer.writeln(
        '$indent<rect $idAttr $nameAttr x="$x" y="$y" width="$w" height="$h"$radiusAttr$commonAttrs />',
      );
      return;
    }

    if (obj is EllipseObject) {
      final center = obj.localBounds.center;
      final cx = _num(center.x);
      final cy = _num(center.y);
      final rx = _num(obj.rx);
      final ry = _num(obj.ry);
      buffer.writeln(
        '$indent<ellipse $idAttr $nameAttr cx="$cx" cy="$cy" rx="$rx" ry="$ry"$commonAttrs />',
      );
      return;
    }

    if (obj is LineObject) {
      final x1 = _num(obj.start.x);
      final y1 = _num(obj.start.y);
      final x2 = _num(obj.end.x);
      final y2 = _num(obj.end.y);
      final lineAttrs =
          _buildPaintAndTransformAttributes(obj, forceNoFill: true);
      buffer.writeln(
        '$indent<line $idAttr $nameAttr x1="$x1" y1="$y1" x2="$x2" y2="$y2"$lineAttrs />',
      );
      return;
    }

    if (obj is PolygonObject) {
      final pointsStr = _formatVertices(obj.localVertices);
      buffer.writeln(
        '$indent<polygon $idAttr $nameAttr points="$pointsStr"$commonAttrs />',
      );
      return;
    }

    if (obj is StarObject) {
      final pointsStr = _formatVertices(obj.localVertices);
      buffer.writeln(
        '$indent<polygon $idAttr $nameAttr points="$pointsStr"$commonAttrs />',
      );
      return;
    }

    if (obj is PathObject) {
      if (obj.anchors.isEmpty) return;
      final d = buildSvgPathData(obj);
      final pathAttrs = _buildPaintAndTransformAttributes(
        obj,
        forceNoFill: !obj.closed && !obj.fill.isEnabled,
      );
      buffer.writeln('$indent<path $idAttr $nameAttr d="$d"$pathAttrs />');
    }
  }

  void _writeTextObject(
    StringBuffer buffer,
    TextObject obj, {
    required String idAttr,
    required String nameAttr,
    required String indent,
  }) {
    if (obj.text.isEmpty) return;

    final bounds = obj.localBounds;
    final anchorX = TextLayoutService.alignedLineAnchorX(
      left: obj.x,
      width: bounds.width,
      align: obj.textAlign,
    );
    final svgAnchor = _svgTextAnchor(obj.textAlign);
    final fontFamilyEscaped = ValidationUtils.escapeXml(obj.fontFamily);
    final fontStyle = obj.isItalic ? ' font-style="italic"' : '';
    final letterSpacingAttr = obj.letterSpacing.abs() > 1e-4
        ? ' letter-spacing="${_num(obj.letterSpacing)}"'
        : '';
    final paintAttrs = _buildPaintAndTransformAttributes(obj);

    // Extract visual lines (wrapping inside frameWidth when Area Text is used)
    final visualLines = _extractVisualLines(obj);
    final lineAdvance = obj.fontSize * obj.lineHeight;
    final firstBaselineY = obj.y + obj.fontSize * 0.85;

    buffer.writeln(
      '$indent<text $idAttr $nameAttr x="${_num(anchorX)}" y="${_num(firstBaselineY)}" '
      'font-family="$fontFamilyEscaped" font-size="${_num(obj.fontSize)}" '
      'font-weight="${obj.fontWeightValue}"$fontStyle '
      'text-anchor="$svgAnchor"$letterSpacingAttr xml:space="preserve"$paintAttrs>',
    );

    for (var i = 0; i < visualLines.length; i++) {
      final lineY = firstBaselineY + i * lineAdvance;
      final escapedLine = ValidationUtils.escapeXml(visualLines[i]);
      buffer.writeln(
        '$indent  <tspan x="${_num(anchorX)}" y="${_num(lineY)}">$escapedLine</tspan>',
      );
    }

    buffer.writeln('$indent</text>');
  }

  List<String> _extractVisualLines(TextObject obj) {
    if (!obj.isAreaText || obj.frameWidth == null) {
      return obj.text.split('\n');
    }

    // Use TextPainter line boundary ranges so Area Text wraps identically in SVG
    final painter = TextLayoutService.buildLaidOutPainter(
      text: obj.text,
      fontFamily: obj.fontFamily,
      fontSize: obj.fontSize,
      fontWeightValue: obj.fontWeightValue,
      isItalic: obj.isItalic,
      textAlign: obj.textAlign,
      lineHeight: obj.lineHeight,
      letterSpacing: obj.letterSpacing,
      color: const Color(0xFFFFFFFF),
      frameWidth: obj.frameWidth,
    );

    final lines = <String>[];
    var offset = 0;
    final textLen = obj.text.length;
    while (offset <= textLen) {
      final range = painter.getLineBoundary(TextPosition(offset: offset));
      if (range.end <= offset) {
        if (offset < textLen) {
          lines.add(obj.text.substring(offset));
        }
        break;
      }
      final endClamp = range.end.clamp(0, textLen);
      var slice = obj.text.substring(range.start.clamp(0, textLen), endClamp);
      if (slice.endsWith('\n')) {
        slice = slice.substring(0, slice.length - 1);
      }
      lines.add(slice);
      offset = endClamp;
      if (offset < textLen && obj.text.codeUnitAt(offset) == 10) {
        offset++;
      }
      if (offset >= textLen) break;
    }

    painter.dispose();
    return lines.isEmpty ? obj.text.split('\n') : lines;
  }

  void _writeImageObject(
    StringBuffer buffer,
    VectorDocument document,
    ImageObject obj, {
    required String idAttr,
    required String nameAttr,
    required String indent,
  }) {
    final asset = document.findAssetById(obj.assetId);
    if (asset == null) return;

    final dataUri = asset.toDataUri();
    final x = _num(obj.x);
    final y = _num(obj.y);
    final w = _num(obj.width);
    final h = _num(obj.height);

    final extraAttrs = StringBuffer();
    if (obj.opacity < 0.999) {
      extraAttrs.write(
        ' opacity="${ValidationUtils.formatCompact(obj.opacity, decimals: 3)}"',
      );
    }
    if (obj.rotation.abs() > 1e-6) {
      final deg = _num(GeometryMath.radiansToDegrees(obj.rotation));
      final c = obj.center;
      extraAttrs.write(' transform="rotate($deg ${_num(c.x)} ${_num(c.y)})"');
    }

    buffer.writeln(
      '$indent<image $idAttr $nameAttr x="$x" y="$y" width="$w" height="$h" '
      'preserveAspectRatio="none" href="$dataUri"$extraAttrs />',
    );
  }

  String _svgTextAnchor(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return 'middle';
      case TextAlign.right:
      case TextAlign.end:
        return 'end';
      case TextAlign.left:
      case TextAlign.start:
      case TextAlign.justify:
        return 'start';
    }
  }

  /// Generates SVG `<path d="...">` command data including cubic Bézier `C` commands.
  String buildSvgPathData(PathObject path) {
    if (path.anchors.isEmpty) return '';
    final parts = <String>[];
    final first = path.anchors.first;
    parts.add('M ${_num(first.position.x)} ${_num(first.position.y)}');

    for (final seg in path.segments) {
      if (seg.isLinear) {
        parts.add('L ${_num(seg.p3.x)} ${_num(seg.p3.y)}');
      } else {
        parts.add(
          'C ${_num(seg.p1.x)} ${_num(seg.p1.y)}, '
          '${_num(seg.p2.x)} ${_num(seg.p2.y)}, '
          '${_num(seg.p3.x)} ${_num(seg.p3.y)}',
        );
      }
    }

    if (path.closed && path.anchors.length >= 2) {
      parts.add('Z');
    }
    return parts.join(' ');
  }

  String _formatVertices(List<Vec2> vertices) {
    return vertices.map((v) => '${_num(v.x)},${_num(v.y)}').join(' ');
  }

  String _buildPaintAndTransformAttributes(
    VectorObject obj, {
    bool forceNoFill = false,
  }) {
    final sb = StringBuffer();

    if (forceNoFill || !obj.fill.isEnabled || obj.fill.opacity <= 0.0) {
      sb.write(' fill="none"');
    } else {
      final fillHex = ColorUtils.toSvgHex(obj.fill.color);
      sb.write(' fill="$fillHex"');
      final effectiveFillAlpha =
          (obj.fill.color.alpha / 255.0) * obj.fill.opacity;
      if (effectiveFillAlpha < 0.999) {
        sb.write(
          ' fill-opacity="${ValidationUtils.formatCompact(effectiveFillAlpha, decimals: 3)}"',
        );
      }
    }

    if (!obj.stroke.isVisible) {
      sb.write(' stroke="none"');
    } else {
      final strokeHex = ColorUtils.toSvgHex(obj.stroke.color);
      sb.write(' stroke="$strokeHex"');
      sb.write(' stroke-width="${_num(obj.stroke.width)}"');
      sb.write(' stroke-linecap="${obj.stroke.cap.toSvgValue()}"');
      sb.write(' stroke-linejoin="${obj.stroke.join.toSvgValue()}"');
      final effectiveStrokeAlpha =
          (obj.stroke.color.alpha / 255.0) * obj.stroke.opacity;
      if (effectiveStrokeAlpha < 0.999) {
        sb.write(
          ' stroke-opacity="${ValidationUtils.formatCompact(effectiveStrokeAlpha, decimals: 3)}"',
        );
      }
    }

    if (obj.opacity < 0.999) {
      sb.write(
        ' opacity="${ValidationUtils.formatCompact(obj.opacity, decimals: 3)}"',
      );
    }

    if (obj.rotation.abs() > 1e-6) {
      final deg = _num(GeometryMath.radiansToDegrees(obj.rotation));
      final c = obj.center;
      sb.write(' transform="rotate($deg ${_num(c.x)} ${_num(c.y)})"');
    }

    return sb.toString();
  }

  String _num(double value) => ValidationUtils.formatCompact(value, decimals: 2);
}
