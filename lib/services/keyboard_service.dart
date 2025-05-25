// lib/services/keyboard_service.dart
import 'package:flutter/services.dart';

class KeyboardService {
  final VoidCallback onSpacePressed;
  final VoidCallback onCmdShiftEnterPressed;

  KeyboardService({
    required this.onSpacePressed,
    required this.onCmdShiftEnterPressed,
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
