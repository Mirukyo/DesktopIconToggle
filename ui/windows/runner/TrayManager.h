#pragma once

#include <windows.h>

// ============================================================
// TrayManager
// ============================================================

// 初始化系统托盘
bool InitializeTrayManager(HWND mainWindow);

// 移除系统托盘
void ShutdownTrayManager();

// 显示托盘右键菜单
void ShowTrayMenu();

// 更新托盘图标显示状态
void UpdateTrayVisibility(bool visible);