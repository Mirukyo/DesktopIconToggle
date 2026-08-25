#pragma once

#include <windows.h>
#include <string>

struct AppSettings
{
    // 双击桌面隐藏/显示
    bool doubleClickEnabled = true;

    // 开机自动启动
    bool startupEnabled = false;

    // 显示系统托盘图标
    bool trayEnabled = true;

    // 启用全局快捷键
    bool hotkeyEnabled = true;

    // 快捷键修饰键
    // 默认：Ctrl + Alt
    UINT hotkeyModifiers =
        MOD_CONTROL | MOD_ALT;

    // 快捷键主键
    // 默认：H
    UINT hotkeyVk = 'H';
};

// ============================================================
// Settings
// ============================================================

// 读取设置
void LoadSettings();

// 保存设置
void SaveSettings();

// 恢复默认设置
void ResetSettings();

// 获取当前设置
const AppSettings& GetSettings();

// 修改当前设置
AppSettings& GetSettingsMutable();

// ============================================================
// Startup
// ============================================================

// 设置是否开机自动启动
void SetStartupEnabled(bool enabled);

// 获取当前程序 EXE 路径
std::wstring GetExecutablePath();

// 检查 Windows 启动项是否指向当前 EXE
bool IsStartupPathCurrent();