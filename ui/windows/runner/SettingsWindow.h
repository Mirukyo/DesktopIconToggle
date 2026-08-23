#pragma once

#include <windows.h>

// ============================================================
// SettingsWindow
// ============================================================

// 打开设置窗口
void OpenSettingsWindow(HWND mainWindow);

// 关闭设置窗口
void CloseSettingsWindow();

// 判断设置窗口是否已经打开
bool IsSettingsWindowOpen();