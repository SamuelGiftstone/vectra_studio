import 'dart:math' as math;

import '../core/utils/id_generator.dart';
import '../math/vec2.dart';
import '../models/anchor_point.dart';

/// Parsed subpath produced by [SvgPathParser] from an SVG `<path d="...">` string.
class ParsedSvgSubpath {
  final List<AnchorPoint> anchors;
  final bool closed;

  const ParsedSvgSubpath({
    required this.anchors,
    required this.closed,
  });
}

/// Complete W3C SVG 1.1 `<path d="...">` command parser converting `M/m`, `L/l`,
/// `H/h`, `V/v`, `C/c`, `S/s`, `Q/q`, `T/t`, `A/a`, and `Z/z` commands into
/// node-editable cubic Bézier [AnchorPoint] subpaths.
class SvgPathParser {
  SvgPathParser._();

  static final RegExp _tokenRegex = RegExp(
    r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?',
  );

  /// Parses an SVG path data string `d` into one or more [ParsedSvgSubpath]s.
  static List<ParsedSvgSubpath> parse(String pathData) {
    final trimmed = pathData.trim();
    if (trimmed.isEmpty) return const <ParsedSvgSubpath>[];

    final tokens = _tokenRegex
        .allMatches(trimmed)
        .map((m) => m.group(0)!)
        .toList();
    if (tokens.isEmpty) return const <ParsedSvgSubpath>[];

    final subpaths = <ParsedSvgSubpath>[];
    var currentAnchors = <AnchorPoint>[];

    var cursor = Vec2.zero;
    var subpathStart = Vec2.zero;
    Vec2? lastCubicControl;
    Vec2? lastQuadControl;
    String? prevCmd;

    var idx = 0;

    bool hasMoreNumbers() {
      if (idx >= tokens.length) return false;
      final t = tokens[idx];
      return !_isCommandLetter(t);
    }

    double nextNumber() {
      if (idx >= tokens.length) {
        throw const FormatException('Unexpected end of SVG path numbers.');
      }
      final val = double.tryParse(tokens[idx]);
      if (val == null || !val.isFinite) {
        throw FormatException('Invalid number "${tokens[idx]}" in SVG path.');
      }
      idx++;
      return val;
    }

    int nextArcFlag() {
      if (idx >= tokens.length) {
        throw const FormatException('Unexpected end of SVG arc flags.');
      }
      final tok = tokens[idx];
      // Support compact SVG arc flags like "01" or "10" if attached, though regex splits numbers
      if (tok == '0' || tok == '1') {
        idx++;
        return tok == '1' ? 1 : 0;
      }
      if (tok.length > 1 && (tok.startsWith('0') || tok.startsWith('1'))) {
        final flag = tok[0] == '1' ? 1 : 0;
        tokens[idx] = tok.substring(1);
        return flag;
      }
      final numVal = nextNumber();
      return numVal != 0.0 ? 1 : 0;
    }

    void flushSubpath({required bool closed}) {
      if (currentAnchors.isEmpty) return;

      // If closed and last anchor coincides with first anchor, merge incoming handle onto first
      if (closed && currentAnchors.length >= 2) {
        final first = currentAnchors.first;
        final last = currentAnchors.last;
        if (first.position.distanceTo(last.position) <= 1e-3) {
          currentAnchors[0] = first.copyWith(
            handleIn: last.handleIn,
            nodeType: NodeType.corner,
          );
          currentAnchors.removeLast();
        }
      }

      if (currentAnchors.isNotEmpty) {
        subpaths.add(
          ParsedSvgSubpath(
            anchors: List<AnchorPoint>.unmodifiable(currentAnchors),
            closed: closed,
          ),
        );
      }
      currentAnchors = <AnchorPoint>[];
    }

    void appendLineTo(Vec2 target) {
      if (currentAnchors.isEmpty) {
        currentAnchors.add(
          AnchorPoint.corner(id: IdGenerator.anchorId(), position: cursor),
        );
      }
      currentAnchors.add(
        AnchorPoint.corner(id: IdGenerator.anchorId(), position: target),
      );
      cursor = target;
    }

    void appendCubicTo(Vec2 cp1, Vec2 cp2, Vec2 endPt) {
      if (currentAnchors.isEmpty) {
        currentAnchors.add(
          AnchorPoint.corner(id: IdGenerator.anchorId(), position: cursor),
        );
      }
      final prevIndex = currentAnchors.length - 1;
      final prevAnchor = currentAnchors[prevIndex];
      final outOffset = cp1 - prevAnchor.position;
      currentAnchors[prevIndex] = prevAnchor.copyWith(
        handleOut: outOffset,
        nodeType: NodeType.corner,
      );

      final inOffset = cp2 - endPt;
      currentAnchors.add(
        AnchorPoint(
          id: IdGenerator.anchorId(),
          position: endPt,
          handleIn: inOffset,
          handleOut: Vec2.zero,
          nodeType: NodeType.corner,
        ),
      );
      cursor = endPt;
    }

    while (idx < tokens.length) {
      final String cmd;
      if (_isCommandLetter(tokens[idx])) {
        cmd = tokens[idx];
        idx++;
      } else if (prevCmd != null) {
        cmd = prevCmd;
      } else {
        break;
      }

      switch (cmd) {
        case 'M':
        case 'm':
          flushSubpath(closed: false);
          final isRel = cmd == 'm';
          final x = nextNumber();
          final y = nextNumber();
          cursor = isRel ? cursor + Vec2(x, y) : Vec2(x, y);
          subpathStart = cursor;
          currentAnchors.add(
            AnchorPoint.corner(id: IdGenerator.anchorId(), position: cursor),
          );
          lastCubicControl = null;
          lastQuadControl = null;

          // Subsequent coordinate pairs after M/m are treated as L/l
          while (hasMoreNumbers()) {
            final lx = nextNumber();
            final ly = nextNumber();
            final target = isRel ? cursor + Vec2(lx, ly) : Vec2(lx, ly);
            appendLineTo(target);
          }
          prevCmd = isRel ? 'l' : 'L';
          break;

        case 'L':
        case 'l':
          final isRel = cmd == 'l';
          do {
            final x = nextNumber();
            final y = nextNumber();
            final target = isRel ? cursor + Vec2(x, y) : Vec2(x, y);
            appendLineTo(target);
          } while (hasMoreNumbers());
          lastCubicControl = null;
          lastQuadControl = null;
          prevCmd = cmd;
          break;

        case 'H':
        case 'h':
          final isRel = cmd == 'h';
          do {
            final x = nextNumber();
            final target = Vec2(isRel ? cursor.x + x : x, cursor.y);
            appendLineTo(target);
          } while (hasMoreNumbers());
          lastCubicControl = null;
          lastQuadControl = null;
          prevCmd = cmd;
          break;

        case 'V':
        case 'v':
          final isRel = cmd == 'v';
          do {
            final y = nextNumber();
            final target = Vec2(cursor.x, isRel ? cursor.y + y : y);
            appendLineTo(target);
          } while (hasMoreNumbers());
          lastCubicControl = null;
          lastQuadControl = null;
          prevCmd = cmd;
          break;

        case 'C':
        case 'c':
          final isRel = cmd == 'c';
          do {
            final x1 = nextNumber();
            final y1 = nextNumber();
            final x2 = nextNumber();
            final y2 = nextNumber();
            final x = nextNumber();
            final y = nextNumber();
            final cp1 = isRel ? cursor + Vec2(x1, y1) : Vec2(x1, y1);
            final cp2 = isRel ? cursor + Vec2(x2, y2) : Vec2(x2, y2);
            final endPt = isRel ? cursor + Vec2(x, y) : Vec2(x, y);
            appendCubicTo(cp1, cp2, endPt);
            lastCubicControl = cp2;
            lastQuadControl = null;
          } while (hasMoreNumbers());
          prevCmd = cmd;
          break;

        case 'S':
        case 's':
          final isRel = cmd == 's';
          do {
            final x2 = nextNumber();
            final y2 = nextNumber();
            final x = nextNumber();
            final y = nextNumber();
            final cp1 = (prevCmd == 'C' ||
                    prevCmd == 'c' ||
                    prevCmd == 'S' ||
                    prevCmd == 's') &&
                lastCubicControl != null
                ? cursor * 2.0 - lastCubicControl!
                : cursor;
            final cp2 = isRel ? cursor + Vec2(x2, y2) : Vec2(x2, y2);
            final endPt = isRel ? cursor + Vec2(x, y) : Vec2(x, y);
            appendCubicTo(cp1, cp2, endPt);
            lastCubicControl = cp2;
            lastQuadControl = null;
            prevCmd = cmd;
          } while (hasMoreNumbers());
          break;

        case 'Q':
        case 'q':
          final isRel = cmd == 'q';
          do {
            final qx = nextNumber();
            final qy = nextNumber();
            final x = nextNumber();
            final y = nextNumber();
            final qCtrl = isRel ? cursor + Vec2(qx, qy) : Vec2(qx, qy);
            final endPt = isRel ? cursor + Vec2(x, y) : Vec2(x, y);
            // Degree elevation from quadratic to exact cubic Bézier
            final cp1 = cursor + (qCtrl - cursor) * (2.0 / 3.0);
            final cp2 = endPt + (qCtrl - endPt) * (2.0 / 3.0);
            appendCubicTo(cp1, cp2, endPt);
            lastQuadControl = qCtrl;
            lastCubicControl = null;
          } while (hasMoreNumbers());
          prevCmd = cmd;
          break;

        case 'T':
        case 't':
          final isRel = cmd == 't';
          do {
            final x = nextNumber();
            final y = nextNumber();
            final qCtrl = (prevCmd == 'Q' ||
                    prevCmd == 'q' ||
                    prevCmd == 'T' ||
                    prevCmd == 't') &&
                lastQuadControl != null
                ? cursor * 2.0 - lastQuadControl!
                : cursor;
            final endPt = isRel ? cursor + Vec2(x, y) : Vec2(x, y);
            final cp1 = cursor + (qCtrl - cursor) * (2.0 / 3.0);
            final cp2 = endPt + (qCtrl - endPt) * (2.0 / 3.0);
            appendCubicTo(cp1, cp2, endPt);
            lastQuadControl = qCtrl;
            lastCubicControl = null;
            prevCmd = cmd;
          } while (hasMoreNumbers());
          break;

        case 'A':
        case 'a':
          final isRel = cmd == 'a';
          do {
            final rx = nextNumber();
            final ry = nextNumber();
            final xAxisRotDeg = nextNumber();
            final largeArc = nextArcFlag() == 1;
            final sweep = nextArcFlag() == 1;
            final x = nextNumber();
            final y = nextNumber();
            final endPt = isRel ? cursor + Vec2(x, y) : Vec2(x, y);

            final cubics = _arcToCubicSegments(
              start: cursor,
              end: endPt,
              rxInput: rx,
              ryInput: ry,
              xAxisRotationDeg: xAxisRotDeg,
              largeArcFlag: largeArc,
              sweepFlag: sweep,
            );
            if (cubics.isEmpty) {
              appendLineTo(endPt);
            } else {
              for (final seg in cubics) {
                appendCubicTo(seg.cp1, seg.cp2, seg.end);
              }
            }
            lastCubicControl = null;
            lastQuadControl = null;
          } while (hasMoreNumbers());
          prevCmd = cmd;
          break;

        case 'Z':
        case 'z':
          cursor = subpathStart;
          flushSubpath(closed: true);
          lastCubicControl = null;
          lastQuadControl = null;
          prevCmd = cmd;
          break;
      }
    }

    flushSubpath(closed: false);
    return subpaths;
  }

