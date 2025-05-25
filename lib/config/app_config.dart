// lib/config/app_config.dart
import 'package:flutter/material.dart';

class AppConfig {
  // Window Manager Configuration
  static const Size initialWindowSize = Size(400, 400);
  static const Size minimumWindowSize = Size(300, 300);
  static const Size maximumWindowSize = Size(800, 800);
  // Note: maxFullScreenContentSize is set in macos/Runner/MainFlutterWindow.swift
  // and should ideally match or exceed your screen's resolution for true fullscreen.
  // For example, if your screen is 1920x1080, you might set it to 1920x1080 or higher.

  // Application Details
  static const String appTitle = 'YouTube Widget';
  static const String initialUrlInputHint = 'Paste YouTube URL here...';

  // Other potential configurations
  static const MaterialColor primaryColor = Colors.red;
  static const Color backgroundColor = Colors.black;
}
