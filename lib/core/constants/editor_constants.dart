/// Document preset definition for creating new artboards.
class ArtboardPreset {
  final String name;
  final double width;
  final double height;

  const ArtboardPreset({
    required this.name,
    required this.width,
    required this.height,
  });
}

/// Core numerical limits, file format tags, and editor defaults.
class EditorConstants {
  EditorConstants._();

  // Persistence format metadata
  static const String appName = 'VECTRA Studio';
  static const String projectFormatId = 'vectra-studio';
  static const int currentSchemaVersion = 2;
  static const String projectExtension = 'vectra';
  static const String svgExtension = 'svg';
  static const String pngExtension = 'png';
  static const String jpegExtension = 'jpg';
  static const List<String> supportedRasterImportExtensions = <String>[
    'png',
    'jpg',
    'jpeg',
    'webp',
  ];

  // Default document dimensions
  static const double defaultArtboardWidth = 1200.0;
  static const double defaultArtboardHeight = 800.0;
  static const double minArtboardSize = 16.0;
  static const double maxArtboardSize = 16384.0;

  // Viewport zoom limits
  static const double minZoom = 0.05;
  static const double maxZoom = 32.0;
  static const double zoomStepFactor = 1.25;
  static const double fitViewportPadding = 64.0;
  static const double defaultGridSize = 20.0;

  // Tool & hit-testing defaults (in screen pixels before zoom conversion)
  static const double hitTestScreenTolerance = 7.0;
  static const double handleHitScreenRadius = 8.5;
  static const double penCloseScreenRadius = 10.0;
  static const double minDragCreateDistance = 2.0;
  static const double textFrameDragThreshold = 8.0;

  // Typography defaults
  static const String defaultFontFamily = 'Inter';
  static const double defaultFontSize = 28.0;
  static const double minFontSize = 4.0;
  static const double maxFontSize = 1000.0;
  static const int defaultFontWeight = 400;
  static const double defaultLineHeight = 1.25;
  static const double minTextFrameWidth = 24.0;
  static const double minTextFrameHeight = 20.0;

  // Export defaults
  static const int defaultJpegQuality = 92;

  // Shape defaults
  static const int defaultPolygonSides = 6;
  static const int minPolygonSides = 3;
  static const int maxPolygonSides = 24;

  static const int defaultStarPoints = 5;
  static const int minStarPoints = 3;
  static const int maxStarPoints = 24;
  static const double defaultStarInnerRatio = 0.45;

  // History limits
  static const int maxHistoryEntries = 100;

  // Standard artboard presets
  static const List<ArtboardPreset> artboardPresets = <ArtboardPreset>[
    ArtboardPreset(name: 'Desktop Illustration', width: 1200, height: 800),
    ArtboardPreset(name: 'FHD Presentation (1080p)', width: 1920, height: 1080),
    ArtboardPreset(name: 'Web Hero / App Frame', width: 1440, height: 900),
    ArtboardPreset(name: 'Square Artwork', width: 1080, height: 1080),
    ArtboardPreset(name: 'Icon Design Grid', width: 512, height: 512),
    ArtboardPreset(name: 'Print A4 Portrait', width: 794, height: 1123),
  ];
}

