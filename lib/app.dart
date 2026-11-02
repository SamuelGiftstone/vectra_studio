import 'dart:io' show Platform;

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/editor_constants.dart';
import 'core/theme/app_theme.dart';
import 'ui/workspace/editor_workspace.dart';

/// Root VECTRA Studio application widget.
class VectraStudioApp extends ConsumerWidget {
  const VectraStudioApp({super.key});

  bool get _useWindowBorder =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const workspace = EditorWorkspace();

    return MaterialApp(
      title: EditorConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _useWindowBorder
          ? WindowBorder(
              color: AppColors.border,
              width: 1.0,
              child: workspace,
            )
          : workspace,
    );
  }
}
