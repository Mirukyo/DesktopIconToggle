import 'package:shared_preferences/shared_preferences.dart';

import '../bridge.dart';

class SettingsController {
  static const String firstRunCompletedKey =
      'first_run_completed';

  bool doubleClickEnabled = true;
  bool startupEnabled = false;
  bool trayEnabled = true;
  bool hotkeyEnabled = true;

  String hotkey = 'Ctrl + Alt + H';

  int hotkeyModifiers = 3;
  int hotkeyVk = 0x48;

  bool saving = false;

  // ==========================================================
  // Load settings from native side
  // ==========================================================

  Future<void> load() async {
    final settings =
        await NativeBridge.getSettings();

    doubleClickEnabled =
        settings['doubleClickEnabled']
                as bool? ??
            true;

    startupEnabled =
        settings['startupEnabled']
                as bool? ??
            false;

    trayEnabled =
        settings['trayEnabled']
                as bool? ??
            true;

    hotkeyEnabled =
        settings['hotkeyEnabled']
                as bool? ??
            true;

    hotkeyModifiers =
        settings['hotkeyModifiers']
                as int? ??
            3;

    hotkeyVk =
        settings['hotkeyVk']
                as int? ??
            0x48;

    hotkey =
        formatHotkey(
      hotkeyModifiers,
      hotkeyVk,
    );
  }

  // ==========================================================
  // Save settings
  // ==========================================================

  Future<bool> save() async {
    final success =
        await NativeBridge.saveSettings(
      <String, dynamic>{
        'doubleClickEnabled':
            doubleClickEnabled,
        'startupEnabled':
            startupEnabled,
        'trayEnabled':
            trayEnabled,
        'hotkeyEnabled':
            hotkeyEnabled,
        'hotkeyModifiers':
            hotkeyModifiers,
        'hotkeyVk':
            hotkeyVk,
      },
    );

    return success;
  }

  // ==========================================================
  // Restore defaults
  // ==========================================================

  void restoreDefaults() {
    doubleClickEnabled = true;
    startupEnabled = false;
    trayEnabled = true;
    hotkeyEnabled = true;

    hotkeyModifiers = 3;
    hotkeyVk = 0x48;

    hotkey =
        'Ctrl + Alt + H';
  }

  // ==========================================================
  // Set hotkey
  // ==========================================================

  void setHotkey({
    required int modifiers,
    required int virtualKey,
    required String display,
  }) {
    hotkeyModifiers =
        modifiers;

    hotkeyVk =
        virtualKey;

    hotkey =
        display;
  }

  // ==========================================================
  // Format hotkey
  // ==========================================================

  String formatHotkey(
    int modifiers,
    int virtualKey,
  ) {
    final result =
        <String>[];

    if ((modifiers & 2) != 0) {
      result.add('Ctrl');
    }

    if ((modifiers & 4) != 0) {
      result.add('Shift');
    }

    if ((modifiers & 1) != 0) {
      result.add('Alt');
    }

    if ((modifiers & 8) != 0) {
      result.add('Win');
    }

    if (virtualKey >= 0x41 &&
        virtualKey <= 0x5A) {
      result.add(
        String.fromCharCode(
          virtualKey,
        ),
      );
    } else if (virtualKey >= 0x30 &&
        virtualKey <= 0x39) {
      result.add(
        String.fromCharCode(
          virtualKey,
        ),
      );
    } else if (virtualKey >= 0x70 &&
        virtualKey <= 0x7B) {
      result.add(
        'F${virtualKey - 0x6F}',
      );
    }

    return result.join(
      ' + ',
    );
  }

  // ==========================================================
  // First-run state
  // ==========================================================

  Future<bool> isFirstRunCompleted(
    SharedPreferences preferences,
  ) async {
    return preferences.getBool(
          firstRunCompletedKey,
        ) ??
        false;
  }

  Future<void> setFirstRunCompleted(
    SharedPreferences preferences,
    bool value,
  ) async {
    await preferences.setBool(
      firstRunCompletedKey,
      value,
    );
  }
}