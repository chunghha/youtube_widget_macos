// lib/services/keyboard_service.dart
import 'package:flutter/services.dart';

class KeyboardService {
  final VoidCallback onSpacePressed;
  final VoidCallback onCmdShiftEnterPressed;
  final VoidCallback onPlayPausePressed;
  final VoidCallback onStopPressed;

  KeyboardService({
    required this.onSpacePressed,
    required this.onCmdShiftEnterPressed,
    required this.onPlayPausePressed,
    required this.onStopPressed,
  });

  bool _hardwareKeyHandler(KeyEvent event) {
    if (event is KeyDownEvent) {
      final Set<LogicalKeyboardKey> pressedKeys =
          HardwareKeyboard.instance.logicalKeysPressed;

      if (event.logicalKey == LogicalKeyboardKey.space) {
        onSpacePressed();
        return true;
      } else if ((pressedKeys.contains(LogicalKeyboardKey.metaLeft) ||
              pressedKeys.contains(LogicalKeyboardKey.metaRight)) &&
          (pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
              pressedKeys.contains(LogicalKeyboardKey.shiftRight)) &&
          event.logicalKey == LogicalKeyboardKey.enter) {
        onCmdShiftEnterPressed();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.keyP) {
        onPlayPausePressed();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
        onStopPressed();
        return true;
      }
    }
    return false;
  }

  void addHandler() {
    HardwareKeyboard.instance.addHandler(_hardwareKeyHandler);
  }

  void removeHandler() {
    HardwareKeyboard.instance.removeHandler(_hardwareKeyHandler);
  }
}
