#include "Settings.h"
#include "Resources.h"

#include <windows.h>

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>
#include <iterator>

// ============================================================
// Internal helpers
// ============================================================

namespace
{
    constexpr DWORD kHotkeyFormatVersion = 3;

    constexpr wchar_t kSettingsDirectory[] =
        L"data";

    constexpr wchar_t kSettingsFileName[] =
        L"settings.json";

    AppSettings g_settings;

    // --------------------------------------------------------
    // Read DWORD from registry
    // --------------------------------------------------------

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

        const LONG result =
            RegQueryValueExW(
                key,
                name,
                nullptr,
                &type,
                reinterpret_cast<LPBYTE>(
                    &value),
                &size);

        RegCloseKey(key);

        return result == ERROR_SUCCESS &&
               type == REG_DWORD &&
               size == sizeof(DWORD);
    }

    // --------------------------------------------------------
    // Read string from registry
    // --------------------------------------------------------

    bool ReadString(
        HKEY root,
        const wchar_t* path,
        const wchar_t* name,
        std::wstring& value)
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
        DWORD size = 0;

        LONG result =
            RegQueryValueExW(
                key,
                name,
                nullptr,
                &type,
                nullptr,
                &size);

        if (result != ERROR_SUCCESS ||
            (type != REG_SZ &&
             type != REG_EXPAND_SZ) ||
            size == 0)
        {
            RegCloseKey(key);
            return false;
        }

        std::wstring buffer(
            size / sizeof(wchar_t),
            L'\0');

        result =
            RegQueryValueExW(
                key,
                name,
                nullptr,
                &type,
                reinterpret_cast<LPBYTE>(
                    buffer.data()),
                &size);

        RegCloseKey(key);

        if (result != ERROR_SUCCESS)
        {
            return false;
        }

        if (!buffer.empty() &&
            buffer.back() == L'\0')
        {
            buffer.pop_back();
        }

        value = buffer;

        return !value.empty();
    }

    // --------------------------------------------------------
    // Write DWORD to registry
    // --------------------------------------------------------

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
            reinterpret_cast<const BYTE*>(
                &value),
            sizeof(value));

        RegCloseKey(key);
    }

    // --------------------------------------------------------
    // Get directory containing current EXE
    // --------------------------------------------------------

    std::wstring GetExecutableDirectory()
    {
        const std::wstring executable =
            GetExecutablePath();

        if (executable.empty())
        {
            return L"";
        }

        const size_t separator =
            executable.find_last_of(
                L"\\/");

        if (separator ==
            std::wstring::npos)
        {
            return L"";
        }

        return executable.substr(
            0,
            separator);
    }

    // --------------------------------------------------------
    // Get data directory
    //
    // Example:
    //
    // F:\DesktopIconToggle\
    //     data\
    // --------------------------------------------------------

    std::wstring GetDataDirectory()
    {
        const std::wstring executableDirectory =
            GetExecutableDirectory();

        if (executableDirectory.empty())
        {
            return L"";
        }

        return executableDirectory +
               L"\\" +
               kSettingsDirectory;
    }

    // --------------------------------------------------------
    // Get settings file path
    //
    // Example:
    //
    // F:\DesktopIconToggle\data\settings.json
    // --------------------------------------------------------

    std::wstring GetSettingsFilePath()
    {
        const std::wstring dataDirectory =
            GetDataDirectory();

        if (dataDirectory.empty())
        {
            return L"";
        }

        return dataDirectory +
               L"\\" +
               kSettingsFileName;
    }

    // --------------------------------------------------------
    // Ensure data directory exists
    // --------------------------------------------------------

    bool EnsureDataDirectory()
    {
        const std::wstring dataDirectory =
            GetDataDirectory();

        if (dataDirectory.empty())
        {
            return false;
        }

        const DWORD attributes =
            GetFileAttributesW(
                dataDirectory.c_str());

        if (attributes !=
            INVALID_FILE_ATTRIBUTES)
        {
            return (
                attributes &
                FILE_ATTRIBUTE_DIRECTORY) != 0;
        }

        if (CreateDirectoryW(
                dataDirectory.c_str(),
                nullptr))
        {
            return true;
        }

        return GetLastError() ==
               ERROR_ALREADY_EXISTS;
    }

    // --------------------------------------------------------
    // Read settings.json
    // --------------------------------------------------------

    bool ReadSettingsFile(
        std::wstring& content)
    {
        const std::wstring filePath =
            GetSettingsFilePath();

        if (filePath.empty())
        {
            return false;
        }

        std::wifstream file{
            std::filesystem::path(
                filePath)};

        if (!file.is_open())
        {
            return false;
        }

        content.assign(
            std::istreambuf_iterator<wchar_t>(
                file),
            std::istreambuf_iterator<wchar_t>());

        return !content.empty();
    }

    // --------------------------------------------------------
    // Find JSON value
    // --------------------------------------------------------

    bool FindJsonValue(
        const std::wstring& json,
        const wchar_t* name,
        size_t& valueStart)
    {
        const std::wstring key =
            std::wstring(L"\"") +
            name +
            L"\"";

        const size_t keyPosition =
            json.find(key);

        if (keyPosition ==
            std::wstring::npos)
        {
            return false;
        }

        const size_t colon =
            json.find(
                L':',
                keyPosition + key.length());

        if (colon ==
            std::wstring::npos)
        {
            return false;
        }

        valueStart =
            colon + 1;

        while (
            valueStart < json.length() &&
            (
                json[valueStart] == L' ' ||
                json[valueStart] == L'\t' ||
                json[valueStart] == L'\r' ||
                json[valueStart] == L'\n'))
        {
            ++valueStart;
        }

        return valueStart <
               json.length();
    }

    // --------------------------------------------------------
    // Read JSON bool
    // --------------------------------------------------------

    bool ReadJsonBool(
        const std::wstring& json,
        const wchar_t* name,
        bool& value)
    {
        size_t position = 0;

        if (!FindJsonValue(
                json,
                name,
                position))
        {
            return false;
        }

        if (json.compare(
                position,
                4,
                L"true") == 0)
        {
            value = true;
            return true;
        }

        if (json.compare(
                position,
                5,
                L"false") == 0)
        {
            value = false;
            return true;
        }

        return false;
    }

    // --------------------------------------------------------
    // Read JSON unsigned integer
    // --------------------------------------------------------

    bool ReadJsonUInt(
        const std::wstring& json,
        const wchar_t* name,
        unsigned int& value)
    {
        size_t position = 0;

        if (!FindJsonValue(
                json,
                name,
                position))
        {
            return false;
        }

        const wchar_t* begin =
            json.c_str() + position;

        wchar_t* end = nullptr;

        const unsigned long parsed =
            std::wcstoul(
                begin,
                &end,
                10);

        if (end == begin)
        {
            return false;
        }

        value =
            static_cast<unsigned int>(
                parsed);

        return true;
    }

    // --------------------------------------------------------
    // Write settings.json
    //
    // Uses a temporary file first and then replaces the
    // existing settings file.
    // --------------------------------------------------------

    bool WriteSettingsFile()
    {
        if (!EnsureDataDirectory())
        {
            return false;
        }

        const std::wstring filePath =
            GetSettingsFilePath();

        if (filePath.empty())
        {
            return false;
        }

        const std::wstring temporaryPath =
            filePath + L".tmp";

        {
            std::wofstream file{
                std::filesystem::path(
                    temporaryPath),
                std::ios::trunc};

            if (!file.is_open())
            {
                return false;
            }

            file
                << L"{\n"
                << L"  \"version\": "
                << kHotkeyFormatVersion
                << L",\n"

                << L"  \"doubleClickEnabled\": "
                << (
                    g_settings.doubleClickEnabled
                        ? L"true"
                        : L"false")
                << L",\n"

                << L"  \"startupEnabled\": "
                << (
                    g_settings.startupEnabled
                        ? L"true"
                        : L"false")
                << L",\n"

                << L"  \"trayEnabled\": "
                << (
                    g_settings.trayEnabled
                        ? L"true"
                        : L"false")
                << L",\n"

                << L"  \"hotkeyEnabled\": "
                << (
                    g_settings.hotkeyEnabled
                        ? L"true"
                        : L"false")
                << L",\n"

                << L"  \"hotkeyModifiers\": "
                << g_settings.hotkeyModifiers
                << L",\n"

                << L"  \"hotkeyVk\": "
                << g_settings.hotkeyVk
                << L"\n"

                << L"}\n";

            if (!file.good())
            {
                return false;
            }
        }

        if (!MoveFileExW(
                temporaryPath.c_str(),
                filePath.c_str(),
                MOVEFILE_REPLACE_EXISTING |
                    MOVEFILE_WRITE_THROUGH))
        {
            DeleteFileW(
                temporaryPath.c_str());

            return false;
        }

        return true;
    }

    // --------------------------------------------------------
    // Load settings.json
    // --------------------------------------------------------

    bool LoadSettingsFile()
    {
        std::wstring json;

        if (!ReadSettingsFile(json))
        {
            return false;
        }

        bool boolValue = false;
        unsigned int uintValue = 0;

        if (ReadJsonBool(
                json,
                L"doubleClickEnabled",
                boolValue))
        {
            g_settings.doubleClickEnabled =
                boolValue;
        }

        if (ReadJsonBool(
                json,
                L"startupEnabled",
                boolValue))
        {
            g_settings.startupEnabled =
                boolValue;
        }

        if (ReadJsonBool(
                json,
                L"trayEnabled",
                boolValue))
        {
            g_settings.trayEnabled =
                boolValue;
        }

        if (ReadJsonBool(
                json,
                L"hotkeyEnabled",
                boolValue))
        {
            g_settings.hotkeyEnabled =
                boolValue;
        }

        if (ReadJsonUInt(
                json,
                L"hotkeyModifiers",
                uintValue))
        {
            g_settings.hotkeyModifiers =
                uintValue;
        }

        if (ReadJsonUInt(
                json,
                L"hotkeyVk",
                uintValue))
        {
            g_settings.hotkeyVk =
                uintValue;
        }

        return true;
    }

    // --------------------------------------------------------
    // Load settings from legacy registry
    //
    // Used only when settings.json does not exist.
    // --------------------------------------------------------

    void LoadLegacyRegistrySettings()
    {
        DWORD value = 0;

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

        DWORD modifiers = 0;
        DWORD virtualKey = 0;

        const bool hasModifiers =
            ReadDWORD(
                HKEY_CURRENT_USER,
                REG_PATH,
                L"HotkeyModifiers",
                modifiers);

        const bool hasVirtualKey =
            ReadDWORD(
                HKEY_CURRENT_USER,
                REG_PATH,
                L"HotkeyVk",
                virtualKey);

        // ----------------------------------------------------
        // Fix known legacy hotkey value.
        //
        // Old Flutter versions:
        // Ctrl = 1
        // Shift = 2
        // Alt = 4
        //
        // Ctrl + Alt = 5
        //
        // Correct Windows value:
        // MOD_CONTROL | MOD_ALT = 3
        // ----------------------------------------------------

        if (hasModifiers &&
            hasVirtualKey &&
            modifiers == 5 &&
            virtualKey == 0x48)
        {
            modifiers =
                MOD_CONTROL | MOD_ALT;
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
    }
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
    g_settings =
        AppSettings{};

    // --------------------------------------------------------
    // Try the new local configuration first.
    // --------------------------------------------------------

    const bool loadedFromFile =
        LoadSettingsFile();

    // --------------------------------------------------------
    // Migrate legacy registry settings when no JSON file
    // exists yet.
    // --------------------------------------------------------

    if (!loadedFromFile)
    {
        LoadLegacyRegistrySettings();

        WriteSettingsFile();
    }

    // --------------------------------------------------------
    // Keep Windows startup entry synchronized.
    //
    // If startup is enabled but the registry points to an old
    // version, rewrite it to the current EXE.
    // --------------------------------------------------------

    if (g_settings.startupEnabled &&
        !IsStartupPathCurrent())
    {
        SetStartupEnabled(true);
    }
}

