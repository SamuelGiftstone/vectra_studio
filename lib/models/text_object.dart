import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/constants/editor_constants.dart';
import '../core/utils/validation_utils.dart';
import '../math/bounds2d.dart';
import '../math/vec2.dart';
import '../rendering/text_layout_service.dart';
import 'fill_style.dart';
import 'stroke_style.dart';
import 'vector_object.dart';

/// Editable 2D vector text object supporting both Point Text (click-created,
/// intrinsic width) and Area / Frame Text (drag-created bounding box with wrapping).
///
/// Resizing behavior:
/// - **Area / Frame Text** ([isAreaText] == `true`): resizing updates [x], [y],
///   [frameWidth], and [frameHeight], dynamically re-wrapping lines inside the frame.
/// - **Point Text** ([isAreaText] == `false`): resizing updates [x], [y] and scales
///   [fontSize] proportionally to the vertical resize ratio.
class TextObject extends VectorObject {
  final String text;
  final double x;
  final double y;
  final double? frameWidth;
  final double? frameHeight;
  final String fontFamily;
  final double fontSize;
  final int fontWeightValue;
  final bool isItalic;
  final TextAlign textAlign;
  final double lineHeight;
  final double letterSpacing;

  const TextObject({
    required super.id,
    required super.name,
    required super.layerId,
    required this.text,
    required this.x,
    required this.y,
    this.frameWidth,
    this.frameHeight,
    this.fontFamily = EditorConstants.defaultFontFamily,
    this.fontSize = EditorConstants.defaultFontSize,
    this.fontWeightValue = EditorConstants.defaultFontWeight,
    this.isItalic = false,
    this.textAlign = TextAlign.left,
    this.lineHeight = EditorConstants.defaultLineHeight,
    this.letterSpacing = 0.0,
    super.fill = const FillStyle(
      color: Color(0xFF18181B),
      opacity: 1.0,
      isEnabled: true,
    ),
    super.stroke = StrokeStyle.none,
    super.opacity = 1.0,
    super.visible = true,
    super.locked = false,
    super.rotation = 0.0,
  }) : super(type: VectorObjectType.text);

  /// `true` when this text object wraps inside an explicit rectangular text frame.
  bool get isAreaText => frameWidth != null;

  bool get isBold => fontWeightValue >= 600;

  @override
  Bounds2D get localBounds => TextLayoutService.measureLocalBounds(
        x: x,
        y: y,
        text: text,
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeightValue: fontWeightValue,
        isItalic: isItalic,
        textAlign: textAlign,
        lineHeight: lineHeight,
        letterSpacing: letterSpacing,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
      );

  TextObject copyWith({
    String? id,
    String? name,
    String? layerId,
    String? text,
    double? x,
    double? y,
    double? frameWidth,
    bool clearFrameWidth = false,
    double? frameHeight,
    bool clearFrameHeight = false,
    String? fontFamily,
    double? fontSize,
    int? fontWeightValue,
    bool? isItalic,
    TextAlign? textAlign,
    double? lineHeight,
    double? letterSpacing,
    FillStyle? fill,
    StrokeStyle? stroke,
    double? opacity,
    bool? visible,
    bool? locked,
    double? rotation,
  }) {
    return TextObject(
      id: id ?? this.id,
      name: name ?? this.name,
      layerId: layerId ?? this.layerId,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      frameWidth: clearFrameWidth ? null : (frameWidth ?? this.frameWidth),
      frameHeight: clearFrameHeight ? null : (frameHeight ?? this.frameHeight),
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: (fontSize ?? this.fontSize).clamp(
        EditorConstants.minFontSize,
        EditorConstants.maxFontSize,
      ),
      fontWeightValue: (fontWeightValue ?? this.fontWeightValue).clamp(100, 900),
      isItalic: isItalic ?? this.isItalic,
      textAlign: textAlign ?? this.textAlign,
      lineHeight: (lineHeight ?? this.lineHeight).clamp(0.6, 5.0),
      letterSpacing: (letterSpacing ?? this.letterSpacing).clamp(-20.0, 100.0),
      fill: fill ?? this.fill,
      stroke: stroke ?? this.stroke,
      opacity: (opacity ?? this.opacity).clamp(0.0, 1.0),
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      rotation: rotation ?? this.rotation,
    );
  }

  /// Converts between Point Text and Area / Frame Text while preserving visual position.
  TextObject toggleAreaTextMode() {
    if (isAreaText) {
      return copyWith(clearFrameWidth: true, clearFrameHeight: true);
    }
    final measured = localBounds;
    return copyWith(
      frameWidth: math.max(120.0, measured.width + 16.0),
      frameHeight: math.max(40.0, measured.height + 8.0),
    );
  }

  @override
  TextObject translate(Vec2 delta) => copyWith(
        x: x + delta.x,
        y: y + delta.y,
      );

