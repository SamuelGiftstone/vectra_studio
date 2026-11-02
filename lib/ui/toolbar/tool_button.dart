import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';

/// Individual icon button inside the left vector tool dock with distinct hover,
/// active, and disabled visual states.
class ToolButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onPressed;

  const ToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.isSelected = false,
    this.isEnabled = true,
    this.onPressed,
  });

  @override
  State<ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<ToolButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected;
    final enabled = widget.isEnabled && widget.onPressed != null;

    Color bgColor = Colors.transparent;
    if (active) {
      bgColor = AppColors.surfaceActive;
    } else if (_isHovered && enabled) {
      bgColor = AppColors.surfaceHover;
    }

    Color iconColor = AppColors.textSecondary;
    if (!enabled) {
      iconColor = AppColors.textMuted.withOpacity(0.45);
    } else if (active) {
      iconColor = AppColors.accent;
    } else if (_isHovered) {
      iconColor = AppColors.textPrimary;
    }

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? widget.onPressed : null,
          child: Container(
            width: AppDimensions.toolButtonSize,
            height: AppDimensions.toolButtonSize,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(
                color: active ? AppColors.accent : Colors.transparent,
                width: 1.0,
              ),
            ),
            child: Icon(
              widget.icon,
              size: AppDimensions.iconLg,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
