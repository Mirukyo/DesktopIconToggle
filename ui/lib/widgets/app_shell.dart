import 'package:flutter/material.dart';

import '../pages/about_page.dart';
import '../pages/home_page.dart';
import '../pages/settings_page.dart';
import 'navigation_pane.dart';

class AppShell extends StatelessWidget {
  final int selectedIndex;

  final bool doubleClickEnabled;
  final bool startupEnabled;
  final bool trayEnabled;
  final bool hotkeyEnabled;

  final String hotkey;

  final bool desktopIconsHidden;

  final bool saving;
  final bool showFirstRunGuide;

  final VoidCallback onToggleDesktopIcons;

  final ValueChanged<bool> onDoubleClickChanged;
  final ValueChanged<bool> onStartupChanged;
  final ValueChanged<bool> onTrayChanged;
  final ValueChanged<bool> onHotkeyEnabledChanged;

  final VoidCallback onChangeHotkey;
  final VoidCallback onOpenFirstRunGuide;
  final VoidCallback onRestoreDefaults;
  final VoidCallback onExitSettings;
  final VoidCallback onApplySettings;

  final ValueChanged<int> onNavigationChanged;

  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.doubleClickEnabled,
    required this.startupEnabled,
    required this.trayEnabled,
    required this.hotkeyEnabled,
    required this.hotkey,
    required this.desktopIconsHidden,
    required this.saving,
    required this.showFirstRunGuide,
    required this.onToggleDesktopIcons,
    required this.onDoubleClickChanged,
    required this.onStartupChanged,
    required this.onTrayChanged,
    required this.onHotkeyEnabledChanged,
    required this.onChangeHotkey,
    required this.onOpenFirstRunGuide,
    required this.onRestoreDefaults,
    required this.onExitSettings,
    required this.onApplySettings,
    required this.onNavigationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NavigationPane(
          selectedIndex: selectedIndex,
          onSelected: onNavigationChanged,
        ),
        Expanded(
          child: _buildPage(),
        ),
      ],
    );
  }

  Widget _buildPage() {
    switch (selectedIndex) {
      case 0:
        return HomePage(
          desktopIconsHidden:
              desktopIconsHidden,
          doubleClickEnabled:
              doubleClickEnabled,
          startupEnabled:
              startupEnabled,
          trayEnabled:
              trayEnabled,
          hotkeyEnabled:
              hotkeyEnabled,
          hotkey: hotkey,
          onToggleDesktopIcons:
              onToggleDesktopIcons,
        );

      case 1:
        return SettingsPage(
          doubleClickEnabled:
              doubleClickEnabled,
          startupEnabled:
              startupEnabled,
          trayEnabled:
              trayEnabled,
          hotkeyEnabled:
              hotkeyEnabled,
          hotkey: hotkey,
          saving: saving,
          showFirstRunGuide:
              showFirstRunGuide,
          onDoubleClickChanged:
              onDoubleClickChanged,
          onStartupChanged:
              onStartupChanged,
          onTrayChanged:
              onTrayChanged,
          onHotkeyEnabledChanged:
              onHotkeyEnabledChanged,
          onChangeHotkey:
              onChangeHotkey,
          onOpenFirstRunGuide:
              onOpenFirstRunGuide,
          onRestoreDefaults:
              onRestoreDefaults,
          onExitSettings:
              onExitSettings,
          onApplySettings:
              onApplySettings,
        );

      case 2:
        return const AboutPage();

      default:
        return HomePage(
          desktopIconsHidden:
              desktopIconsHidden,
          doubleClickEnabled:
              doubleClickEnabled,
          startupEnabled:
              startupEnabled,
          trayEnabled:
              trayEnabled,
          hotkeyEnabled:
              hotkeyEnabled,
          hotkey: hotkey,
          onToggleDesktopIcons:
              onToggleDesktopIcons,
        );
    }
  }
}