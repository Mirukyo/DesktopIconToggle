import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'bridge.dart';
import 'widgets/app_shell.dart';
import 'widgets/hotkey_dialogs.dart';
import 'widgets/message_bubble.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences =
      await SharedPreferences.getInstance();

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(920, 680),
    minimumSize: Size(820, 600),
    center: true,
    title: '桌面图标隐藏工具',
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(
    windowOptions,
    () async {
      await windowManager.center();
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(
    DesktopIconToggleApp(
      preferences: preferences,
    ),
  );
}

// ============================================================
// Application
// ============================================================

class DesktopIconToggleApp extends StatelessWidget {
  final SharedPreferences preferences;

  const DesktopIconToggleApp({
    super.key,
    required this.preferences,
  });

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final ColorScheme lightScheme =
            lightDynamic ??
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF0078D4),
              brightness: Brightness.light,
            );

        final ColorScheme darkScheme =
            darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF0078D4),
              brightness: Brightness.dark,
            );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '桌面图标隐藏工具',
          themeMode: ThemeMode.system,

          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightScheme,
            brightness: Brightness.light,
            fontFamily: 'Microsoft YaHei',
            scaffoldBackgroundColor:
                lightScheme.surface,
          ),

          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkScheme,
            brightness: Brightness.dark,
            fontFamily: 'Microsoft YaHei',
            scaffoldBackgroundColor:
                darkScheme.surface,
          ),

          home: DesktopIconToggleShell(
            preferences: preferences,
          ),
        );
      },
    );
  }
}

// ============================================================
// Main shell / state controller
// ============================================================

class DesktopIconToggleShell
    extends StatefulWidget {
  final SharedPreferences preferences;

  const DesktopIconToggleShell({
    super.key,
    required this.preferences,
  });

  @override
  State<DesktopIconToggleShell> createState() =>
      _DesktopIconToggleShellState();
}

