// lib/services/window_service.dart
import 'package:window_manager/window_manager.dart';

class WindowService {
  static Future<void> minimize() async {
    await windowManager.minimize();
  }

  static Future<void> close() async {
    await windowManager.close();
  }

  static Future<void> startDragging() async {
    await windowManager.startDragging();
  }

  static Future<bool> isFullScreen() async {
    return await windowManager.isFullScreen();
  }

  static Future<void> setFullScreen(bool fullscreen) async {
    await windowManager.setFullScreen(fullscreen);
  }
}
