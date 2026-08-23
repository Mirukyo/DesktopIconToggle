#pragma once

#include <windows.h>

// ============================================================
// DesktopManager
// ============================================================

// 获取 Windows 桌面的 SHELLDLL_DefView 窗口
HWND GetDesktopShellView();

// 隐藏 / 显示桌面图标
void ToggleDesktopIcons();

// ============================================================
// 获取当前桌面图标是否处于隐藏状态
//
// true  = 当前隐藏
// false = 当前显示
// ============================================================

bool AreDesktopIconsHidden();