class _DesktopIconToggleShellState
    extends State<DesktopIconToggleShell> {
  static const MethodChannel _nativeChannel =
      MethodChannel(
    'desktop_icon_toggle/native',
  );

  static const String _firstRunCompletedKey =
      'first_run_completed';

  int _selectedIndex = 0;

  bool doubleClickEnabled = true;
  bool startupEnabled = false;
  bool trayEnabled = true;
  bool hotkeyEnabled = true;

  String hotkey = 'Ctrl + Alt + H';

  int hotkeyModifiers = 3;
  int hotkeyVk = 0x48;

  bool desktopIconsHidden = false;

  bool loading = true;
  bool saving = false;

  bool _showFirstRunGuide = false;

  @override
  void initState() {
    super.initState();

    _nativeChannel.setMethodCallHandler(
      _handleNativeMethodCall,
    );

    _loadSettings();
  }

  @override
  void dispose() {
    _nativeChannel.setMethodCallHandler(null);
    super.dispose();
  }

  // ==========================================================
  // Native -> Flutter
  // ==========================================================

  Future<dynamic> _handleNativeMethodCall(
    MethodCall call,
  ) async {
    if (call.method ==
        'desktopIconStateChanged') {
      final arguments = call.arguments;

      if (arguments is bool &&
          mounted) {
        setState(() {
          desktopIconsHidden =
              arguments;
        });
      }
    }

    return null;
  }

  // ==========================================================
  // Read current desktop state once
  // ==========================================================

  Future<void> _syncDesktopIconState() async {
    try {
      final hidden =
          await NativeBridge
              .getDesktopIconState();

      if (!mounted) {
        return;
      }

      setState(() {
        desktopIconsHidden =
            hidden;
      });
    } catch (_) {
      // Ignore one-time synchronization failures.
    }
  }

  // ==========================================================
  // Load settings
  // ==========================================================

  Future<void> _loadSettings() async {
    try {
      final settings =
          await NativeBridge.getSettings();

      final actualDesktopState =
          await NativeBridge
              .getDesktopIconState();

      if (!mounted) {
        return;
      }

      setState(() {
        doubleClickEnabled =
            settings[
                    'doubleClickEnabled']
                as bool? ??
                true;

        startupEnabled =
            settings[
                    'startupEnabled']
                as bool? ??
                false;

        trayEnabled =
            settings[
                    'trayEnabled']
                as bool? ??
                true;

        hotkeyEnabled =
            settings[
                    'hotkeyEnabled']
                as bool? ??
                true;

        hotkeyModifiers =
            settings[
                    'hotkeyModifiers']
                as int? ??
                3;

        hotkeyVk =
            settings[
                    'hotkeyVk']
                as int? ??
                0x48;

        hotkey =
            _formatHotkey(
          hotkeyModifiers,
          hotkeyVk,
        );

        desktopIconsHidden =
            actualDesktopState;

        loading = false;
      });

      final completed =
          widget.preferences.getBool(
                _firstRunCompletedKey,
              ) ??
              false;

      if (!completed &&
          mounted) {
        WidgetsBinding.instance
            .addPostFrameCallback(
          (_) {
            if (mounted) {
              _openFirstRunGuide();
            }
          },
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
      });

      _showMessage(
        '读取设置失败',
        error: true,
      );
    }
  }

  // ==========================================================
  // Toggle desktop icons
  // ==========================================================

  Future<void> _toggleDesktopIcons() async {
    try {
      final success =
          await NativeBridge
              .toggleDesktopIcons();

      if (!mounted) {
        return;
      }

      if (!success) {
        _showMessage(
          '操作失败',
          error: true,
        );

        return;
      }

      // One-shot fallback synchronization.
      await _syncDesktopIconState();

      if (!mounted) {
        return;
      }

      _showMessage(
        desktopIconsHidden
            ? '桌面图标已隐藏'
            : '桌面图标已显示',
      );
    } catch (_) {
      if (mounted) {
        _showMessage(
          '操作失败',
          error: true,
        );
      }
    }
  }

  // ==========================================================
  // First-run hotkey guide
  // ==========================================================

  Future<void> _openFirstRunGuide() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _showFirstRunGuide = true;
    });

    final result =
        await showDialog<
            HotkeyGuideResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return FirstRunHotkeyDialog(
          initialDisplay: hotkey,
        );
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _showFirstRunGuide = false;
    });

    if (result == null ||
        result.skipped) {
      setState(() {
        hotkeyEnabled = false;
      });

      await NativeBridge
          .setHotkeyEnabled(
        false,
      );

      await widget.preferences
          .setBool(
        _firstRunCompletedKey,
        true,
      );

      if (mounted) {
        _showMessage(
          '已跳过快捷键设置，之后可在设置中开启',
        );
      }

      return;
    }

    setState(() {
      hotkeyModifiers =
          result.modifiers;

      hotkeyVk =
          result.virtualKey;

      hotkey =
          result.display;

      hotkeyEnabled = true;
    });

    try {
      final success =
          await NativeBridge
              .saveSettings(
        <String, dynamic>{
          'doubleClickEnabled':
              doubleClickEnabled,
          'startupEnabled':
              startupEnabled,
          'trayEnabled':
              trayEnabled,
          'hotkeyEnabled':
              true,
          'hotkeyModifiers':
              hotkeyModifiers,
          'hotkeyVk':
              hotkeyVk,
        },
      );

      if (!success) {
        if (mounted) {
          _showMessage(
            '快捷键保存失败',
            error: true,
          );
        }

        return;
      }

      await widget.preferences
          .setBool(
        _firstRunCompletedKey,
        true,
      );

      if (mounted) {
        _showMessage(
          '快捷键已启用',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          '快捷键保存失败',
          error: true,
        );
      }
    }
  }

  // ==========================================================
  // Reopen first-run guide
  // ==========================================================

  Future<void>
      _resetFirstRunGuide() async {
    await widget.preferences
        .setBool(
      _firstRunCompletedKey,
      false,
    );

    await _openFirstRunGuide();
  }

  // ==========================================================
  // Save settings
  // ==========================================================

  Future<void> _applySettings() async {
    if (saving) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final success =
          await NativeBridge
              .saveSettings(
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

      if (!mounted) {
        return;
      }

      setState(() {
        saving = false;
      });

      if (success) {
        await _syncDesktopIconState();

        if (mounted) {
          _showMessage(
            '设置已保存',
          );
        }
      } else {
        _showMessage(
          '设置保存失败',
          error: true,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        saving = false;
      });

      _showMessage(
        '设置保存失败',
        error: true,
      );
    }
  }

  // ==========================================================
  // Restore defaults
  // ==========================================================

  void _restoreDefaults() {
    setState(() {
      doubleClickEnabled = true;
      startupEnabled = false;
      trayEnabled = true;
      hotkeyEnabled = true;

      hotkeyModifiers = 3;
      hotkeyVk = 0x48;

      hotkey =
          'Ctrl + Alt + H';
    });

    _showMessage(
      '已恢复默认设置',
    );
  }

  // ==========================================================
  // Exit settings
  // ==========================================================

  Future<void> _exitSettings() async {
    await windowManager.hide();
  }

  // ==========================================================
  // Change hotkey
  // ==========================================================

  Future<void> _changeHotkey() async {
    final result =
        await showDialog<HotkeyResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return HotkeyRecorderDialog(
          initialDisplay:
              hotkey,
        );
      },
    );

    if (!mounted ||
        result == null) {
      return;
    }

    setState(() {
      hotkeyModifiers =
          result.modifiers;

      hotkeyVk =
          result.virtualKey;

      hotkey =
          result.display;
    });

    _showMessage(
      '快捷键已修改，点击“应用”后生效',
    );
  }

  // ==========================================================
  // Message
  // ==========================================================

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    final overlay =
        Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) {
        return AnimatedMessageBubble(
            message: message,
            type: error
                ? MessageBubbleType.error
                : MessageBubbleType.success,
          onFinished: () {
            if (entry.mounted) {
              entry.remove();
            }
          },
        );
      },
    );

    overlay.insert(entry);
  }

  // ==========================================================
  // Hotkey format
  // ==========================================================

  String _formatHotkey(
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
  // Build
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: AppShell(
        selectedIndex:
            _selectedIndex,

        doubleClickEnabled:
            doubleClickEnabled,

        startupEnabled:
            startupEnabled,

        trayEnabled:
            trayEnabled,

        hotkeyEnabled:
            hotkeyEnabled,

        hotkey:
            hotkey,

        desktopIconsHidden:
            desktopIconsHidden,

        saving:
            saving,

        showFirstRunGuide:
            _showFirstRunGuide,

        onToggleDesktopIcons:
            _toggleDesktopIcons,

        onDoubleClickChanged:
            (value) {
          setState(() {
            doubleClickEnabled =
                value;
          });
        },

        onStartupChanged:
            (value) {
          setState(() {
            startupEnabled =
                value;
          });
        },

        onTrayChanged:
            (value) {
          setState(() {
            trayEnabled =
                value;
          });
        },

        onHotkeyEnabledChanged:
            (value) {
          setState(() {
            hotkeyEnabled =
                value;
          });
        },

        onChangeHotkey:
            _changeHotkey,

        onOpenFirstRunGuide:
            _resetFirstRunGuide,

        onRestoreDefaults:
            _restoreDefaults,

        onExitSettings:
            _exitSettings,

        onApplySettings:
            _applySettings,

        onNavigationChanged:
            (index) {
          setState(() {
            _selectedIndex =
                index;
          });

          _syncDesktopIconState();
        },
      ),
    );
  }
}