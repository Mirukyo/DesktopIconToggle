#include "Settings.h"
#include "Resources.h"

#include <windows.h>

#include <string>

// ============================================================
// Internal helpers
// ============================================================

namespace
{
    constexpr DWORD kHotkeyFormatVersion = 3;

    bool ReadDWORD(
        HKEY root,
        const wchar_t* path,
        const wchar_t* name,
        DWORD& value)
    {
        HKEY key = nullptr;

        if (RegOpenKeyExW(
                root,
                path,
                0,
                KEY_READ,
                &key) != ERROR_SUCCESS)
        {
            return false;
        }

        DWORD type = 0;
        DWORD size = sizeof(DWORD);

        LONG result =
            RegQueryValueExW(
                key,
                name,
                nullptr,
                &type,
                reinterpret_cast<LPBYTE>(&value),
                &size
            );

        RegCloseKey(key);

        return result == ERROR_SUCCESS &&
               type == REG_DWORD;
    }

    void WriteDWORD(
        HKEY root,
        const wchar_t* path,
        const wchar_t* name,
        DWORD value)
    {
        HKEY key = nullptr;

        if (RegCreateKeyExW(
                root,
                path,
                0,
                nullptr,
                0,
                KEY_WRITE,
                nullptr,
                &key,
                nullptr) != ERROR_SUCCESS)
        {
            return;
        }

        RegSetValueExW(
            key,
            name,
            0,
            REG_DWORD,
            reinterpret_cast<const BYTE*>(&value),
            sizeof(value)
        );

        RegCloseKey(key);
    }

    AppSettings g_settings;
}

// ============================================================
// Get settings
// ============================================================

const AppSettings& GetSettings()
{
    return g_settings;
}

AppSettings& GetSettingsMutable()
{
    return g_settings;
}

// ============================================================
// Load settings
// ============================================================

void LoadSettings()
{
    g_settings = AppSettings{};

    DWORD value = 0;

    // --------------------------------------------------------
    // General settings
    // --------------------------------------------------------

    if (ReadDWORD(
            HKEY_CURRENT_USER,
            REG_PATH,
            L"DoubleClickEnabled",
            value))
    {
        g_settings.doubleClickEnabled =
            value != 0;
    }

    if (ReadDWORD(
            HKEY_CURRENT_USER,
            REG_PATH,
            L"StartupEnabled",
            value))
    {
        g_settings.startupEnabled =
            value != 0;
    }

    if (ReadDWORD(
            HKEY_CURRENT_USER,
            REG_PATH,
            L"TrayEnabled",
            value))
    {
        g_settings.trayEnabled =
            value != 0;
    }

    if (ReadDWORD(
            HKEY_CURRENT_USER,
            REG_PATH,
            L"HotkeyEnabled",
            value))
    {
        g_settings.hotkeyEnabled =
            value != 0;
    }

    // --------------------------------------------------------
    // Hotkey
    // --------------------------------------------------------

    DWORD modifiers = 0;
    DWORD virtualKey = 0;

    bool hasModifiers =
        ReadDWORD(
            HKEY_CURRENT_USER,
            REG_PATH,
            L"HotkeyModifiers",
            modifiers
        );

    bool hasVirtualKey =
        ReadDWORD(
            HKEY_CURRENT_USER,
            REG_PATH,
            L"HotkeyVk",
            virtualKey
        );

    // --------------------------------------------------------
    // Fix the known legacy bad value.
    //
    // Previous Flutter versions stored:
    //
    // Ctrl = 1
    // Shift = 2
    // Alt = 4
    //
    // Therefore the previous "Ctrl + Alt + H"
    // was incorrectly saved as:
    //
    // 1 + 4 = 5
    //
    // Windows interprets 5 as:
    //
    // MOD_ALT + MOD_SHIFT
    //
    // If the stored shortcut is the known old
    // Ctrl + Alt + H combination, convert it to:
    //
    // MOD_CONTROL + MOD_ALT = 2 + 1 = 3
    // --------------------------------------------------------

    if (hasModifiers &&
        hasVirtualKey &&
        modifiers == 5 &&
        virtualKey == 0x48)
    {
        modifiers = MOD_CONTROL | MOD_ALT;

        WriteDWORD(
            HKEY_CURRENT_USER,
            REG_PATH,
            L"HotkeyModifiers",
            modifiers
        );
    }

    if (hasModifiers)
    {
        g_settings.hotkeyModifiers =
            modifiers;
    }

    if (hasVirtualKey)
    {
        g_settings.hotkeyVk =
            virtualKey;
    }

    // --------------------------------------------------------
    // Mark current format.
    // --------------------------------------------------------

    WriteDWORD(
        HKEY_CURRENT_USER,
        REG_PATH,
        L"HotkeyFormatVersion",
        kHotkeyFormatVersion
    );
}

