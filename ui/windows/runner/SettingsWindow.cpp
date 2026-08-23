#include "SettingsWindow.h"

#include "Resources.h"
#include "Settings.h"
#include "TrayManager.h"
#include "MouseManager.h"
#include "ModernControls.h"

#include <windows.h>
#include <commctrl.h>
#include <dwmapi.h>
#include <uxtheme.h>

#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "uxtheme.lib")

namespace
{
    HWND g_mainWindow = nullptr;
    HWND g_settingsWindow = nullptr;

    HWND g_checkDoubleClick = nullptr;
    HWND g_checkStartup = nullptr;
    HWND g_checkTray = nullptr;
    HWND g_checkHotkey = nullptr;

    HWND g_hotkeyControl = nullptr;

    HWND g_applyButton = nullptr;
    HWND g_cancelButton = nullptr;
    HWND g_defaultButton = nullptr;

    HFONT g_titleFont = nullptr;
    HFONT g_sectionFont = nullptr;
    HFONT g_smallFont = nullptr;

    COLORREF g_accentColor =
        RGB(0, 120, 215);

    bool g_darkMode = false;
    bool g_isWindows11 = false;

    // ========================================================
    // Windows version
    // ========================================================

    bool IsWindows11OrNewer()
    {
        RTL_OSVERSIONINFOW version{};

        version.dwOSVersionInfoSize =
            sizeof(version);

        using RtlGetVersionPtr =
            LONG(WINAPI*)(
                PRTL_OSVERSIONINFOW
            );

        HMODULE ntdll =
            GetModuleHandleW(
                L"ntdll.dll"
            );

        if (!ntdll)
            return false;

        auto RtlGetVersion =
            reinterpret_cast<RtlGetVersionPtr>(
                GetProcAddress(
                    ntdll,
                    "RtlGetVersion"
                )
            );

        if (!RtlGetVersion)
            return false;

        if (RtlGetVersion(&version) != 0)
            return false;

        return version.dwMajorVersion >= 10 &&
               version.dwBuildNumber >= 22000;
    }

    // ========================================================
    // Dark mode
    // ========================================================

    bool IsDarkMode()
    {
        HKEY key = nullptr;

        if (RegOpenKeyExW(
                HKEY_CURRENT_USER,
                L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
                0,
                KEY_READ,
                &key
            ) != ERROR_SUCCESS)
        {
            return false;
        }

        DWORD value = 1;
        DWORD size = sizeof(value);

        LONG result =
            RegQueryValueExW(
                key,
                L"AppsUseLightTheme",
                nullptr,
                nullptr,
                reinterpret_cast<LPBYTE>(&value),
                &size
            );

        RegCloseKey(key);

        return result == ERROR_SUCCESS &&
               value == 0;
    }

    // ========================================================
    // Accent color
    // ========================================================

    COLORREF GetAccentColor()
    {
        HKEY key = nullptr;

        if (RegOpenKeyExW(
                HKEY_CURRENT_USER,
                L"Software\\Microsoft\\Windows\\DWM",
                0,
                KEY_READ,
                &key
            ) != ERROR_SUCCESS)
        {
            return RGB(0, 120, 215);
        }

        DWORD color = 0;
        DWORD size = sizeof(color);

        LONG result =
            RegQueryValueExW(
                key,
                L"AccentColor",
                nullptr,
                nullptr,
                reinterpret_cast<LPBYTE>(&color),
                &size
            );

        RegCloseKey(key);

        if (result != ERROR_SUCCESS)
            return RGB(0, 120, 215);

        return RGB(
            static_cast<BYTE>(color & 0xFF),
            static_cast<BYTE>((color >> 8) & 0xFF),
            static_cast<BYTE>((color >> 16) & 0xFF)
        );
    }

    // ========================================================
    // Theme colors
    // ========================================================

    COLORREF WindowBackground()
    {
        return g_darkMode
            ? RGB(32, 32, 32)
            : RGB(246, 246, 246);
    }

    COLORREF PrimaryText()
    {
        return g_darkMode
            ? RGB(245, 245, 245)
            : RGB(32, 32, 32);
    }

