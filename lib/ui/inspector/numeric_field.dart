import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validation_utils.dart';

/// Compact desktop numeric input field for the Inspector panel.
///
/// Tracks [ownerKey] (e.g., selected object ID) so switching selection never
/// accidentally commits a stale draft value onto the newly selected object.
class NumericInspectorField extends StatefulWidget {
  final String ownerKey;
  final String label;
  final double value;
  final int decimals;
  final double min;
  final double max;
  final bool enabled;
  final ValueChanged<double> onCommitted;

  const NumericInspectorField({
    super.key,
    required this.ownerKey,
    required this.label,
    required this.value,
    this.decimals = 1,
    this.min = -100000.0,
    this.max = 100000.0,
    this.enabled = true,
    required this.onCommitted,
  });

  @override
  State<NumericInspectorField> createState() => _NumericInspectorFieldState();
}

class _NumericInspectorFieldState extends State<NumericInspectorField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late String _boundOwnerKey;

  @override
  void initState() {
    super.initState();
    _boundOwnerKey = widget.ownerKey;
    _controller = TextEditingController(text: _format(widget.value));
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant NumericInspectorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ownerKey != _boundOwnerKey) {
      // Selection changed: reset controller immediately without committing old text!
      _boundOwnerKey = widget.ownerKey;
      _controller.text = _format(widget.value);
      return;
    }
    if (!_focusNode.hasFocus) {
      final formatted = _format(widget.value);
      if (_controller.text != formatted) {
        _controller.text = formatted;
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitCurrentText();
    }
  }

  void _commitCurrentText() {
    if (!widget.enabled || widget.ownerKey != _boundOwnerKey) return;
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null || parsed.isNaN || parsed.isInfinite) {
      _controller.text = _format(widget.value);
      return;
    }
    final clamped = ValidationUtils.clampDouble(parsed, widget.min, widget.max);
    _controller.text = _format(clamped);
    if ((clamped - widget.value).abs() > 1e-4) {
      widget.onCommitted(clamped);
    }
  }

  String _format(double v) =>
      ValidationUtils.formatCompact(v, decimals: widget.decimals);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.inputHeight,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        style: AppTheme.monoStyle(
          fontSize: 11.5,
          color: widget.enabled ? AppColors.textPrimary : AppColors.textMuted,
        ),
        onSubmitted: (_) => _commitCurrentText(),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 7, right: 4),
            child: Text(
              widget.label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        ),
      ),
    );
  }
}
