// lib/main.dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:youtube_widget_macos/youtube_widget_app.dart';
import 'package:youtube_widget_macos/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: AppConfig.initialWindowSize,
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(AppConfig.minimumWindowSize);
    // IMPORTANT: The actual fix for fullscreen was in macos/Runner/MainFlutterWindow.swift
    // where maxFullScreenContentSize was set to a larger value (e.g., 1728x1080).
    // This line here sets the *windowed* max size, which is fine.
    await windowManager.setMaximumSize(AppConfig.maximumWindowSize);
    await windowManager.setAlwaysOnTop(true);
  });

  runApp(
    const ProviderScope(
      child: YouTubeWidgetApp(),
    ),
  );
}
