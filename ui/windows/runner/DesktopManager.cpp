#include "DesktopManager.h"
#include "bridge.h"

#include <windows.h>

// ============================================================
// Find desktop SHELLDLL_DefView
// ============================================================

HWND GetDesktopShellView()
{
    HWND progman = FindWindowW(
        L"Progman",
        L"Program Manager"
    );

    if (!progman)
    {
        return nullptr;
    }

    HWND shellView = FindWindowExW(
        progman,
        nullptr,
        L"SHELLDLL_DefView",
        nullptr
    );

    if (shellView)
    {
        return shellView;
    }

    HWND workerW = nullptr;

    while (true)
    {
        workerW = FindWindowExW(
            GetDesktopWindow(),
            workerW,
            L"WorkerW",
            nullptr
        );

        if (!workerW)
        {
            break;
        }

        shellView = FindWindowExW(
            workerW,
            nullptr,
            L"SHELLDLL_DefView",
            nullptr
        );

        if (shellView)
        {
            return shellView;
        }
    }

    return nullptr;
}

// ============================================================
// Find desktop icon ListView
// ============================================================

namespace
{
    HWND GetDesktopListView()
    {
        HWND shellView =
            GetDesktopShellView();

        if (!shellView)
        {
            return nullptr;
        }

        return FindWindowExW(
            shellView,
            nullptr,
            L"SysListView32",
            nullptr
        );
    }
}

// ============================================================
// Get current desktop icon state
//
// true  = hidden
// false = visible
// ============================================================

bool AreDesktopIconsHidden()
{
    HWND listView =
        GetDesktopListView();

    if (!listView)
    {
        return false;
    }

    return IsWindowVisible(
        listView
    ) == FALSE;
}

// ============================================================
// Toggle desktop icons
// ============================================================

void ToggleDesktopIcons()
{
    HWND listView =
        GetDesktopListView();

    if (!listView)
    {
        return;
    }

    const bool hidden =
        IsWindowVisible(
            listView
        ) == FALSE;

    ShowWindow(
        listView,
        hidden
            ? SW_SHOW
            : SW_HIDE
    );

    UpdateWindow(
        listView
    );

    // --------------------------------------------------------
    // Immediately notify Flutter.
    // No polling required.
    // --------------------------------------------------------

    NotifyDesktopIconStateChanged();
}