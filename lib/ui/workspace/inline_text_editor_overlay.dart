import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_icons.dart';
import '../../math/vec2.dart';
import '../../models/text_object.dart';
import '../../providers/editor_providers.dart';
import '../../rendering/font_catalog.dart';

/// Viewport-projected inline canvas text editor rendered directly at the active
/// [TextObject]'s screen coordinates during creation or re-editing.
///
/// Supports multiline `Enter`, text selection, copy/paste, `Ctrl+Enter` to commit,
/// and `Escape` to cancel cleanly without canvas gesture interference.
class InlineTextEditorOverlay extends ConsumerStatefulWidget {
  const InlineTextEditorOverlay({super.key});

  @override
  ConsumerState<InlineTextEditorOverlay> createState() =>
      _InlineTextEditorOverlayState();
}

class _InlineTextEditorOverlayState
    extends ConsumerState<InlineTextEditorOverlay> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _boundSessionObjectId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode(
      debugLabel: 'InlineCanvasTextEditor',
      onKeyEvent: _handleEditorKeyEvent,
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  KeyEventResult _handleEditorKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final kb = HardwareKeyboard.instance;
    final isCtrl = kb.isControlPressed || kb.isMetaPressed;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      ref.read(editorControllerProvider).cancelInlineTextEditing();
      return KeyEventResult.handled;
    }

    if (isCtrl &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      ref.read(editorControllerProvider).commitInlineTextEditing();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _syncSession(TextObject textObj) {
    if (_boundSessionObjectId != textObj.id) {
      _boundSessionObjectId = textObj.id;
      _controller.value = TextEditingValue(
        text: textObj.text,
        selection: TextSelection.collapsed(offset: textObj.text.length),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    } else if (_controller.text != textObj.text) {
      final prevSelection = _controller.selection;
      final clampedOffset =
          prevSelection.baseOffset.clamp(0, textObj.text.length);
      _controller.value = TextEditingValue(
        text: textObj.text,
        selection: TextSelection.collapsed(offset: clampedOffset),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeTextSessionProvider);
    if (session == null) {
      _boundSessionObjectId = null;
      return const SizedBox.shrink();
    }

    final document = ref.watch(currentDocumentProvider);
    final viewport = ref.watch(viewportControllerProvider);
    final obj = document.findObjectById(session.objectId);
    if (obj is! TextObject) {
      return const SizedBox.shrink();
    }

    _syncSession(obj);

    final editor = ref.read(editorControllerProvider);
    final zoom = viewport.zoom;
    final screenTopLeft = viewport.documentToScreen(Vec2(obj.x, obj.y));

    final scaledFontSize = (obj.fontSize * zoom).clamp(8.0, 600.0);
    final scaledLetterSpacing = obj.letterSpacing * zoom;
    final textColor = obj.fill.isEnabled
        ? obj.fill.color.withOpacity(
            (obj.fill.opacity * obj.opacity).clamp(0.15, 1.0),
          )
        : AppColors.textPrimary;

    final textStyle = FontCatalog.buildTextStyle(
      fontFamily: obj.fontFamily,
      fontSize: scaledFontSize,
      fontWeightValue: obj.fontWeightValue,
      isItalic: obj.isItalic,
      lineHeight: obj.lineHeight,
      letterSpacing: scaledLetterSpacing,
      color: textColor,
    );

    final bounds = obj.localBounds;
    final double editorWidth;
    final double minEditorHeight;
    if (obj.isAreaText && obj.frameWidth != null) {
      editorWidth = math.max(64.0, obj.frameWidth! * zoom);
      minEditorHeight = math.max(
        28.0,
        (obj.frameHeight ?? bounds.height) * zoom,
      );
    } else {
      editorWidth = math.max(
        180.0,
        bounds.width * zoom + scaledFontSize * 1.5,
      );
      minEditorHeight = math.max(28.0, scaledFontSize * obj.lineHeight + 6.0);
    }

    final pillTop = math.max(6.0, screenTopLeft.dy - 28.0);

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // Compact control pill above the active text box
        Positioned(
          left: screenTopLeft.dx,
          top: pillTop,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) {},
            child: Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryPanel,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(color: AppColors.accent, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(AppIcons.text, size: 11, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    obj.isAreaText ? 'Frame Text' : 'Point Text',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: editor.commitInlineTextEditing,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            AppIcons.check,
                            size: 11,
                            color: AppColors.success,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: editor.cancelInlineTextEditing,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                      child: Icon(
                        AppIcons.close,
                        size: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Inline editable text container aligned to document coordinates
        Positioned(
          left: screenTopLeft.dx,
          top: screenTopLeft.dy,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) {},
            onPointerMove: (_) {},
            onPointerUp: (_) {},
            child: Transform.rotate(
              angle: obj.rotation,
              alignment: Alignment.topLeft,
              child: Container(
                width: editorWidth,
                constraints: BoxConstraints(minHeight: minEditorHeight),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: AppColors.accent,
                    width: 1.2,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textAlign: obj.textAlign,
                  style: textStyle,
                  cursorColor: AppColors.accent,
                  cursorWidth: 1.8,
                  onChanged: editor.updateInlineTextDraft,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    hintText: 'Type text...',
                    hintStyle: textStyle.copyWith(
                      color: textColor.withOpacity(0.35),
                    ),
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