// ============================================================
// Save settings
// ============================================================

void SaveSettings()
{
    WriteDWORD(
        HKEY_CURRENT_USER,
        REG_PATH,
        L"DoubleClickEnabled",
        g_settings.doubleClickEnabled ? 1 : 0
    );

    WriteDWORD(
        HKEY_CURRENT_USER,
        REG_PATH,
        L"StartupEnabled",
        g_settings.startupEnabled ? 1 : 0
    );

    WriteDWORD(
        HKEY_CURRENT_USER,
        REG_PATH,
        L"TrayEnabled",
        g_settings.trayEnabled ? 1 : 0
    );

    WriteDWORD(
        HKEY_CURRENT_USER,
        REG_PATH,
        L"HotkeyEnabled",
        g_settings.hotkeyEnabled ? 1 : 0
    );

    WriteDWORD(
        HKEY_CURRENT_USER,
        REG_PATH,
        L"HotkeyModifiers",
        g_settings.hotkeyModifiers
    );

    WriteDWORD(
        HKEY_CURRENT_USER,
        REG_PATH,
        L"HotkeyVk",
        g_settings.hotkeyVk
    );

    WriteDWORD(
        HKEY_CURRENT_USER,
        REG_PATH,
        L"HotkeyFormatVersion",
        kHotkeyFormatVersion
    );
}

// ============================================================
// Reset settings
// ============================================================

void ResetSettings()
{
    g_settings =
        AppSettings{};
}

// ============================================================
// Get executable path
// ============================================================

std::wstring GetExecutablePath()
{
    wchar_t buffer[MAX_PATH]{};

    DWORD length =
        GetModuleFileNameW(
            nullptr,
            buffer,
            MAX_PATH
        );

    if (length == 0)
    {
        return L"";
    }

    return std::wstring(
        buffer,
        length
    );
}

// ============================================================
// Configure Windows startup
// ============================================================

void SetStartupEnabled(
    bool enabled)
{
    HKEY key = nullptr;

    if (RegCreateKeyExW(
            HKEY_CURRENT_USER,
            RUN_REG_PATH,
            0,
            nullptr,
            0,
            KEY_WRITE,
            nullptr,
            &key,
            nullptr) != ERROR_SUCCESS)
    {
        return;
    }

    const wchar_t* valueName =
        L"DesktopIconToggle";

    if (enabled)
    {
        std::wstring exe =
            GetExecutablePath();

        if (!exe.empty())
        {
            std::wstring command =
                L"\"" + exe + L"\"";

            RegSetValueExW(
                key,
                valueName,
                0,
                REG_SZ,
                reinterpret_cast<const BYTE*>(
                    command.c_str()
                ),
                static_cast<DWORD>(
                    (command.size() + 1) *
                    sizeof(wchar_t)
                )
            );
        }
    }
    else
    {
        RegDeleteValueW(
            key,
            valueName
        );
    }

    RegCloseKey(key);
}