  static bool _isCommandLetter(String token) {
    if (token.length != 1) return false;
    final code = token.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  /// Converts an SVG elliptical arc (W3C SVG 1.1 Appendix F.6.5/F.6.6) into
  /// high-accuracy cubic Bézier segments.
  static List<({Vec2 cp1, Vec2 cp2, Vec2 end})> _arcToCubicSegments({
    required Vec2 start,
    required Vec2 end,
    required double rxInput,
    required double ryInput,
    required double xAxisRotationDeg,
    required bool largeArcFlag,
    required bool sweepFlag,
  }) {
    if (start.distanceTo(end) <= 1e-6) {
      return const <({Vec2 cp1, Vec2 cp2, Vec2 end})>[];
    }

    var rx = rxInput.abs();
    var ry = ryInput.abs();
    if (rx <= 1e-6 || ry <= 1e-6) {
      return <({Vec2 cp1, Vec2 cp2, Vec2 end})>[
        (cp1: start, cp2: end, end: end),
      ];
    }

    final phi = xAxisRotationDeg * math.pi / 180.0;
    final cosPhi = math.cos(phi);
    final sinPhi = math.sin(phi);

    final dx2 = (start.x - end.x) * 0.5;
    final dy2 = (start.y - end.y) * 0.5;

    final x1p = cosPhi * dx2 + sinPhi * dy2;
    final y1p = -sinPhi * dx2 + cosPhi * dy2;

    var rxSq = rx * rx;
    var rySq = ry * ry;
    final x1pSq = x1p * x1p;
    final y1pSq = y1p * y1p;

    // Ensure radii are large enough to reach endpoint
    final lambda = (x1pSq / rxSq) + (y1pSq / rySq);
    if (lambda > 1.0) {
      final scale = math.sqrt(lambda);
      rx *= scale;
      ry *= scale;
      rxSq = rx * rx;
      rySq = ry * ry;
    }

    final sign = (largeArcFlag == sweepFlag) ? -1.0 : 1.0;
    final numTerm = math.max(
      0.0,
      rxSq * rySq - rxSq * y1pSq - rySq * x1pSq,
    );
    final denTerm = rxSq * y1pSq + rySq * x1pSq;
    final coef = sign * (denTerm > 1e-12 ? math.sqrt(numTerm / denTerm) : 0.0);

    final cxp = coef * ((rx * y1p) / ry);
    final cyp = coef * (-(ry * x1p) / rx);

    final cx = cosPhi * cxp - sinPhi * cyp + (start.x + end.x) * 0.5;
    final cy = sinPhi * cxp + cosPhi * cyp + (start.y + end.y) * 0.5;

    double vectorAngle(double ux, double uy, double vx, double vy) {
      final dot = ux * vx + uy * vy;
      final len = math.sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy));
      if (len <= 1e-12) return 0.0;
      final clamped = (dot / len).clamp(-1.0, 1.0);
      final angle = math.acos(clamped);
      return (ux * vy - uy * vx) < 0 ? -angle : angle;
    }

