import 'package:flutter/services.dart';

/// Flutter 与 Windows C++ 核心之间的通信接口。
class NativeBridge {
  NativeBridge._();

  static const MethodChannel _channel =
      MethodChannel(
    'desktop_icon_toggle/native',
  );

  // ==========================================================
  // 获取当前设置
  // ==========================================================

  static Future<Map<String, dynamic>> getSettings() async {
    final result =
        await _channel.invokeMethod<dynamic>(
      'getSettings',
    );

    if (result is Map) {
      return Map<String, dynamic>.from(
        result,
      );
    }

    return <String, dynamic>{};
  }

  // ==========================================================
  // 获取 Windows 当前桌面图标状态
  //
  // true  = 已隐藏
  // false = 当前可见
  // ==========================================================

  static Future<bool> getDesktopIconState() async {
    final result =
        await _channel.invokeMethod<dynamic>(
      'getDesktopIconState',
    );

    return result == true;
  }

  // ==========================================================
  // 保存全部设置
  // ==========================================================

  static Future<bool> saveSettings(
    Map<String, dynamic> settings,
  ) async {
    final result =
        await _channel.invokeMethod<dynamic>(
      'saveSettings',
      settings,
    );

    return result == true;
  }

  // ==========================================================
  // 隐藏 / 显示桌面图标
  // ==========================================================

  static Future<bool> toggleDesktopIcons() async {
    final result =
        await _channel.invokeMethod<dynamic>(
      'toggleDesktopIcons',
    );

    return result == true;
  }

  // ==========================================================
  // 双击功能
  // ==========================================================

  static Future<bool> setDoubleClickEnabled(
    bool enabled,
  ) async {
    final result =
        await _channel.invokeMethod<dynamic>(
      'setDoubleClickEnabled',
      enabled,
    );

    return result == true;
  }

  // ==========================================================
  // 开机启动
  // ==========================================================

  static Future<bool> setStartupEnabled(
    bool enabled,
  ) async {
    final result =
        await _channel.invokeMethod<dynamic>(
      'setStartupEnabled',
      enabled,
    );

    return result == true;
  }

  // ==========================================================
  // 托盘图标
  // ==========================================================

  static Future<bool> setTrayEnabled(
    bool enabled,
  ) async {
    final result =
        await _channel.invokeMethod<dynamic>(
      'setTrayEnabled',
      enabled,
    );

    return result == true;
  }

  // ==========================================================
  // 快捷键启用状态
  // ==========================================================

  static Future<bool> setHotkeyEnabled(
    bool enabled,
  ) async {
    final result =
        await _channel.invokeMethod<dynamic>(
      'setHotkeyEnabled',
      enabled,
    );

    return result == true;
  }

  // ==========================================================
  // 修改快捷键
  //
  // Windows:
  // Alt      = 1
  // Control  = 2
  // Shift    = 4
  // Win      = 8
  // ==========================================================

  static Future<bool> setHotkey({
    required int modifiers,
    required int virtualKey,
  }) async {
    final result =
        await _channel.invokeMethod<dynamic>(
      'setHotkey',
      <String, dynamic>{
        'modifiers': modifiers,
        'virtualKey': virtualKey,
      },
    );

    return result == true;
  }

  // ==========================================================
  // 真正退出整个程序
  // ==========================================================

  static Future<bool> exitApp() async {
    final result =
        await _channel.invokeMethod<dynamic>(
      'exitApp',
    );

    return result == true;
  }
}