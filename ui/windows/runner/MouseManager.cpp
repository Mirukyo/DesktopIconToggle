#include "MouseManager.h"

#include "DesktopManager.h"
#include "Settings.h"
#include "Resources.h"

#include <oleacc.h>
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
    // Check whether the point belongs to the desktop.
    // --------------------------------------------------------

    bool IsDesktopWindowAtPoint(POINT point)
    {
        HWND hwnd = WindowFromPoint(point);

        if (!hwnd)
        {
            return false;
        }

        wchar_t className[256]{};

        HWND current = hwnd;

        while (current)
        {
            GetClassNameW(
                current,
                className,
                256
            );

            if (wcscmp(
                    className,
                    L"SysListView32") == 0)
            {
                return true;
            }

            if (wcscmp(
                    className,
                    L"SHELLDLL_DefView") == 0)
            {
                return true;
            }

            if (wcscmp(
                    className,
                    L"Progman") == 0)
            {
                return true;
            }

            if (wcscmp(
                    className,
                    L"WorkerW") == 0)
            {
                return true;
            }

            current = GetParent(current);
        }

        return false;
    }

    // --------------------------------------------------------
    // Check whether the point is on a desktop icon.
    //
    // Uses Windows Accessibility API instead of
    // LVM_HITTEST, avoiding direct ListView messaging.
    // --------------------------------------------------------

    bool IsDesktopIconAtPoint(POINT point)
    {
        IAccessible* accessible = nullptr;
        VARIANT child{};

        VariantInit(&child);

        HRESULT hr = AccessibleObjectFromPoint(
            point,
            &accessible,
            &child
        );

        if (FAILED(hr) || !accessible)
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

    bool IsEmptyDesktopArea(POINT point)
    {
        if (!IsDesktopWindowAtPoint(point))
        {
            return false;
        }

        if (IsDesktopIconAtPoint(point))
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
            GetAsyncKeyState(VK_LBUTTON);

        bool leftDown =
            (state & 0x8000) != 0;

        // Detect UP -> DOWN transition.
        if (leftDown && !g_leftDown)
        {
            POINT point{};

            if (GetCursorPos(&point))
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
                    now - g_lastClickTime <=
                        doubleClickTime &&
                    dx <=
                        GetSystemMetrics(
                            SM_CXDOUBLECLK
                        ) &&
                    dy <=
                        GetSystemMetrics(
                            SM_CYDOUBLECLK
                        );

                g_lastClickTime = now;
                g_lastClickPoint = point;

                if (doubleClick)
                {
                    // Only empty desktop areas trigger.
                    if (IsEmptyDesktopArea(point))
                    {
                        ToggleDesktopIcons();
                    }

                    // Reset after processing.
                    g_lastClickTime = 0;
                }
            }
        }

        g_leftDown = leftDown;
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

bool InitializeMouseManager(HWND mainWindow)
{
    if (!mainWindow)
    {
        return false;
    }

    g_mainWindow = mainWindow;

    g_enabled =
        GetSettings().doubleClickEnabled;

    g_leftDown = false;
    g_lastClickTime = 0;
    g_lastClickPoint = {};

    // Create a timer associated with this thread.
    g_timerId = SetTimer(
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
    g_enabled = enabled;

    if (!enabled)
    {
        g_leftDown = false;
        g_lastClickTime = 0;
    }
}