#include "TrayManager.h"

#include "DesktopManager.h"
#include "Resources.h"
#include "SettingsWindow.h"

#include <windows.h>
#include <shellapi.h>

#pragma comment(lib, "shell32.lib")

namespace
{
    HWND g_mainWindow = nullptr;
    bool g_trayVisible = false;

    // ========================================================
    // Load our application icon
    // ========================================================

    HICON LoadAppIcon()
    {
        wchar_t path[MAX_PATH]{};

        DWORD length =
            GetModuleFileNameW(
                nullptr,
                path,
                MAX_PATH
            );

        if (length == 0 ||
            length >= MAX_PATH)
        {
            return nullptr;
        }

        wchar_t* slash =
            wcsrchr(
                path,
                L'\\'
            );

        if (!slash)
        {
            return nullptr;
        }

        *(slash + 1) = L'\0';

        wcscat_s(
            path,
            MAX_PATH,
            L"resources\\desktop_icon.ico"
        );

        return static_cast<HICON>(
            LoadImageW(
                nullptr,
                path,
                IMAGE_ICON,
                0,
                0,
                LR_LOADFROMFILE |
                LR_DEFAULTSIZE |
                LR_SHARED
            )
        );
    }

    // ========================================================
    // Add tray icon
    // ========================================================

    bool AddTrayIcon()
    {
        if (!g_mainWindow)
        {
            return false;
        }

        NOTIFYICONDATAW nid{};

        nid.cbSize =
            sizeof(NOTIFYICONDATAW);

        nid.hWnd =
            g_mainWindow;

        nid.uID =
            1;

        nid.uFlags =
            NIF_MESSAGE |
            NIF_ICON |
            NIF_TIP;

        nid.uCallbackMessage =
            WM_TRAYICON;

        nid.hIcon =
            LoadAppIcon();

        if (!nid.hIcon)
        {
            return false;
        }

        wcscpy_s(
            nid.szTip,
            APP_NAME
        );

        if (!Shell_NotifyIconW(
                NIM_ADD,
                &nid))
        {
            DestroyIcon(
                nid.hIcon
            );

            return false;
        }

        g_trayVisible =
            true;

        return true;
    }

    // ========================================================
    // Remove tray icon
    // ========================================================

    void RemoveTrayIcon()
    {
        if (!g_mainWindow ||
            !g_trayVisible)
        {
            return;
        }

        NOTIFYICONDATAW nid{};

        nid.cbSize =
            sizeof(NOTIFYICONDATAW);

        nid.hWnd =
            g_mainWindow;

        nid.uID =
            1;

        Shell_NotifyIconW(
            NIM_DELETE,
            &nid
        );

        g_trayVisible =
            false;
    }
}

// ============================================================
// Initialize tray manager
// ============================================================

bool InitializeTrayManager(
    HWND mainWindow)
{
    if (!mainWindow)
    {
        return false;
    }

    g_mainWindow =
        mainWindow;

    return AddTrayIcon();
}

// ============================================================
// Shutdown tray manager
// ============================================================

void ShutdownTrayManager()
{
    RemoveTrayIcon();

    g_mainWindow =
        nullptr;
}

// ============================================================
// Show tray menu
// ============================================================

void ShowTrayMenu()
{
    if (!g_mainWindow)
    {
        return;
    }

    POINT point{};

    if (!GetCursorPos(
            &point))
    {
        return;
    }

    HMENU menu =
        CreatePopupMenu();

    if (!menu)
    {
        return;
    }

    AppendMenuW(
        menu,
        MF_STRING,
        ID_TRAY_TOGGLE,
        L"隐藏/显示桌面图标"
    );

    AppendMenuW(
        menu,
        MF_STRING,
        ID_TRAY_SETTINGS,
        L"设置"
    );

    AppendMenuW(
        menu,
        MF_SEPARATOR,
        0,
        nullptr
    );

    AppendMenuW(
        menu,
        MF_STRING,
        ID_TRAY_EXIT,
        L"退出"
    );

    SetForegroundWindow(
        g_mainWindow
    );

    TrackPopupMenu(
        menu,
        TPM_RIGHTBUTTON,
        point.x,
        point.y,
        0,
        g_mainWindow,
        nullptr
    );

    DestroyMenu(
        menu
    );

    PostMessageW(
        g_mainWindow,
        WM_NULL,
        0,
        0
    );
}

// ============================================================
// Update tray visibility
// ============================================================

void UpdateTrayVisibility(
    bool visible)
{
    if (!g_mainWindow)
    {
        return;
    }

    if (visible)
    {
        if (!g_trayVisible)
        {
            AddTrayIcon();
        }
    }
    else
    {
        if (g_trayVisible)
        {
            RemoveTrayIcon();
        }
    }
}