// ============================================================
// Save settings
// ============================================================

void SaveSettings()
{
    // --------------------------------------------------------
    // Software settings
    // --------------------------------------------------------

    WriteSettingsFile();

    // --------------------------------------------------------
    // Windows startup setting
    // --------------------------------------------------------

    SetStartupEnabled(
        g_settings.startupEnabled);
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
    std::wstring result;

    DWORD bufferSize =
        MAX_PATH;

    while (true)
    {
        std::wstring buffer(
            bufferSize,
            L'\0');

        const DWORD length =
            GetModuleFileNameW(
                nullptr,
                buffer.data(),
                bufferSize);

        if (length == 0)
        {
            return L"";
        }

        // The buffer was large enough.
        if (length <
            bufferSize - 1)
        {
            buffer.resize(length);
            result = buffer;
            break;
        }

        // The path may have been truncated.
        bufferSize *= 2;

        if (bufferSize >
            32768)
        {
            return L"";
        }
    }

    return result;
}

// ============================================================
// Check startup path
// ============================================================

bool IsStartupPathCurrent()
{
    const std::wstring currentExe =
        GetExecutablePath();

    if (currentExe.empty())
    {
        return false;
    }

    HKEY key = nullptr;

    if (RegOpenKeyExW(
            HKEY_CURRENT_USER,
            RUN_REG_PATH,
            0,
            KEY_READ,
            &key) != ERROR_SUCCESS)
    {
        return false;
    }

    wchar_t buffer[32768]{};

    DWORD size =
        sizeof(buffer);

    DWORD type = 0;

    const LONG result =
        RegQueryValueExW(
            key,
            L"DesktopIconToggle",
            nullptr,
            &type,
            reinterpret_cast<LPBYTE>(
                buffer),
            &size);

    RegCloseKey(key);

    if (result != ERROR_SUCCESS ||
        (type != REG_SZ &&
         type != REG_EXPAND_SZ))
    {
        return false;
    }

    std::wstring startupCommand(
        buffer);

    // --------------------------------------------------------
    // Trim whitespace.
    // --------------------------------------------------------

    while (
        !startupCommand.empty() &&
        (
            startupCommand.back() == L' ' ||
            startupCommand.back() == L'\t' ||
            startupCommand.back() == L'\r' ||
            startupCommand.back() == L'\n'))
    {
        startupCommand.pop_back();
    }

    while (
        !startupCommand.empty() &&
        (
            startupCommand.front() == L' ' ||
            startupCommand.front() == L'\t' ||
            startupCommand.front() == L'\r' ||
            startupCommand.front() == L'\n'))
    {
        startupCommand.erase(
            startupCommand.begin());
    }

    // --------------------------------------------------------
    // Remove surrounding quotes.
    // --------------------------------------------------------

    if (startupCommand.size() >= 2 &&
        startupCommand.front() == L'"' &&
        startupCommand.back() == L'"')
    {
        startupCommand =
            startupCommand.substr(
                1,
                startupCommand.size() - 2);
    }

    return _wcsicmp(
               startupCommand.c_str(),
               currentExe.c_str()) == 0;
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
        const std::wstring exe =
            GetExecutablePath();

        if (!exe.empty())
        {
            const std::wstring command =
                L"\"" + exe + L"\"";

            RegSetValueExW(
                key,
                valueName,
                0,
                REG_SZ,
                reinterpret_cast<const BYTE*>(
                    command.c_str()),
                static_cast<DWORD>(
                    (command.size() + 1) *
                    sizeof(wchar_t)));
        }
    }
    else
    {
        RegDeleteValueW(
            key,
            valueName);
    }

    RegCloseKey(key);
}