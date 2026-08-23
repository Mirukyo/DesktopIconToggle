#pragma once

// ============================================================
// Application
// ============================================================

#define APP_NAME L"桌面图标隐藏工具"
#define APP_CLASS L"DesktopIconToggleWindow"
#define SETTINGS_WINDOW_CLASS L"DesktopIconToggleSettingsWindow"
#define MUTEX_NAME L"DesktopIconToggle_SingleInstance"

// ============================================================
// Windows Registry
// ============================================================

#define REG_PATH L"Software\\DesktopIconToggle"

#define RUN_REG_PATH \
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run"

// ============================================================
// Custom window messages
// ============================================================

constexpr UINT WM_TRAYICON =
    WM_APP + 1;

constexpr UINT WM_SHOW_SETTINGS =
    WM_APP + 2;

// ============================================================
// Timers
// ============================================================

constexpr UINT TIMER_MOUSE = 1;

// ============================================================
// Tray menu
// ============================================================

constexpr UINT ID_TRAY_TOGGLE = 1001;
constexpr UINT ID_TRAY_SETTINGS = 1002;
constexpr UINT ID_TRAY_EXIT = 1003;

// ============================================================
// Settings controls
// ============================================================

constexpr int ID_CHECK_DOUBLE_CLICK = 2001;
constexpr int ID_CHECK_STARTUP = 2002;
constexpr int ID_CHECK_TRAY = 2003;
constexpr int ID_CHECK_HOTKEY = 2004;

constexpr int ID_HOTKEY = 2101;

constexpr int ID_BUTTON_DEFAULT = 2201;
constexpr int ID_BUTTON_CANCEL = 2202;
constexpr int ID_BUTTON_APPLY = 2203;

// ============================================================
// Global hotkey
// ============================================================

constexpr int ID_HOTKEY_GLOBAL = 3001;

// ============================================================
// Windows Explorer command
// ============================================================

// Explorer: View -> Show desktop icons
constexpr WPARAM TOGGLE_DESKTOP_ICONS_COMMAND =
    0x7402;