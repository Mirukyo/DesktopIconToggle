import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'bridge.dart';
import 'controllers/desktop_controller.dart';
import 'controllers/navigation_controller.dart';
import 'controllers/settings_controller.dart';
import 'widgets/app_shell.dart';
import 'widgets/hotkey_dialogs.dart';
import 'widgets/message_bubble.dart';

// ============================================================
// Main application shell / coordinator
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
  // ----------------------------------------------------------
  // Controllers
  // ----------------------------------------------------------

  final NavigationController _navigationController =
      NavigationController();

  final DesktopController _desktopController =
      DesktopController();

  final SettingsController _settingsController =
      SettingsController();

  // ----------------------------------------------------------
  // UI state
  // ----------------------------------------------------------

  bool loading = true;
  bool _showFirstRunGuide = false;

  // ==========================================================
  // Lifecycle
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _desktopController.startListening(
      () {
        if (mounted) {
          setState(() {});
        }
      },
    );

    _initialize();
  }

  @override
  void dispose() {
    _desktopController.stopListening();
    super.dispose();
  }

  // ==========================================================
  // Initialize application state
  // ==========================================================

  Future<void> _initialize() async {
    try {
      await _settingsController.load();
      await _desktopController.loadState();

      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
      });

      final completed =
          await _settingsController
              .isFirstRunCompleted(
        widget.preferences,
      );

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
          await _desktopController.toggle();

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

      setState(() {});

      _showMessage(
        _desktopController.desktopIconsHidden
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
        await showDialog<HotkeyGuideResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return FirstRunHotkeyDialog(
          initialDisplay:
              _settingsController.hotkey,
        );
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _showFirstRunGuide = false;
    });

    // --------------------------------------------------------
    // User skipped the first-run guide.
    // --------------------------------------------------------

    if (result == null ||
        result.skipped) {
      _settingsController.hotkeyEnabled =
          false;

      await NativeBridge.setHotkeyEnabled(
        false,
      );

      await _settingsController
          .setFirstRunCompleted(
        widget.preferences,
        true,
      );

      if (mounted) {
        setState(() {});

        _showMessage(
          '已跳过快捷键设置，之后可在设置中开启',
        );
      }

      return;
    }

    // --------------------------------------------------------
    // Save selected hotkey.
    // --------------------------------------------------------

    _settingsController.setHotkey(
      modifiers: result.modifiers,
      virtualKey: result.virtualKey,
      display: result.display,
    );

    _settingsController.hotkeyEnabled =
        true;

    try {
      final success =
          await NativeBridge.saveSettings(
        <String, dynamic>{
          'doubleClickEnabled':
              _settingsController
                  .doubleClickEnabled,
          'startupEnabled':
              _settingsController
                  .startupEnabled,
          'trayEnabled':
              _settingsController
                  .trayEnabled,
          'hotkeyEnabled':
              true,
          'hotkeyModifiers':
              _settingsController
                  .hotkeyModifiers,
          'hotkeyVk':
              _settingsController
                  .hotkeyVk,
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

      await _settingsController
          .setFirstRunCompleted(
        widget.preferences,
        true,
      );

      if (mounted) {
        setState(() {});

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

  Future<void> _resetFirstRunGuide() async {
    await _settingsController
        .setFirstRunCompleted(
      widget.preferences,
      false,
    );

    await _openFirstRunGuide();
  }

  // ==========================================================
  // Save settings
  // ==========================================================

  Future<void> _applySettings() async {
    if (_settingsController.saving) {
      return;
    }

    setState(() {
      _settingsController.saving =
          true;
    });

    try {
      final success =
          await _settingsController.save();

      if (!mounted) {
        return;
      }

      setState(() {
        _settingsController.saving =
            false;
      });

      if (success) {
        await _desktopController.syncState();

        if (mounted) {
          setState(() {});

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
        _settingsController.saving =
            false;
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
    _settingsController.restoreDefaults();

    setState(() {});

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
              _settingsController.hotkey,
        );
      },
    );

    if (!mounted ||
        result == null) {
      return;
    }

    _settingsController.setHotkey(
      modifiers: result.modifiers,
      virtualKey: result.virtualKey,
      display: result.display,
    );

    setState(() {});

    _showMessage(
      '快捷键已修改，点击“应用”后生效',
    );
  }

  // ==========================================================
  // Navigation
  // ==========================================================

  void _selectPage(int index) {
    _navigationController.select(
      index,
    );

    setState(() {});

    _desktopController.syncState().then(
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  // ==========================================================
  // Message bubble
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
  // Build
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: AppShell(
        selectedIndex:
            _navigationController
                .selectedIndex,

        doubleClickEnabled:
            _settingsController
                .doubleClickEnabled,

        startupEnabled:
            _settingsController
                .startupEnabled,

        trayEnabled:
            _settingsController
                .trayEnabled,

        hotkeyEnabled:
            _settingsController
                .hotkeyEnabled,

        hotkey:
            _settingsController.hotkey,

        desktopIconsHidden:
            _desktopController
                .desktopIconsHidden,

        saving:
            _settingsController.saving,

        showFirstRunGuide:
            _showFirstRunGuide,

        onToggleDesktopIcons:
            _toggleDesktopIcons,

        onDoubleClickChanged:
            (value) {
          _settingsController
              .doubleClickEnabled = value;

          setState(() {});
        },

        onStartupChanged:
            (value) {
          _settingsController
              .startupEnabled = value;

          setState(() {});
        },

        onTrayChanged:
            (value) {
          _settingsController
              .trayEnabled = value;

          setState(() {});
        },

        onHotkeyEnabledChanged:
            (value) {
          _settingsController
              .hotkeyEnabled = value;

          setState(() {});
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
            _selectPage,
      ),
    );
  }
}