    COLORREF SecondaryText()
    {
        return g_darkMode
            ? RGB(190, 190, 190)
            : RGB(96, 96, 96);
    }

    // ========================================================
    // Font
    // ========================================================

    HFONT CreateUIFont(
        int size,
        int weight)
    {
        return CreateFontW(
            size,
            0,
            0,
            0,
            weight,
            FALSE,
            FALSE,
            FALSE,
            DEFAULT_CHARSET,
            OUT_DEFAULT_PRECIS,
            CLIP_DEFAULT_PRECIS,
            CLEARTYPE_QUALITY,
            DEFAULT_PITCH | FF_DONTCARE,
            L"Microsoft YaHei UI"
        );
    }

    void CreateFonts()
    {
        g_titleFont =
            CreateUIFont(
                24,
                FW_SEMIBOLD
            );

        g_sectionFont =
            CreateUIFont(
                18,
                FW_SEMIBOLD
            );

        g_smallFont =
            CreateUIFont(
                14,
                FW_NORMAL
            );
    }

    void DestroyFonts()
    {
        if (g_titleFont)
        {
            DeleteObject(
                g_titleFont
            );

            g_titleFont = nullptr;
        }

        if (g_sectionFont)
        {
            DeleteObject(
                g_sectionFont
            );

            g_sectionFont = nullptr;
        }

        if (g_smallFont)
        {
            DeleteObject(
                g_smallFont
            );

            g_smallFont = nullptr;
        }
    }

    void SetFont(
        HWND control,
        HFONT font)
    {
        if (control && font)
        {
            SendMessageW(
                control,
                WM_SETFONT,
                reinterpret_cast<WPARAM>(
                    font
                ),
                TRUE
            );
        }
    }

    // ========================================================
    // Modern DWM style
    // ========================================================

    void ApplyModernWindowStyle(
        HWND hwnd)
    {
        if (!hwnd)
            return;

        g_isWindows11 =
            IsWindows11OrNewer();

        g_darkMode =
            IsDarkMode();

        g_accentColor =
            GetAccentColor();

        SetModernAccentColor(
            g_accentColor
        );

        if (!g_isWindows11)
            return;

        DWM_WINDOW_CORNER_PREFERENCE corner =
            DWMWCP_ROUND;

        DwmSetWindowAttribute(
            hwnd,
            DWMWA_WINDOW_CORNER_PREFERENCE,
            &corner,
            sizeof(corner)
        );

        BOOL dark =
            g_darkMode
                ? TRUE
                : FALSE;

        DwmSetWindowAttribute(
            hwnd,
            DWMWA_USE_IMMERSIVE_DARK_MODE,
            &dark,
            sizeof(dark)
        );

        DWM_SYSTEMBACKDROP_TYPE backdrop =
            DWMSBT_MAINWINDOW;

        DwmSetWindowAttribute(
            hwnd,
            DWMWA_SYSTEMBACKDROP_TYPE,
            &backdrop,
            sizeof(backdrop)
        );
    }

    // ========================================================
    // Label
    // ========================================================

    HWND CreateLabel(
        HWND parent,
        const wchar_t* text,
        int x,
        int y,
        int width,
        int height,
        HFONT font)
    {
        HWND control =
            CreateWindowExW(
                0,
                L"STATIC",
                text,
                WS_CHILD |
                WS_VISIBLE,
                x,
                y,
                width,
                height,
                parent,
                nullptr,
                GetModuleHandleW(nullptr),
                nullptr
            );

        SetFont(
            control,
            font
        );

        return control;
    }

    // ========================================================
    // Load settings
    // ========================================================

    void LoadSettingsToControls()
    {
        const AppSettings& settings =
            GetSettings();

        SetModernToggleChecked(
            g_checkDoubleClick,
            settings.doubleClickEnabled
        );

        SetModernToggleChecked(
            g_checkStartup,
            settings.startupEnabled
        );

        SetModernToggleChecked(
            g_checkTray,
            settings.trayEnabled
        );

        SetModernToggleChecked(
            g_checkHotkey,
            settings.hotkeyEnabled
        );

        WORD hotkey =
            static_cast<WORD>(
                (settings.hotkeyModifiers << 8) |
                (settings.hotkeyVk & 0xFF)
            );

        SendMessageW(
            g_hotkeyControl,
            HKM_SETHOTKEY,
            hotkey,
            0
        );

        InvalidateRect(
            g_settingsWindow,
            nullptr,
            TRUE
        );
    }