  @override
  TextObject resizeLocalBounds(Bounds2D newBounds) {
    if (isAreaText) {
      return copyWith(
        x: newBounds.left,
        y: newBounds.top,
        frameWidth: math.max(EditorConstants.minTextFrameWidth, newBounds.width),
        frameHeight: math.max(
          EditorConstants.minTextFrameHeight,
          newBounds.height,
        ),
      );
    }

    final current = localBounds;
    var nextFontSize = fontSize;
    if ((newBounds.height - current.height).abs() > 0.5 && current.height > 1.0) {
      final scaleY = newBounds.height / current.height;
      nextFontSize = (fontSize * scaleY).clamp(
        EditorConstants.minFontSize,
        EditorConstants.maxFontSize,
      );
    }
    return copyWith(
      x: newBounds.left,
      y: newBounds.top,
      fontSize: nextFontSize,
    );
  }

  @override
  TextObject withRotation(double newRotationRadians) =>
      copyWith(rotation: newRotationRadians);

  @override
  TextObject withFill(FillStyle newFill) => copyWith(fill: newFill);

  @override
  TextObject withStroke(StrokeStyle newStroke) => copyWith(stroke: newStroke);

  @override
  TextObject withOpacity(double newOpacity) => copyWith(opacity: newOpacity);

  @override
  TextObject withName(String newName) => copyWith(name: newName);

  @override
  TextObject withVisibility(bool isVisible) => copyWith(visible: isVisible);

  @override
  TextObject withLocked(bool isLocked) => copyWith(locked: isLocked);

  @override
  TextObject withLayerId(String newLayerId) => copyWith(layerId: newLayerId);

  @override
  TextObject duplicateWithNewId({
    required String newId,
    String? newLayerId,
    Vec2 offset = Vec2.zero,
  }) {
    return copyWith(
      id: newId,
      name: '$name Copy',
      layerId: newLayerId ?? layerId,
      x: x + offset.x,
      y: y + offset.y,
    );
  }

  static String textAlignToJson(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return 'center';
      case TextAlign.right:
      case TextAlign.end:
        return 'right';
      case TextAlign.justify:
        return 'justify';
      case TextAlign.left:
      case TextAlign.start:
        return 'left';
    }
  }

  static TextAlign textAlignFromJson(String? raw) {
    switch (raw) {
      case 'center':
        return TextAlign.center;
      case 'right':
      case 'end':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...baseFieldsToJson(),
        'text': text,
        'x': x,
        'y': y,
        if (frameWidth != null) 'frameWidth': frameWidth,
        if (frameHeight != null) 'frameHeight': frameHeight,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'fontWeightValue': fontWeightValue,
        'isItalic': isItalic,
        'textAlign': textAlignToJson(textAlign),
        'lineHeight': lineHeight,
        'letterSpacing': letterSpacing,
      };

  factory TextObject.fromJson(Map<String, dynamic> json) {
    final rawFrameW = json['frameWidth'];
    final rawFrameH = json['frameHeight'];

    return TextObject(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Text',
      layerId: (json['layerId'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
      x: ValidationUtils.requireFiniteDouble(json['x'], 'x'),
      y: ValidationUtils.requireFiniteDouble(json['y'], 'y'),
      frameWidth: rawFrameW is num
          ? ValidationUtils.clampDouble(
              rawFrameW.toDouble(),
              EditorConstants.minTextFrameWidth,
              EditorConstants.maxArtboardSize,
            )
          : null,
      frameHeight: rawFrameH is num
          ? ValidationUtils.clampDouble(
              rawFrameH.toDouble(),
              EditorConstants.minTextFrameHeight,
              EditorConstants.maxArtboardSize,
            )
          : null,
      fontFamily: ((json['fontFamily'] as String?) ?? '').trim().isEmpty
          ? EditorConstants.defaultFontFamily
          : (json['fontFamily'] as String).trim(),
      fontSize: ValidationUtils.optionalDouble(
        json['fontSize'],
        EditorConstants.defaultFontSize,
      ).clamp(EditorConstants.minFontSize, EditorConstants.maxFontSize),
      fontWeightValue: ValidationUtils.optionalDouble(
        json['fontWeightValue'],
        EditorConstants.defaultFontWeight.toDouble(),
      ).round().clamp(100, 900),
      isItalic: json['isItalic'] is bool ? json['isItalic'] as bool : false,
      textAlign: textAlignFromJson(json['textAlign'] as String?),
      lineHeight: ValidationUtils.optionalDouble(
        json['lineHeight'],
        EditorConstants.defaultLineHeight,
      ).clamp(0.6, 5.0),
      letterSpacing: ValidationUtils.optionalDouble(
        json['letterSpacing'],
        0.0,
      ).clamp(-20.0, 100.0),
      fill: FillStyle.fromJson(
        json['fill'] as Map<String, dynamic>?,
        fallback: const FillStyle(
          color: Color(0xFF18181B),
          opacity: 1.0,
          isEnabled: true,
        ),
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
