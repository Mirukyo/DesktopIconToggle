#include "MouseManager.h"

#include "DesktopManager.h"
#include "Settings.h"
#include "Resources.h"

#include <oleacc.h>
#include <windows.h>
#include <cstdlib>

#pragma comment(lib, "oleacc.lib")

namespace
{
    // Timer ID returned by SetTimer.
    UINT_PTR g_timerId = 0;

    // Current main window.
    HWND g_mainWindow = nullptr;

    // Mouse button state.
    bool g_leftDown = false;

    // Previous click information.
    DWORD g_lastClickTime = 0;
    POINT g_lastClickPoint{};

    // Whether double-click detection is enabled.
    bool g_enabled = true;

    // --------------------------------------------------------
    // Find the desktop SysListView32.
    // --------------------------------------------------------

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

    // --------------------------------------------------------
    // Check whether hwnd belongs to the desktop Shell view.
    //
    // This works both when the desktop icon ListView is visible
    // and when it has been hidden.
    // --------------------------------------------------------

    bool IsDesktopShellWindow(
        HWND hwnd)
    {
        if (!hwnd)
        {
            return false;
        }

        HWND shellView =
            GetDesktopShellView();

        if (!shellView)
        {
            return false;
        }

        // The exact SHELLDLL_DefView itself.
        if (hwnd == shellView)
        {
            return true;
        }

        // A child of SHELLDLL_DefView.
        if (IsChild(
                shellView,
                hwnd))
        {
            return true;
        }

        // The desktop ListView.
        HWND listView =
            GetDesktopListView();

        if (listView &&
            hwnd == listView)
        {
            return true;
        }

        // Walk up the parent chain.
        HWND current =
            hwnd;

        while (current)
        {
            if (current == shellView)
            {
                return true;
            }

            current =
                GetParent(current);
        }

        // ----------------------------------------------------
        // When the desktop ListView is hidden, Windows may
        // return the WorkerW/Progman host itself.
        //
        // Find the direct parent of SHELLDLL_DefView and accept
        // only that exact host window.
        //
        // This is intentionally NOT a generic "WorkerW /
        // Progman is desktop" check, so application windows
        // cannot accidentally pass.
        // ----------------------------------------------------

        HWND shellHost =
            GetParent(shellView);

        if (shellHost &&
            hwnd == shellHost)
        {
            return true;
        }

        return false;
    }

    // --------------------------------------------------------
    // Check whether the point is inside the desktop Shell area.
    // --------------------------------------------------------

    bool IsDesktopWindowAtPoint(
        POINT point)
    {
        HWND hwnd =
            WindowFromPoint(point);

        if (!hwnd)
        {
            return false;
        }

        return IsDesktopShellWindow(
            hwnd
        );
    }

    // --------------------------------------------------------
    // Check whether point is on a desktop icon.
    //
    // Uses Windows Accessibility API instead of LVM_HITTEST.
    // --------------------------------------------------------

    bool IsDesktopIconAtPoint(
        POINT point)
    {
        // If the desktop ListView itself is hidden, there cannot
        // be a visible desktop icon under the cursor.
        HWND listView =
            GetDesktopListView();

        if (!listView ||
            !IsWindowVisible(listView))
        {
            return false;
        }

        IAccessible* accessible =
            nullptr;

        VARIANT child{};

        VariantInit(&child);

        HRESULT hr =
            AccessibleObjectFromPoint(
                point,
                &accessible,
                &child
            );

        if (FAILED(hr) ||
            !accessible)
        {
            VariantClear(&child);
            return false;
        }

        bool isIcon = false;

        if (child.vt == VT_I4 &&
            child.lVal != CHILDID_SELF)
        {
            isIcon = true;
        }

        accessible->Release();

        VariantClear(&child);

        return isIcon;
    }

    // --------------------------------------------------------
    // Check whether point is an empty desktop area.
    // --------------------------------------------------------

    bool IsEmptyDesktopArea(
        POINT point)
    {
        // The point must belong to the actual Windows desktop
        // Shell area, not an application window.
        if (!IsDesktopWindowAtPoint(
                point))
        {
            return false;
        }

        // When icons are visible, reject actual icon clicks.
        if (IsDesktopIconAtPoint(
                point))
        {
            return false;
        }

        return true;
    }

    // --------------------------------------------------------
    // Process mouse state.
    // --------------------------------------------------------

    void CheckMouse()
    {
        if (!g_enabled)
        {
            g_leftDown = false;
            g_lastClickTime = 0;
            return;
        }

        SHORT state =
            GetAsyncKeyState(
                VK_LBUTTON
            );

        bool leftDown =
            (state & 0x8000) != 0;

        // Detect UP -> DOWN transition.
        if (leftDown &&
            !g_leftDown)
        {
            POINT point{};

            if (GetCursorPos(
                    &point))
            {
                DWORD now =
                    GetTickCount();

                DWORD doubleClickTime =
                    GetDoubleClickTime();

                int dx =
                    std::abs(
                        point.x -
                        g_lastClickPoint.x
                    );

                int dy =
                    std::abs(
                        point.y -
                        g_lastClickPoint.y
                    );

                bool doubleClick =
                    g_lastClickTime != 0 &&
                    now -
                            g_lastClickTime <=
                        doubleClickTime &&
                    dx <=
                        GetSystemMetrics(
                            SM_CXDOUBLECLK
                        ) &&
                    dy <=
                        GetSystemMetrics(
                            SM_CYDOUBLECLK
                        );

                g_lastClickTime =
                    now;

                g_lastClickPoint =
                    point;

                if (doubleClick)
                {
                    if (IsEmptyDesktopArea(
                            point))
                    {
                        ToggleDesktopIcons();
                    }

                    // Reset after processing.
                    g_lastClickTime = 0;
                }
            }
        }

        g_leftDown =
            leftDown;
    }

    // --------------------------------------------------------
    // Timer callback.
    // --------------------------------------------------------

    VOID CALLBACK MouseTimerProc(
        HWND,
        UINT,
        UINT_PTR,
        DWORD)
    {
        CheckMouse();
    }
}

// ============================================================
// Initialize mouse manager
// ============================================================

bool InitializeMouseManager(
    HWND mainWindow)
{
    if (!mainWindow)
    {
        return false;
    }

    g_mainWindow =
        mainWindow;

    g_enabled =
        GetSettings()
            .doubleClickEnabled;

    g_leftDown = false;
    g_lastClickTime = 0;
    g_lastClickPoint = {};

    // Create a timer associated with this thread.
    g_timerId =
        SetTimer(
            nullptr,
            0,
            20,
            MouseTimerProc
        );

    return g_timerId != 0;
}

// ============================================================
// Shutdown mouse manager
// ============================================================

void ShutdownMouseManager()
{
    if (g_timerId != 0)
    {
        KillTimer(
            nullptr,
            g_timerId
        );

        g_timerId = 0;
    }

    g_mainWindow = nullptr;
}

// ============================================================
// Enable / disable double-click detection
// ============================================================

void SetDoubleClickDetectionEnabled(
    bool enabled)
{
    g_enabled =
        enabled;

    if (!enabled)
    {
        g_leftDown = false;
        g_lastClickTime = 0;
    }
}