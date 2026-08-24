import 'package:flutter/material.dart';

import '../widgets/setting_widgets.dart';

class HomePage extends StatelessWidget {
  final bool desktopIconsHidden;
  final bool doubleClickEnabled;
  final bool startupEnabled;
  final bool trayEnabled;
  final bool hotkeyEnabled;
  final String hotkey;
  final VoidCallback onToggleDesktopIcons;

  const HomePage({
    super.key,
    required this.desktopIconsHidden,
    required this.doubleClickEnabled,
    required this.startupEnabled,
    required this.trayEnabled,
    required this.hotkeyEnabled,
    required this.hotkey,
    required this.onToggleDesktopIcons,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final statusColor =
        desktopIconsHidden
            ? colors.primary
            : colors.tertiary;

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
            '首页',
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
            '快速查看和控制桌面图标状态',
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
          // Desktop icon status
          // ==================================================

          Card(
            clipBehavior:
                Clip.antiAlias,
            child: Padding(
              padding:
                  const EdgeInsets.all(
                28,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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
                        child: Icon(
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
                        child: Column(
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
                        theme.textTheme.bodyLarge,
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  FilledButton.icon(
                    onPressed:
                        onToggleDesktopIcons,
                    icon: Icon(
                      desktopIconsHidden
                          ? Icons
                              .visibility_rounded
                          : Icons
                              .visibility_off_rounded,
                    ),
                    label: Text(
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

          // ==================================================
          // Quick actions
          // ==================================================

          Text(
            '快捷操作',
            style:
                theme.textTheme.titleMedium
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
                child: QuickInfoCard(
                  icon:
                      Icons.touch_app_rounded,
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
                child: QuickInfoCard(
                  icon:
                      Icons.keyboard_rounded,
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
                child: QuickInfoCard(
                  icon: Icons
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

          // ==================================================
          // Running status
          // ==================================================

          Card(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              child: Row(
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
                    child: Text(
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
                          color: colors
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
}