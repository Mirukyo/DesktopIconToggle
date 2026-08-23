#pragma once

#include <windows.h>

// ============================================================
// MouseManager
// ============================================================

// 初始化鼠标检测
bool InitializeMouseManager(HWND mainWindow);

// 停止鼠标检测
void ShutdownMouseManager();

// 开始/停止双击检测
void SetDoubleClickDetectionEnabled(bool enabled);