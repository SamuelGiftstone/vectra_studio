import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/editor_constants.dart';

/// Descriptor for a font family selectable in VECTRA Studio's Text Inspector.
class FontFamilyOption {
  final String family;
  final String category;
  final List<String> fallbacks;
  final bool usesGoogleFont;

  const FontFamilyOption({
    required this.family,
    required this.category,
    required this.fallbacks,
    this.usesGoogleFont = false,
  });
}

/// Offline-safe font catalog and [TextStyle] resolver shared across canvas
/// [TextPainter] rendering, inline viewport text editing, and Inspector previews.
///
/// Disables unexpected runtime HTTP font fetching by default and provides deterministic
/// Windows/cross-platform fallback chains so rendering never crashes or stalls offline.
class FontCatalog {
  FontCatalog._();

  static bool _configured = false;

  /// Ensures `GoogleFonts` does not initiate unexpected network requests offline.
  static void ensureOfflineSafeConfiguration() {
    if (_configured) return;
    GoogleFonts.config.allowRuntimeFetching = false;
    _configured = true;
  }

  static const List<FontFamilyOption> curatedFonts = <FontFamilyOption>[
    FontFamilyOption(
      family: 'Inter',
      category: 'Sans-Serif',
      fallbacks: <String>['Segoe UI', 'Roboto', 'Arial', 'sans-serif'],
      usesGoogleFont: true,
    ),
    FontFamilyOption(
      family: 'Segoe UI',
      category: 'System Sans',
      fallbacks: <String>['Inter', 'Arial', 'sans-serif'],
    ),
    FontFamilyOption(
      family: 'Roboto',
      category: 'Sans-Serif',
      fallbacks: <String>['Segoe UI', 'Arial', 'sans-serif'],
      usesGoogleFont: true,
    ),
    FontFamilyOption(
      family: 'Arial',
      category: 'Sans-Serif',
      fallbacks: <String>['Segoe UI', 'Helvetica', 'sans-serif'],
    ),
    FontFamilyOption(
      family: 'Georgia',
      category: 'Serif',
      fallbacks: <String>['Times New Roman', 'serif'],
    ),
    FontFamilyOption(
      family: 'Merriweather',
      category: 'Serif',
      fallbacks: <String>['Georgia', 'Times New Roman', 'serif'],
      usesGoogleFont: true,
    ),
    FontFamilyOption(
      family: 'Playfair Display',
      category: 'Display Serif',
      fallbacks: <String>['Georgia', 'Times New Roman', 'serif'],
      usesGoogleFont: true,
    ),
    FontFamilyOption(
      family: 'JetBrains Mono',
      category: 'Monospace',
      fallbacks: <String>['Consolas', 'Courier New', 'monospace'],
      usesGoogleFont: true,
    ),
    FontFamilyOption(
      family: 'Consolas',
      category: 'Monospace',
      fallbacks: <String>['Courier New', 'monospace'],
    ),
    FontFamilyOption(
      family: 'Courier New',
      category: 'Monospace',
      fallbacks: <String>['Consolas', 'monospace'],
    ),
  ];

  static const List<int> supportedWeights = <int>[300, 400, 500, 600, 700, 800];

  static String weightLabel(int weight) {
    switch (weight) {
      case 300:
        return 'Light (300)';
      case 400:
        return 'Regular (400)';
      case 500:
        return 'Medium (500)';
      case 600:
        return 'SemiBold (600)';
      case 700:
        return 'Bold (700)';
      case 800:
        return 'ExtraBold (800)';
      default:
        return 'Weight $weight';
    }
  }

  static FontWeight resolveFontWeight(int numericWeight) {
    if (numericWeight <= 150) return FontWeight.w100;
    if (numericWeight <= 250) return FontWeight.w200;
    if (numericWeight <= 350) return FontWeight.w300;
    if (numericWeight <= 450) return FontWeight.w400;
    if (numericWeight <= 550) return FontWeight.w500;
    if (numericWeight <= 650) return FontWeight.w600;
    if (numericWeight <= 750) return FontWeight.w700;
    if (numericWeight <= 850) return FontWeight.w800;
    return FontWeight.w900;
  }

  static FontFamilyOption findOption(String familyName) {
    final normalized = familyName.trim().toLowerCase();
    for (final option in curatedFonts) {
      if (option.family.toLowerCase() == normalized) {
        return option;
      }
    }
    return FontFamilyOption(
      family: familyName.trim().isEmpty
          ? EditorConstants.defaultFontFamily
          : familyName.trim(),
      category: 'Custom',
      fallbacks: const <String>['Segoe UI', 'Arial', 'sans-serif'],
    );
  }

  /// Resolves an offline-safe [TextStyle] that never throws if bundled font assets
  /// are absent or if the machine is offline.
  static TextStyle buildTextStyle({
    required String fontFamily,
    required double fontSize,
    required int fontWeightValue,
    required bool isItalic,
    required double lineHeight,
    required double letterSpacing,
    required Color color,
    Paint? foreground,
  }) {
    ensureOfflineSafeConfiguration();

    final option = findOption(fontFamily);
    final weight = resolveFontWeight(fontWeightValue);
    final style = isItalic ? FontStyle.italic : FontStyle.normal;
    final clampedSize = fontSize.clamp(
      EditorConstants.minFontSize,
      EditorConstants.maxFontSize,
    );
    final clampedHeight = lineHeight.clamp(0.6, 5.0);

    final baseStyle = TextStyle(
      fontFamily: option.family,
      fontFamilyFallback: option.fallbacks,
      fontSize: clampedSize,
      fontWeight: weight,
      fontStyle: style,
      height: clampedHeight,
      letterSpacing: letterSpacing,
      color: foreground == null ? color : null,
      foreground: foreground,
    );

    if (!option.usesGoogleFont) {
      return baseStyle;
    }

    // Attempt local bundled GoogleFont resolution when available; fall back cleanly
    // to platform font family + fallback stack without network calls.
    try {
      switch (option.family) {
        case 'Inter':
          return GoogleFonts.inter(textStyle: baseStyle);
        case 'Roboto':
          return GoogleFonts.roboto(textStyle: baseStyle);
        case 'Merriweather':
          return GoogleFonts.merriweather(textStyle: baseStyle);
        case 'Playfair Display':
          return GoogleFonts.playfairDisplay(textStyle: baseStyle);
        case 'JetBrains Mono':
          return GoogleFonts.jetBrainsMono(textStyle: baseStyle);
      }
    } catch (_) {
      return baseStyle;
    }

    return baseStyle;
  }
}
