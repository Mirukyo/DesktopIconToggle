import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'bridge.dart';

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
// Main shell
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

  static const String _firstRunCompletedKey =
      'first_run_completed';

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
      final arguments =
          call.arguments;

      if (arguments is bool &&
          mounted) {
        setState(() {
          desktopIconsHidden =
              arguments;
        });
      }

      return null;
    }

    return null;
  }

  // ==========================================================
  // Read current desktop state once
  //
  // This is NOT polling.
  // It is only used during startup or explicit UI actions.
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

      if (!completed && mounted) {
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

      // --------------------------------------------------------
      // C++ will normally notify Flutter immediately.
      // Keep one direct read as a fallback for this action.
      // This is a one-shot read, not polling.
      // --------------------------------------------------------

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
  // First-run guide
  // ==========================================================

  Future<void> _openFirstRunGuide() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _showFirstRunGuide =
          true;
    });

    final result =
        await showDialog<
            _HotkeyGuideResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _FirstRunHotkeyDialog(
          initialDisplay:
              hotkey,
        );
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _showFirstRunGuide =
          false;
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
        await showDialog<_HotkeyResult>(
      context: context,
      barrierDismissible:
          false,
      builder: (context) {
        return _HotkeyRecorderDialog(
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
        return _AnimatedMessageBubble(
          message: message,
          error: error,
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
  Widget build(
    BuildContext context,
  ) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _NavigationPane(
            selectedIndex:
                _selectedIndex,
            onSelected:
                (index) {
              setState(() {
                _selectedIndex =
                    index;
              });

              // One-time refresh when changing pages.
              _syncDesktopIconState();
            },
          ),

          Expanded(
            child:
                _buildContent(),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // Content
  // ==========================================================

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomePage();

      case 1:
        return _buildSettingsPage();

      default:
        return _buildHomePage();
    }
  }

  // ==========================================================
  // Home
  // ==========================================================

  Widget _buildHomePage() {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final statusColor =
        desktopIconsHidden
            ? colors.primary
            : colors.tertiary;

    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        32,
        32,
        32,
        40,
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Text(
            '首页',
            style:
                theme
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w600,
                ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            '快速查看和控制桌面图标状态',
            style:
                theme
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                  color:
                      colors
                          .onSurfaceVariant,
                ),
          ),

          const SizedBox(
            height: 28,
          ),

          Card(
            clipBehavior:
                Clip.antiAlias,

            child:
                Padding(
              padding:
                  const EdgeInsets.all(
                28,
              ),

              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration:
                            BoxDecoration(
                          color:
                              statusColor
                                  .withValues(
                            alpha: 0.12,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            16,
                          ),
                        ),
                        child:
                            Icon(
                          desktopIconsHidden
                              ? Icons
                                  .visibility_off_rounded
                              : Icons
                                  .desktop_windows_rounded,
                          color:
                              statusColor,
                          size: 26,
                        ),
                      ),

                      const SizedBox(
                        width: 16,
                      ),

                      Expanded(
                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              '桌面图标',
                              style:
                                  theme
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              desktopIconsHidden
                                  ? '当前已隐藏'
                                  : '当前可见',
                              style:
                                  theme
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                color:
                                    statusColor,
                                fontWeight:
                                    FontWeight
                                        .w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 26,
                  ),

                  Text(
                    desktopIconsHidden
                        ? '桌面图标目前处于隐藏状态。'
                        : '桌面图标目前正常显示。',
                    style:
                        theme
                            .textTheme
                            .bodyLarge,
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  FilledButton.icon(
                    onPressed:
                        _toggleDesktopIcons,
                    icon:
                        Icon(
                      desktopIconsHidden
                          ? Icons
                              .visibility_rounded
                          : Icons
                              .visibility_off_rounded,
                    ),
                    label:
                        Text(
                      desktopIconsHidden
                          ? '显示桌面图标'
                          : '隐藏桌面图标',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(
            height: 24,
          ),

          Text(
            '快捷操作',
            style:
                theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w600,
                ),
          ),

          const SizedBox(
            height: 12,
          ),

          Row(
            children: [
              Expanded(
                child:
                    _QuickInfoCard(
                  icon:
                      Icons
                          .touch_app_rounded,
                  title:
                      '双击桌面',
                  value:
                      doubleClickEnabled
                          ? '已开启'
                          : '已关闭',
                  color:
                      doubleClickEnabled
                          ? colors.primary
                          : colors
                              .onSurfaceVariant,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child:
                    _QuickInfoCard(
                  icon:
                      Icons
                          .keyboard_rounded,
                  title:
                      '全局快捷键',
                  value:
                      hotkeyEnabled
                          ? hotkey
                          : '已关闭',
                  color:
                      hotkeyEnabled
                          ? colors.primary
                          : colors
                              .onSurfaceVariant,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child:
                    _QuickInfoCard(
                  icon:
                      Icons
                          .notifications_active_rounded,
                  title:
                      '托盘',
                  value:
                      trayEnabled
                          ? '已开启'
                          : '已关闭',
                  color:
                      trayEnabled
                          ? colors.primary
                          : colors
                              .onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 24,
          ),

          Card(
            child:
                Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),

              child:
                  Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color:
                          colors.primary,
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  const Expanded(
                    child:
                        Text(
                      '程序正在运行',
                    ),
                  ),

                  Text(
                    startupEnabled
                        ? '开机启动已开启'
                        : '开机启动未开启',
                    style:
                        theme
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color:
                              colors
                                  .onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // Settings
  // ==========================================================

  Widget _buildSettingsPage() {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        32,
        32,
        32,
        40,
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Text(
            '设置',
            style:
                theme
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w600,
                ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            '自定义桌面图标隐藏工具的行为',
            style:
                theme
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                  color:
                      colors
                          .onSurfaceVariant,
                ),
          ),

          const SizedBox(
            height: 28,
          ),

          _SectionCard(
            title: '常规',
            child:
                Column(
              children: [
                _SettingTile(
                  title:
                      '启用双击桌面隐藏/显示',
                  subtitle:
                      '双击桌面空白区域切换图标显示状态',
                  value:
                      doubleClickEnabled,
                  onChanged:
                      (value) {
                    setState(() {
                      doubleClickEnabled =
                          value;
                    });
                  },
                ),

                const Divider(
                  height: 1,
                ),

                _SettingTile(
                  title:
                      '开机自动启动',
                  subtitle:
                      '登录 Windows 后自动运行',
                  value:
                      startupEnabled,
                  onChanged:
                      (value) {
                    setState(() {
                      startupEnabled =
                          value;
                    });
                  },
                ),

                const Divider(
                  height: 1,
                ),

                _SettingTile(
                  title:
                      '显示系统托盘图标',
                  subtitle:
                      '在任务栏通知区域显示应用图标',
                  value:
                      trayEnabled,
                  onChanged:
                      (value) {
                    setState(() {
                      trayEnabled =
                          value;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          _SectionCard(
            title: '快捷键',
            child:
                Column(
              children: [
                _SettingTile(
                  title:
                      '启用快捷键',
                  subtitle:
                      '使用快捷键快速隐藏或显示桌面图标',
                  value:
                      hotkeyEnabled,
                  onChanged:
                      (value) {
                    setState(() {
                      hotkeyEnabled =
                          value;
                    });
                  },
                ),

                const Divider(
                  height: 1,
                ),

                ListTile(
                  contentPadding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  title:
                      const Text(
                    '当前快捷键',
                  ),
                  subtitle:
                      Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 4,
                    ),
                    child:
                        Text(
                      hotkey,
                    ),
                  ),
                  trailing:
                      FilledButton.tonal(
                    onPressed:
                        hotkeyEnabled
                            ? _changeHotkey
                            : null,
                    child:
                        const Text(
                      '修改',
                    ),
                  ),
                ),

                const Divider(
                  height: 1,
                ),

                ListTile(
                  contentPadding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading:
                      const Icon(
                    Icons
                        .keyboard_alt_outlined,
                  ),
                  title:
                      const Text(
                    '重新显示首次快捷键设置',
                  ),
                  subtitle:
                      const Text(
                    '重新进行快捷键初始配置',
                  ),
                  trailing:
                      TextButton(
                    onPressed:
                        _showFirstRunGuide
                            ? null
                            : _resetFirstRunGuide,
                    child:
                        const Text(
                      '打开',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          Row(
            children: [
              OutlinedButton(
                onPressed:
                    saving
                        ? null
                        : _restoreDefaults,
                child:
                    const Text(
                  '恢复默认',
                ),
              ),

              const Spacer(),

              TextButton(
                onPressed:
                    saving
                        ? null
                        : _exitSettings,
                child:
                    const Text(
                  '退出设置',
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              FilledButton(
                onPressed:
                    saving
                        ? null
                        : _applySettings,
                child:
                    saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Text(
                            '应用',
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Navigation pane
// ============================================================

class _NavigationPane
    extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int>
      onSelected;

  const _NavigationPane({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(
      BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      width: 190,

      decoration:
          BoxDecoration(
        color:
            colors
                .surfaceContainerLow,

        border:
            Border(
          right:
              BorderSide(
            color:
                colors
                    .outlineVariant
                    .withValues(
              alpha: 0.45,
            ),
          ),
        ),
      ),

      child:
          Column(
        children: [
          const SizedBox(
            height: 24,
          ),

          Padding(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 18,
            ),

            child:
                Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration:
                      BoxDecoration(
                    color:
                        colors.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child:
                      Icon(
                    Icons
                        .desktop_windows_rounded,
                    size: 22,
                    color:
                        colors
                            .onPrimaryContainer,
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child:
                      Text(
                    '桌面图标\n隐藏工具',
                    style:
                        theme
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          _NavigationItem(
            icon:
                Icons.home_rounded,
            label:
                '首页',
            selected:
                selectedIndex == 0,
            onTap:
                () => onSelected(0),
          ),

          _NavigationItem(
            icon:
                Icons.settings_rounded,
            label:
                '设置',
            selected:
                selectedIndex == 1,
            onTap:
                () => onSelected(1),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

// ============================================================
// Navigation item
// ============================================================

class _NavigationItem
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 2,
      ),

      child:
          Material(
        color:
            selected
                ? colors
                    .secondaryContainer
                : Colors.transparent,

        borderRadius:
            BorderRadius.circular(
          14,
        ),

        child:
            InkWell(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          onTap:
              onTap,

          child:
              Padding(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 14,
              vertical: 12,
            ),

            child:
                Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                  color:
                      selected
                          ? colors
                              .onSecondaryContainer
                          : colors
                              .onSurfaceVariant,
                ),

                const SizedBox(
                  width: 12,
                ),

                Text(
                  label,
                  style:
                      TextStyle(
                    fontWeight:
                        selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                    color:
                        selected
                            ? colors
                                .onSecondaryContainer
                            : colors
                                .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Quick info card
// ============================================================

class _QuickInfoCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _QuickInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context) {
    final theme =
        Theme.of(context);

    return Card(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),

        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Icon(
              icon,
              color:
                  color,
              size:
                  24,
            ),

            const SizedBox(
              height: 16,
            ),

            Text(
              title,
              style:
                  theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    color:
                        theme
                            .colorScheme
                            .onSurfaceVariant,
                  ),
            ),

            const SizedBox(
              height: 5,
            ),

            Text(
              value,
              maxLines:
                  1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Section card
// ============================================================

class _SectionCard
    extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(
      BuildContext context) {
    final theme =
        Theme.of(context);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Padding(
          padding:
              const EdgeInsets.only(
            left: 4,
            bottom: 10,
          ),

          child:
              Text(
            title,
            style:
                theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w600,
                ),
          ),
        ),

        Card(
          clipBehavior:
              Clip.antiAlias,
          margin:
              EdgeInsets.zero,
          child:
              child,
        ),
      ],
    );
  }
}

// ============================================================
// Setting tile
// ============================================================

class _SettingTile
    extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>
      onChanged;

  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(
      BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 12,
      ),

      title:
          Text(
        title,
        style:
            const TextStyle(
          fontWeight:
              FontWeight.w500,
        ),
      ),

      subtitle:
          Padding(
        padding:
            const EdgeInsets.only(
          top: 4,
        ),

        child:
            Text(
          subtitle,
          style:
              TextStyle(
            color:
                colors
                    .onSurfaceVariant,
          ),
        ),
      ),

      trailing:
          Switch(
        value:
            value,
        onChanged:
            onChanged,
      ),
    );
  }
}

// ============================================================
// Hotkey result
// ============================================================

class _HotkeyResult {
  final int modifiers;
  final int virtualKey;
  final String display;

  const _HotkeyResult({
    required this.modifiers,
    required this.virtualKey,
    required this.display,
  });
}

// ============================================================
// First-run result
// ============================================================

class _HotkeyGuideResult {
  final bool skipped;
  final int modifiers;
  final int virtualKey;
  final String display;

  const _HotkeyGuideResult({
    required this.skipped,
    this.modifiers = 0,
    this.virtualKey = 0,
    this.display = '',
  });
}

// ============================================================
// First-run hotkey dialog
// ============================================================

class _FirstRunHotkeyDialog
    extends StatefulWidget {
  final String initialDisplay;

  const _FirstRunHotkeyDialog({
    required this.initialDisplay,
  });

  @override
  State<_FirstRunHotkeyDialog> createState() =>
      _FirstRunHotkeyDialogState();
}

class _FirstRunHotkeyDialogState
    extends State<_FirstRunHotkeyDialog> {
  final FocusNode _focusNode =
      FocusNode();

  int _modifiers = 0;
  int? _virtualKey;

  String _display =
      '请按下你想使用的快捷键';

  bool _valid = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.handled;
    }

    final keyboard =
        HardwareKeyboard.instance;

    int modifiers = 0;

    if (keyboard.isAltPressed) {
      modifiers |= 1;
    }

    if (keyboard.isControlPressed) {
      modifiers |= 2;
    }

    if (keyboard.isShiftPressed) {
      modifiers |= 4;
    }

    if (keyboard.isMetaPressed) {
      modifiers |= 8;
    }

    if (_isModifierKey(
      event.logicalKey,
    )) {
      setState(() {
        _modifiers =
            modifiers;

        _valid = false;

        _display =
            modifiers == 0
                ? '请按下你想使用的快捷键'
                : _formatModifiers(
                    modifiers,
                  );
      });

      return KeyEventResult.handled;
    }

    final virtualKey =
        _virtualKeyFromLogicalKey(
      event.logicalKey,
    );

    if (virtualKey == null) {
      return KeyEventResult.handled;
    }

    if (modifiers == 0) {
      setState(() {
        _modifiers = 0;
        _virtualKey = null;
        _valid = false;

        _display =
            '请至少使用 Ctrl、Shift、Alt 或 Win';
      });

      return KeyEventResult.handled;
    }

    setState(() {
      _modifiers =
          modifiers;

      _virtualKey =
          virtualKey;

      _valid = true;

      _display =
          _formatHotkey(
        modifiers,
        virtualKey,
      );
    });

    return KeyEventResult.handled;
  }

  bool _isModifierKey(
    LogicalKeyboardKey key,
  ) {
    return key ==
            LogicalKeyboardKey
                .controlLeft ||
        key ==
            LogicalKeyboardKey
                .controlRight ||
        key ==
            LogicalKeyboardKey
                .shiftLeft ||
        key ==
            LogicalKeyboardKey
                .shiftRight ||
        key ==
            LogicalKeyboardKey
                .altLeft ||
        key ==
            LogicalKeyboardKey
                .altRight ||
        key ==
            LogicalKeyboardKey
                .metaLeft ||
        key ==
            LogicalKeyboardKey
                .metaRight;
  }

  String _formatModifiers(
    int modifiers,
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

    return result.join(
      ' + ',
    );
  }

  int? _virtualKeyFromLogicalKey(
    LogicalKeyboardKey key,
  ) {
    final letters =
        <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.keyA: 0x41,
      LogicalKeyboardKey.keyB: 0x42,
      LogicalKeyboardKey.keyC: 0x43,
      LogicalKeyboardKey.keyD: 0x44,
      LogicalKeyboardKey.keyE: 0x45,
      LogicalKeyboardKey.keyF: 0x46,
      LogicalKeyboardKey.keyG: 0x47,
      LogicalKeyboardKey.keyH: 0x48,
      LogicalKeyboardKey.keyI: 0x49,
      LogicalKeyboardKey.keyJ: 0x4A,
      LogicalKeyboardKey.keyK: 0x4B,
      LogicalKeyboardKey.keyL: 0x4C,
      LogicalKeyboardKey.keyM: 0x4D,
      LogicalKeyboardKey.keyN: 0x4E,
      LogicalKeyboardKey.keyO: 0x4F,
      LogicalKeyboardKey.keyP: 0x50,
      LogicalKeyboardKey.keyQ: 0x51,
      LogicalKeyboardKey.keyR: 0x52,
      LogicalKeyboardKey.keyS: 0x53,
      LogicalKeyboardKey.keyT: 0x54,
      LogicalKeyboardKey.keyU: 0x55,
      LogicalKeyboardKey.keyV: 0x56,
      LogicalKeyboardKey.keyW: 0x57,
      LogicalKeyboardKey.keyX: 0x58,
      LogicalKeyboardKey.keyY: 0x59,
      LogicalKeyboardKey.keyZ: 0x5A,
    };

    final letter =
        letters[key];

    if (letter != null) {
      return letter;
    }

    final numbers =
        <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.digit0: 0x30,
      LogicalKeyboardKey.digit1: 0x31,
      LogicalKeyboardKey.digit2: 0x32,
      LogicalKeyboardKey.digit3: 0x33,
      LogicalKeyboardKey.digit4: 0x34,
      LogicalKeyboardKey.digit5: 0x35,
      LogicalKeyboardKey.digit6: 0x36,
      LogicalKeyboardKey.digit7: 0x37,
      LogicalKeyboardKey.digit8: 0x38,
      LogicalKeyboardKey.digit9: 0x39,
    };

    final number =
        numbers[key];

    if (number != null) {
      return number;
    }

    final functions =
        <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.f1: 0x70,
      LogicalKeyboardKey.f2: 0x71,
      LogicalKeyboardKey.f3: 0x72,
      LogicalKeyboardKey.f4: 0x73,
      LogicalKeyboardKey.f5: 0x74,
      LogicalKeyboardKey.f6: 0x75,
      LogicalKeyboardKey.f7: 0x76,
      LogicalKeyboardKey.f8: 0x77,
      LogicalKeyboardKey.f9: 0x78,
      LogicalKeyboardKey.f10: 0x79,
      LogicalKeyboardKey.f11: 0x7A,
      LogicalKeyboardKey.f12: 0x7B,
    };

    return functions[key];
  }

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

  void _skip() {
    Navigator.of(context).pop(
      const _HotkeyGuideResult(
        skipped: true,
      ),
    );
  }

  void _confirm() {
    if (!_valid ||
        _virtualKey == null) {
      return;
    }

    Navigator.of(context).pop(
      _HotkeyGuideResult(
        skipped: false,
        modifiers:
            _modifiers,
        virtualKey:
            _virtualKey!,
        display:
            _display,
      ),
    );
  }

  @override
  Widget build(
      BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return AlertDialog(
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          24,
        ),
      ),

      title:
          const Text(
        '设置快捷键',
      ),

      content:
          SizedBox(
        width: 430,

        child:
            Focus(
          focusNode:
              _focusNode,
          autofocus:
              true,
          onKeyEvent:
              _handleKeyEvent,

          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              Icon(
                Icons.keyboard_rounded,
                size: 48,
                color:
                    colors.primary,
              ),

              const SizedBox(
                height: 16,
              ),

              Text(
                '设置一个快捷键，快速隐藏或显示桌面图标。',
                textAlign:
                    TextAlign.center,
                style:
                    theme
                        .textTheme
                        .bodyLarge,
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                '不需要快捷键可以直接跳过，之后也可以在设置中开启。',
                textAlign:
                    TextAlign.center,
                style:
                    theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color:
                          colors
                              .onSurfaceVariant,
                    ),
              ),

              const SizedBox(
                height: 24,
              ),

              AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds:
                      180,
                ),

                width:
                    double.infinity,

                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      colors
                          .surfaceContainerHighest,

                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),

                  border:
                      Border.all(
                    color:
                        _valid
                            ? colors
                                .primary
                            : colors
                                .outlineVariant,

                    width:
                        _valid
                            ? 2
                            : 1,
                  ),
                ),

                child:
                    Text(
                  _display,
                  textAlign:
                      TextAlign.center,
                  style:
                      theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                    fontWeight:
                        FontWeight.w600,

                    color:
                        _valid
                            ? colors.primary
                            : colors
                                .onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed:
              _skip,
          child:
              const Text(
            '跳过',
          ),
        ),

        FilledButton(
          onPressed:
              _valid
                  ? _confirm
                  : null,
          child:
              const Text(
            '保存并启用',
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Normal hotkey recorder
// ============================================================

class _HotkeyRecorderDialog
    extends StatefulWidget {
  final String initialDisplay;

  const _HotkeyRecorderDialog({
    required this.initialDisplay,
  });

  @override
  State<_HotkeyRecorderDialog> createState() =>
      _HotkeyRecorderDialogState();
}

class _HotkeyRecorderDialogState
    extends State<_HotkeyRecorderDialog> {
  final FocusNode _focusNode =
      FocusNode();

  int _modifiers = 0;
  int? _virtualKey;

  String _display =
      '请按下新的快捷键';

  bool _valid = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.handled;
    }

    final keyboard =
        HardwareKeyboard.instance;

    int modifiers = 0;

    if (keyboard.isAltPressed) {
      modifiers |= 1;
    }

    if (keyboard.isControlPressed) {
      modifiers |= 2;
    }

    if (keyboard.isShiftPressed) {
      modifiers |= 4;
    }

    if (keyboard.isMetaPressed) {
      modifiers |= 8;
    }

    if (_isModifierKey(
      event.logicalKey,
    )) {
      setState(() {
        _modifiers =
            modifiers;

        _valid = false;

        _display =
            _formatModifiers(
          modifiers,
        );
      });

      return KeyEventResult.handled;
    }

    final virtualKey =
        _virtualKeyFromLogicalKey(
      event.logicalKey,
    );

    if (virtualKey == null) {
      return KeyEventResult.handled;
    }

    if (modifiers == 0) {
      setState(() {
        _valid = false;
        _virtualKey = null;

        _display =
            '请至少使用 Ctrl、Shift、Alt 或 Win';
      });

      return KeyEventResult.handled;
    }

    setState(() {
      _modifiers =
          modifiers;

      _virtualKey =
          virtualKey;

      _valid = true;

      _display =
          _formatHotkey(
        modifiers,
        virtualKey,
      );
    });

    return KeyEventResult.handled;
  }

  bool _isModifierKey(
    LogicalKeyboardKey key,
  ) {
    return key ==
            LogicalKeyboardKey
                .controlLeft ||
        key ==
            LogicalKeyboardKey
                .controlRight ||
        key ==
            LogicalKeyboardKey
                .shiftLeft ||
        key ==
            LogicalKeyboardKey
                .shiftRight ||
        key ==
            LogicalKeyboardKey
                .altLeft ||
        key ==
            LogicalKeyboardKey
                .altRight ||
        key ==
            LogicalKeyboardKey
                .metaLeft ||
        key ==
            LogicalKeyboardKey
                .metaRight;
  }

  String _formatModifiers(
    int modifiers,
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

    return result.join(
      ' + ',
    );
  }

  int? _virtualKeyFromLogicalKey(
    LogicalKeyboardKey key,
  ) {
    final letters =
        <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.keyA: 0x41,
      LogicalKeyboardKey.keyB: 0x42,
      LogicalKeyboardKey.keyC: 0x43,
      LogicalKeyboardKey.keyD: 0x44,
      LogicalKeyboardKey.keyE: 0x45,
      LogicalKeyboardKey.keyF: 0x46,
      LogicalKeyboardKey.keyG: 0x47,
      LogicalKeyboardKey.keyH: 0x48,
      LogicalKeyboardKey.keyI: 0x49,
      LogicalKeyboardKey.keyJ: 0x4A,
      LogicalKeyboardKey.keyK: 0x4B,
      LogicalKeyboardKey.keyL: 0x4C,
      LogicalKeyboardKey.keyM: 0x4D,
      LogicalKeyboardKey.keyN: 0x4E,
      LogicalKeyboardKey.keyO: 0x4F,
      LogicalKeyboardKey.keyP: 0x50,
      LogicalKeyboardKey.keyQ: 0x51,
      LogicalKeyboardKey.keyR: 0x52,
      LogicalKeyboardKey.keyS: 0x53,
      LogicalKeyboardKey.keyT: 0x54,
      LogicalKeyboardKey.keyU: 0x55,
      LogicalKeyboardKey.keyV: 0x56,
      LogicalKeyboardKey.keyW: 0x57,
      LogicalKeyboardKey.keyX: 0x58,
      LogicalKeyboardKey.keyY: 0x59,
      LogicalKeyboardKey.keyZ: 0x5A,
    };

    final letter =
        letters[key];

    if (letter != null) {
      return letter;
    }

    final numbers =
        <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.digit0: 0x30,
      LogicalKeyboardKey.digit1: 0x31,
      LogicalKeyboardKey.digit2: 0x32,
      LogicalKeyboardKey.digit3: 0x33,
      LogicalKeyboardKey.digit4: 0x34,
      LogicalKeyboardKey.digit5: 0x35,
      LogicalKeyboardKey.digit6: 0x36,
      LogicalKeyboardKey.digit7: 0x37,
      LogicalKeyboardKey.digit8: 0x38,
      LogicalKeyboardKey.digit9: 0x39,
    };

    final number =
        numbers[key];

    if (number != null) {
      return number;
    }

    final functions =
        <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.f1: 0x70,
      LogicalKeyboardKey.f2: 0x71,
      LogicalKeyboardKey.f3: 0x72,
      LogicalKeyboardKey.f4: 0x73,
      LogicalKeyboardKey.f5: 0x74,
      LogicalKeyboardKey.f6: 0x75,
      LogicalKeyboardKey.f7: 0x76,
      LogicalKeyboardKey.f8: 0x77,
      LogicalKeyboardKey.f9: 0x78,
      LogicalKeyboardKey.f10: 0x79,
      LogicalKeyboardKey.f11: 0x7A,
      LogicalKeyboardKey.f12: 0x7B,
    };

    return functions[key];
  }

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

  void _confirm() {
    if (!_valid ||
        _virtualKey == null) {
      return;
    }

    Navigator.of(context).pop(
      _HotkeyResult(
        modifiers:
            _modifiers,
        virtualKey:
            _virtualKey!,
        display:
            _display,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return AlertDialog(
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          24,
        ),
      ),

      title:
          const Text(
        '修改快捷键',
      ),

      content:
          SizedBox(
        width: 420,

        child:
            Focus(
          focusNode:
              _focusNode,
          autofocus:
              true,
          onKeyEvent:
              _handleKeyEvent,

          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              Icon(
                Icons.keyboard_rounded,
                size: 42,
                color:
                    colors.primary,
              ),

              const SizedBox(
                height: 20,
              ),

              Text(
                '请按下新的快捷键',
                style:
                    theme.textTheme.titleMedium
                        ?.copyWith(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                '例如 Ctrl + Alt + H',
                style:
                    theme.textTheme.bodyMedium
                        ?.copyWith(
                  color:
                      colors
                          .onSurfaceVariant,
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 200,
                ),

                width:
                    double.infinity,

                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      colors
                          .surfaceContainerHighest,

                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),

                  border:
                      Border.all(
                    color:
                        _valid
                            ? colors.primary
                            : colors
                                .outlineVariant,
                    width:
                        _valid ? 2 : 1,
                  ),
                ),

                child:
                    Center(
                  child:
                      Text(
                    _display,
                    textAlign:
                        TextAlign.center,
                    style:
                        theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w600,
                          color:
                              _valid
                                  ? colors.primary
                                  : colors
                                      .onSurfaceVariant,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop();
          },
          child:
              const Text(
            '取消',
          ),
        ),

        FilledButton(
          onPressed:
              _valid
                  ? _confirm
                  : null,
          child:
              const Text(
            '确定',
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Animated message bubble
// ============================================================

class _AnimatedMessageBubble
    extends StatefulWidget {
  final String message;
  final bool error;
  final VoidCallback onFinished;

  const _AnimatedMessageBubble({
    required this.message,
    required this.error,
    required this.onFinished,
  });

  @override
  State<_AnimatedMessageBubble>
      createState() =>
          _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState
    extends State<_AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController
      _controller;

  late final Animation<double>
      _progress;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 360,
      ),
    );

    _progress =
        CurvedAnimation(
      parent: _controller,
      curve:
          Curves.easeOutCubic,
    );

    _controller.forward();

    Future.delayed(
      const Duration(
        milliseconds: 1500,
      ),
      () async {
        if (!mounted) {
          return;
        }

        await _controller.reverse();

        if (mounted) {
          widget.onFinished();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final iconColor =
        widget.error
            ? colors.error
            : colors.primary;

    final textStyle =
        theme.textTheme.bodyMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w500,
              color:
                  colors
                      .onSurfaceVariant,
            ) ??
            TextStyle(
              fontSize: 14,
              fontWeight:
                  FontWeight.w500,
              color:
                  colors
                      .onSurfaceVariant,
            );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 32,

      child:
          IgnorePointer(
        child:
            Center(
          child:
              AnimatedBuilder(
            animation:
                _progress,

            builder: (
              context,
              child,
            ) {
              final progress =
                  _progress.value;

              final painter =
                  TextPainter(
                text:
                    TextSpan(
                  text:
                      widget.message,
                  style:
                      textStyle,
                ),
                textDirection:
                    TextDirection.ltr,
                maxLines: 1,
              )..layout();

              final targetWidth =
                  46 +
                  14 +
                  painter.width +
                  18;

              const double minWidth =
                  46;

              final width =
                  minWidth +
                  (targetWidth -
                          minWidth) *
                      progress;

              const double height =
                  46;

              final radius =
                  23 -
                  (9 * progress);

              return Container(
                width:
                    width,
                height:
                    height,

                decoration:
                    BoxDecoration(
                  color:
                      colors
                          .surfaceContainerHighest,

                  borderRadius:
                      BorderRadius.circular(
                    radius,
                  ),

                  border:
                      Border.all(
                    color:
                        colors
                            .outlineVariant
                            .withValues(
                      alpha: 0.45,
                    ),
                  ),

                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black
                              .withValues(
                        alpha:
                            theme.brightness ==
                                    Brightness.dark
                                ? 0.30
                                : 0.12,
                      ),
                      blurRadius: 18,
                      offset:
                          const Offset(
                        0,
                        6,
                      ),
                    ),
                  ],
                ),

                child:
                    ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    radius,
                  ),

                  child:
                      Stack(
                    alignment:
                        Alignment.center,

                    children: [
                      Positioned(
                        left: 12,
                        child:
                            Icon(
                          widget.error
                              ? Icons
                                  .error_outline_rounded
                              : Icons
                                  .check_circle_outline_rounded,
                          size: 22,
                          color:
                              iconColor,
                        ),
                      ),

                      Positioned(
                        left: 42,
                        right: 10,
                        child:
                            Opacity(
                          opacity:
                              Curves.easeOut
                                  .transform(
                                progress,
                              ),
                          child:
                              Text(
                            widget.message,
                            maxLines: 1,
                            overflow:
                                TextOverflow.clip,
                            textAlign:
                                TextAlign.center,
                            style:
                                textStyle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}