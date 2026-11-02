import 'dart:io' show Platform;

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/constants/app_dimensions.dart';
import 'core/constants/editor_constants.dart';
import 'rendering/font_catalog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FontCatalog.ensureOfflineSafeConfiguration();

  runApp(
    const ProviderScope(
      child: VectraStudioApp(),
    ),
  );

  if (!kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    doWhenWindowReady(() {
      const initialSize = Size(
        AppDimensions.defaultWindowWidth,
        AppDimensions.defaultWindowHeight,
      );
      const minSize = Size(
        AppDimensions.minWindowWidth,
        AppDimensions.minWindowHeight,
      );
      appWindow.minSize = minSize;
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.title = EditorConstants.appName;
      appWindow.show();
    });
  }
}
