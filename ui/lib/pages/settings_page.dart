import 'package:flutter/material.dart';

import '../widgets/setting_widgets.dart';

class SettingsPage extends StatelessWidget {
  final bool doubleClickEnabled;
  final bool startupEnabled;
  final bool trayEnabled;
  final bool hotkeyEnabled;

  final String hotkey;

  final bool saving;
  final bool showFirstRunGuide;

  final ValueChanged<bool> onDoubleClickChanged;
  final ValueChanged<bool> onStartupChanged;
  final ValueChanged<bool> onTrayChanged;
  final ValueChanged<bool> onHotkeyEnabledChanged;

  final VoidCallback onChangeHotkey;
  final VoidCallback onOpenFirstRunGuide;
  final VoidCallback onRestoreDefaults;
  final VoidCallback onExitSettings;
  final VoidCallback onApplySettings;

  const SettingsPage({
    super.key,
    required this.doubleClickEnabled,
    required this.startupEnabled,
    required this.trayEnabled,
    required this.hotkeyEnabled,
    required this.hotkey,
    required this.saving,
    required this.showFirstRunGuide,
    required this.onDoubleClickChanged,
    required this.onStartupChanged,
    required this.onTrayChanged,
    required this.onHotkeyEnabledChanged,
    required this.onChangeHotkey,
    required this.onOpenFirstRunGuide,
    required this.onRestoreDefaults,
    required this.onExitSettings,
    required this.onApplySettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        32,
        32,
        32,
        40,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ==================================================
          // Page title
          // ==================================================

          Text(
            '设置',
            style:
                theme.textTheme.headlineMedium
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
                theme.textTheme.bodyLarge
                    ?.copyWith(
              color:
                  colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          // ==================================================
          // General
          // ==================================================

          SectionCard(
            title: '常规',
            child: Column(
              children: [
                SettingTile(
                  title:
                      '启用双击桌面隐藏/显示',
                  subtitle:
                      '双击桌面空白区域切换图标显示状态',
                  value:
                      doubleClickEnabled,
                  onChanged:
                      onDoubleClickChanged,
                ),

                const Divider(
                  height: 1,
                ),

                SettingTile(
                  title:
                      '开机自动启动',
                  subtitle:
                      '登录 Windows 后自动运行',
                  value:
                      startupEnabled,
                  onChanged:
                      onStartupChanged,
                ),

                const Divider(
                  height: 1,
                ),

                SettingTile(
                  title:
                      '显示系统托盘图标',
                  subtitle:
                      '在任务栏通知区域显示应用图标',
                  value:
                      trayEnabled,
                  onChanged:
                      onTrayChanged,
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          // ==================================================
          // Hotkey
          // ==================================================

          SectionCard(
            title: '快捷键',
            child: Column(
              children: [
                SettingTile(
                  title:
                      '启用快捷键',
                  subtitle:
                      '使用快捷键快速隐藏或显示桌面图标',
                  value:
                      hotkeyEnabled,
                  onChanged:
                      onHotkeyEnabledChanged,
                ),

                const Divider(
                  height: 1,
                ),

                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(
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
                            ? onChangeHotkey
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
                      const EdgeInsets.symmetric(
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
                        showFirstRunGuide
                            ? null
                            : onOpenFirstRunGuide,
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

          // ==================================================
          // Bottom actions
          // ==================================================

          Row(
            children: [
              OutlinedButton(
                onPressed:
                    saving
                        ? null
                        : onRestoreDefaults,
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
                        : onExitSettings,
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
                        : onApplySettings,
                child:
                    saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
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