    // ========================================================
    // Apply settings
    // ========================================================

    bool ApplySettings()
    {
        AppSettings newSettings =
            GetSettings();

        newSettings.doubleClickEnabled =
            IsModernToggleChecked(
                g_checkDoubleClick
            );

        newSettings.startupEnabled =
            IsModernToggleChecked(
                g_checkStartup
            );

        newSettings.trayEnabled =
            IsModernToggleChecked(
                g_checkTray
            );

        newSettings.hotkeyEnabled =
            IsModernToggleChecked(
                g_checkHotkey
            );

        WORD hotkey =
            static_cast<WORD>(
                SendMessageW(
                    g_hotkeyControl,
                    HKM_GETHOTKEY,
                    0,
                    0
                )
            );

        newSettings.hotkeyModifiers =
            HIBYTE(hotkey);

        newSettings.hotkeyVk =
            LOBYTE(hotkey);

        if (newSettings.hotkeyEnabled &&
            (newSettings.hotkeyModifiers == 0 ||
             newSettings.hotkeyVk == 0))
        {
            MessageBoxW(
                g_settingsWindow,
                L"请设置一个有效的快捷键。",
                APP_NAME,
                MB_OK |
                MB_ICONWARNING
            );

            return false;
        }

        AppSettings oldSettings =
            GetSettings();

        UnregisterHotKey(
            g_mainWindow,
            ID_HOTKEY_GLOBAL
        );

        if (newSettings.hotkeyEnabled)
        {
            if (!RegisterHotKey(
                    g_mainWindow,
                    ID_HOTKEY_GLOBAL,
                    newSettings.hotkeyModifiers,
                    newSettings.hotkeyVk
                ))
            {
                if (oldSettings.hotkeyEnabled)
                {
                    RegisterHotKey(
                        g_mainWindow,
                        ID_HOTKEY_GLOBAL,
                        oldSettings.hotkeyModifiers,
                        oldSettings.hotkeyVk
                    );
                }

                MessageBoxW(
                    g_settingsWindow,
                    L"快捷键注册失败。\n\n"
                    L"可能是这个快捷键已经被其他程序占用。",
                    APP_NAME,
                    MB_OK |
                    MB_ICONWARNING
                );

                return false;
            }
        }

        GetSettingsMutable() =
            newSettings;

        SetDoubleClickDetectionEnabled(
            newSettings.doubleClickEnabled
        );

        SetStartupEnabled(
            newSettings.startupEnabled
        );

        SaveSettings();

        if (oldSettings.trayEnabled !=
            newSettings.trayEnabled)
        {
            UpdateTrayVisibility(
                newSettings.trayEnabled
            );
        }

        MessageBoxW(
            g_settingsWindow,
            L"设置已保存。",
            APP_NAME,
            MB_OK |
            MB_ICONINFORMATION
        );

        return true;
    }

    // ========================================================
    // Restore defaults
    // ========================================================

    void RestoreDefaults()
    {
        GetSettingsMutable() =
            AppSettings{};

        LoadSettingsToControls();

        MessageBoxW(
            g_settingsWindow,
            L"默认设置已恢复。\n\n"
            L"点击“应用”后生效。",
            APP_NAME,
            MB_OK |
            MB_ICONINFORMATION
        );
    }

    // ========================================================
    // Paint background
    // ========================================================

    void PaintBackground(
        HWND hwnd,
        HDC hdc)
    {
        RECT rect{};

        GetClientRect(
            hwnd,
            &rect
        );

        HBRUSH brush =
            CreateSolidBrush(
                WindowBackground()
            );

        FillRect(
            hdc,
            &rect,
            brush
        );

        DeleteObject(
            brush
        );

        HPEN pen =
            CreatePen(
                PS_SOLID,
                1,
                g_darkMode
                    ? RGB(62, 62, 62)
                    : RGB(226, 226, 226)
            );

        HGDIOBJ oldPen =
            SelectObject(
                hdc,
                pen
            );

        MoveToEx(
            hdc,
            28,
            98,
            nullptr
        );

        LineTo(
            hdc,
            rect.right - 28,
            98
        );

        SelectObject(
            hdc,
            oldPen
        );

        DeleteObject(
            pen
        );
    }