    final theta1 = vectorAngle(
      1.0,
      0.0,
      (x1p - cxp) / rx,
      (y1p - cyp) / ry,
    );
    var deltaTheta = vectorAngle(
      (x1p - cxp) / rx,
      (y1p - cyp) / ry,
      (-x1p - cxp) / rx,
      (-y1p - cyp) / ry,
    );

    if (!sweepFlag && deltaTheta > 0) {
      deltaTheta -= 2.0 * math.pi;
    } else if (sweepFlag && deltaTheta < 0) {
      deltaTheta += 2.0 * math.pi;
    }

    final segmentCount = math.max(
      1,
      (deltaTheta.abs() / (math.pi * 0.5)).ceil(),
    );
    final step = deltaTheta / segmentCount;
    final alpha =
        (4.0 / 3.0) * math.tan(step * 0.25);

    Vec2 mapEllipsePoint(double angle) {
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      return Vec2(
        cx + cosPhi * rx * cosA - sinPhi * ry * sinA,
        cy + sinPhi * rx * cosA + cosPhi * ry * sinA,
      );
    }

    Vec2 mapEllipseDerivative(double angle) {
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      return Vec2(
        -cosPhi * rx * sinA - sinPhi * ry * cosA,
        -sinPhi * rx * sinA + cosPhi * ry * cosA,
      );
    }

    final result = <({Vec2 cp1, Vec2 cp2, Vec2 end})>[];
    for (var i = 0; i < segmentCount; i++) {
      final a1 = theta1 + i * step;
      final a2 = a1 + step;
      final p1 = mapEllipsePoint(a1);
      final p2 = mapEllipsePoint(a2);
      final d1 = mapEllipseDerivative(a1);
      final d2 = mapEllipseDerivative(a2);

      result.add((
        cp1: p1 + d1 * alpha,
        cp2: p2 - d2 * alpha,
        end: p2,
      ));
    }

    return result;
  }
}
