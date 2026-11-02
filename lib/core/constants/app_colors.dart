import 'package:flutter/material.dart';

/// Core color system for VECTRA Studio.
class AppColors {
  AppColors._();

  // Required Core Palette
  static const Color mainBackground = Color(0xFF0B0B0F);
  static const Color primaryPanel = Color(0xFF131319);
  static const Color secondarySurface = Color(0xFF191920);
  static const Color border = Color(0xFF292932);
  static const Color accent = Color(0xFFA78BFA);
  static const Color textPrimary = Color(0xFFF4F4F5);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);

  // Extended Interactive & Workspace States
  static const Color surfaceHover = Color(0xFF22222B);
  static const Color surfaceActive = Color(0xFF2A2738);
  static const Color accentSubtle = Color(0x28A78BFA);
  static const Color accentHover = Color(0xFFC4B5FD);
  static const Color accentMuted = Color(0xFF7C3AED);
  static const Color inputBackground = Color(0xFF0E0E13);
  static const Color inputBorderFocus = Color(0xFFA78BFA);

  // Canvas & Overlay Colors
  static const Color canvasBackdrop = Color(0xFF0B0B0F);
  static const Color artboardDefaultBg = Color(0xFFFFFFFF);
  static const Color artboardShadow = Color(0x77000000);
  static const Color gridMinor = Color(0x16000000);
  static const Color gridMajor = Color(0x2E000000);
  static const Color gridMinorDark = Color(0x18FFFFFF);
  static const Color gridMajorDark = Color(0x30FFFFFF);

  // Selection & Vector Handle Overlay Colors
  static const Color selectionOutline = Color(0xFFA78BFA);
  static const Color hoverOutline = Color(0x99A78BFA);
  static const Color marqueeFill = Color(0x22A78BFA);
  static const Color marqueeStroke = Color(0xCCA78BFA);
  static const Color handleFill = Color(0xFFFFFFFF);
  static const Color handleStroke = Color(0xFF7C3AED);
  static const Color bezierHandleLine = Color(0xFF38BDF8);
  static const Color bezierHandleFill = Color(0xFF38BDF8);
  static const Color selectedAnchorFill = Color(0xFFA78BFA);

  // Status & Semantic Colors
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSubtle = Color(0x26EF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);

  // Default Vector Swatches
  static const List<Color> defaultSwatches = <Color>[
    Color(0xFFA78BFA),
    Color(0xFF7C3AED),
    Color(0xFF6366F1),
    Color(0xFF3B82F6),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
    Color(0xFF84CC16),
    Color(0xFFEAB308),
    Color(0xFFF97316),
    Color(0xFFEF4444),
    Color(0xFFEC4899),
    Color(0xFFF43F5E),
    Color(0xFFFFFFFF),
    Color(0xFFD4D4D8),
    Color(0xFF71717A),
    Color(0xFF27272A),
    Color(0xFF09090B),
  ];
}