    // ========================================================
    // Window procedure
    // ========================================================

    LRESULT CALLBACK SettingsWindowProc(
        HWND hwnd,
        UINT message,
        WPARAM wParam,
        LPARAM lParam)
    {
        switch (message)
        {
        case WM_CREATE:
        {
            CreateFonts();

            ApplyModernWindowStyle(
                hwnd
            );

            // ------------------------------------------------
            // Header
            // ------------------------------------------------

            CreateLabel(
                hwnd,
                L"桌面图标隐藏工具",
                32,
                24,
                480,
                36,
                g_titleFont
            );

            CreateLabel(
                hwnd,
                L"设置",
                32,
                66,
                480,
                24,
                g_smallFont
            );

            // ------------------------------------------------
            // General
            // ------------------------------------------------

            CreateLabel(
                hwnd,
                L"常规",
                32,
                116,
                480,
                30,
                g_sectionFont
            );

            g_checkDoubleClick =
                CreateModernToggle(
                    hwnd,
                    ID_CHECK_DOUBLE_CLICK,
                    L"启用双击桌面隐藏/显示",
                    38,
                    154,
                    470,
                    36
                );

            g_checkStartup =
                CreateModernToggle(
                    hwnd,
                    ID_CHECK_STARTUP,
                    L"开机自动启动",
                    38,
                    198,
                    470,
                    36
                );

            g_checkTray =
                CreateModernToggle(
                    hwnd,
                    ID_CHECK_TRAY,
                    L"显示系统托盘图标",
                    38,
                    242,
                    470,
                    36
                );

            // ------------------------------------------------
            // Hotkey
            // ------------------------------------------------

            CreateLabel(
                hwnd,
                L"快捷键",
                32,
                294,
                480,
                30,
                g_sectionFont
            );

            g_checkHotkey =
                CreateModernToggle(
                    hwnd,
                    ID_CHECK_HOTKEY,
                    L"启用快捷键",
                    38,
                    330,
                    180,
                    36
                );

            g_hotkeyControl =
                CreateWindowExW(
                    0,
                    HOTKEY_CLASSW,
                    L"",
                    WS_CHILD |
                    WS_VISIBLE |
                    WS_BORDER,
                    230,
                    326,
                    220,
                    34,
                    hwnd,
                    reinterpret_cast<HMENU>(
                        static_cast<INT_PTR>(
                            ID_HOTKEY
                        )
                    ),
                    GetModuleHandleW(nullptr),
                    nullptr
                );

            SetFont(
                g_hotkeyControl,
                g_smallFont
            );

            SetWindowTheme(
                g_hotkeyControl,
                L"",
                L""
            );

            // ------------------------------------------------
            // Bottom buttons
            // ------------------------------------------------

            g_defaultButton =
                CreateModernButton(
                    hwnd,
                    ID_BUTTON_DEFAULT,
                    L"恢复默认",
                    32,
                    390,
                    112,
                    38,
                    false
                );

            g_cancelButton =
                CreateModernButton(
                    hwnd,
                    ID_BUTTON_CANCEL,
                    L"取消",
                    350,
                    390,
                    82,
                    38,
                    false
                );

            g_applyButton =
                CreateModernButton(
                    hwnd,
                    ID_BUTTON_APPLY,
                    L"应用",
                    442,
                    390,
                    82,
                    38,
                    true
                );

            LoadSettingsToControls();

            return 0;
        }

        case WM_ERASEBKGND:
            return 1;

        case WM_PAINT:
        {
            PAINTSTRUCT ps{};

            HDC hdc =
                BeginPaint(
                    hwnd,
                    &ps
                );

            PaintBackground(
                hwnd,
                hdc
            );

            EndPaint(
                hwnd,
                &ps
            );

            return 0;
        }

        case WM_COMMAND:
        {
            int controlId =
                LOWORD(wParam);

            if (controlId ==
                    ID_CHECK_DOUBLE_CLICK ||
                controlId ==
                    ID_CHECK_STARTUP ||
                controlId ==
                    ID_CHECK_TRAY ||
                controlId ==
                    ID_CHECK_HOTKEY)
            {
                return 0;
            }

            switch (controlId)
            {
            case ID_BUTTON_DEFAULT:

                RestoreDefaults();

                return 0;

            case ID_BUTTON_CANCEL:

                DestroyWindow(hwnd);

                return 0;

            case ID_BUTTON_APPLY:

                ApplySettings();

                return 0;
            }

            break;
        }

        case WM_SETTINGCHANGE:
        case WM_THEMECHANGED:

            g_darkMode =
                IsDarkMode();

            g_accentColor =
                GetAccentColor();

            ApplyModernWindowStyle(
                hwnd
            );

            SetModernAccentColor(
                g_accentColor
            );

            InvalidateRect(
                hwnd,
                nullptr,
                TRUE
            );

            return 0;

        case WM_CLOSE:

            DestroyWindow(
                hwnd
            );

            return 0;

        case WM_DESTROY:

            DestroyFonts();

            g_settingsWindow =
                nullptr;

            return 0;
        }

        return DefWindowProcW(
            hwnd,
            message,
            wParam,
            lParam
        );
    }
}

