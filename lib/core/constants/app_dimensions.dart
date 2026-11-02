/// Layout metrics, spacing, radii, and sizing constants for VECTRA Studio.
class AppDimensions {
  AppDimensions._();

  // Window constraints
  static const double minWindowWidth = 1080.0;
  static const double minWindowHeight = 700.0;
  static const double defaultWindowWidth = 1440.0;
  static const double defaultWindowHeight = 900.0;

  // Workspace chrome
  static const double titleBarHeight = 38.0;
  static const double contextBarHeight = 36.0;
  static const double statusBarHeight = 26.0;
  static const double leftToolbarWidth = 48.0;
  static const double rightSidebarWidth = 288.0;

  // Spacing scale
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;

  // Border radii
  static const double radiusSm = 4.0;
  static const double radiusMd = 6.0;
  static const double radiusLg = 8.0;

  // Icons & controls
  static const double iconSm = 14.0;
  static const double iconMd = 16.0;
  static const double iconLg = 18.0;
  static const double toolButtonSize = 36.0;
  static const double inputHeight = 28.0;

  // Canvas overlay screen-space metrics
  static const double resizeHandleSize = 8.0;
  static const double rotationHandleOffset = 24.0;
  static const double rotationHandleRadius = 5.0;
  static const double anchorNodeSize = 8.0;
  static const double bezierHandleRadius = 4.0;
}
