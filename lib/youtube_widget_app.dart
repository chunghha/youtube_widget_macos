// lib/youtube_widget_app.dart
import 'package:flutter/material.dart';
import 'package:youtube_widget_macos/screens/youtube_widget_screen.dart';
import 'package:youtube_widget_macos/config/app_config.dart';

class YouTubeWidgetApp extends StatelessWidget {
  const YouTubeWidgetApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appTitle,
      theme: ThemeData(
        primarySwatch: AppConfig.primaryColor,
        scaffoldBackgroundColor: AppConfig.backgroundColor,
      ),
      home: const YouTubeWidgetScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