// ============================================================
// Open settings
// ============================================================

void OpenSettingsWindow(
    HWND mainWindow)
{
    g_mainWindow =
        mainWindow;

    if (g_settingsWindow)
    {
        ShowWindow(
            g_settingsWindow,
            SW_SHOWNORMAL
        );

        SetForegroundWindow(
            g_settingsWindow
        );

        return;
    }

    WNDCLASSW wc{};

    wc.lpfnWndProc =
        SettingsWindowProc;

    wc.hInstance =
        GetModuleHandleW(nullptr);

    wc.hCursor =
        LoadCursorW(
            nullptr,
            reinterpret_cast<LPCWSTR>(
                32512
            )
        );

    wc.hbrBackground =
        nullptr;

    wc.lpszClassName =
        SETTINGS_WINDOW_CLASS;

    RegisterClassW(
        &wc
    );

    // --------------------------------------------------------
    // Size
    // --------------------------------------------------------

    int width = 560;
    int height = 470;

    // --------------------------------------------------------
    // Center in work area
    // --------------------------------------------------------

    RECT workArea{};

    SystemParametersInfoW(
        SPI_GETWORKAREA,
        0,
        &workArea,
        0
    );

    int x =
        workArea.left +
        (
            workArea.right -
            workArea.left -
            width
        ) / 2;

    int y =
        workArea.top +
        (
            workArea.bottom -
            workArea.top -
            height
        ) / 2;

    // --------------------------------------------------------
    // Create
    // --------------------------------------------------------

    g_settingsWindow =
        CreateWindowExW(
            0,
            SETTINGS_WINDOW_CLASS,
            APP_NAME,
            WS_OVERLAPPED |
            WS_CAPTION |
            WS_SYSMENU |
            WS_MINIMIZEBOX,
            x,
            y,
            width,
            height,
            nullptr,
            nullptr,
            GetModuleHandleW(nullptr),
            nullptr
        );

    if (!g_settingsWindow)
    {
        MessageBoxW(
            nullptr,
            L"设置窗口创建失败。",
            APP_NAME,
            MB_OK |
            MB_ICONERROR
        );

        return;
    }

    ApplyModernWindowStyle(
        g_settingsWindow
    );

    ShowWindow(
        g_settingsWindow,
        SW_SHOWNORMAL
    );

    UpdateWindow(
        g_settingsWindow
    );

    SetForegroundWindow(
        g_settingsWindow
    );
}

// ============================================================
// Close settings
// ============================================================

void CloseSettingsWindow()
{
    if (g_settingsWindow)
    {
        DestroyWindow(
            g_settingsWindow
        );

        g_settingsWindow =
            nullptr;
    }
}

// ============================================================
// State
// ============================================================

bool IsSettingsWindowOpen()
{
    return g_settingsWindow != nullptr;
}