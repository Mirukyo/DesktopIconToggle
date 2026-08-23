#include "bridge.h"

#include "DesktopManager.h"
#include "MouseManager.h"
#include "Settings.h"
#include "TrayManager.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <cstdint>
#include <memory>

namespace
{
    constexpr char kChannelName[] =
        "desktop_icon_toggle/native";

    constexpr int kHotkeyId = 3001;

    constexpr UINT kMessageExitApplication =
        WM_APP + 100;

    HWND g_mainWindow = nullptr;

    // --------------------------------------------------------
    // Keep the MethodChannel alive for the whole application.
    // --------------------------------------------------------

    std::unique_ptr<
        flutter::MethodChannel<
            flutter::EncodableValue
        >
    > g_channel;

    // ========================================================
    // Convert AppSettings -> Flutter
    // ========================================================

    flutter::EncodableMap SettingsToMap()
    {
        const AppSettings& settings =
            GetSettings();

        flutter::EncodableMap result;

        result[
            flutter::EncodableValue(
                "doubleClickEnabled"
            )
        ] =
            flutter::EncodableValue(
                settings.doubleClickEnabled
            );

        result[
            flutter::EncodableValue(
                "startupEnabled"
            )
        ] =
            flutter::EncodableValue(
                settings.startupEnabled
            );

        result[
            flutter::EncodableValue(
                "trayEnabled"
            )
        ] =
            flutter::EncodableValue(
                settings.trayEnabled
            );

        result[
            flutter::EncodableValue(
                "hotkeyEnabled"
            )
        ] =
            flutter::EncodableValue(
                settings.hotkeyEnabled
            );

        result[
            flutter::EncodableValue(
                "hotkeyModifiers"
            )
        ] =
            flutter::EncodableValue(
                static_cast<int>(
                    settings.hotkeyModifiers
                )
            );

        result[
            flutter::EncodableValue(
                "hotkeyVk"
            )
        ] =
            flutter::EncodableValue(
                static_cast<int>(
                    settings.hotkeyVk
                )
            );

        return result;
    }

    // ========================================================
    // Read bool
    // ========================================================

    bool ReadBool(
        const flutter::EncodableMap& map,
        const char* key,
        bool fallback)
    {
        auto it =
            map.find(
                flutter::EncodableValue(key)
            );

        if (it == map.end())
        {
            return fallback;
        }

        const auto* value =
            std::get_if<bool>(
                &it->second
            );

        if (!value)
        {
            return fallback;
        }

        return *value;
    }

    // ========================================================
    // Read int
    // ========================================================

    int ReadInt(
        const flutter::EncodableMap& map,
        const char* key,
        int fallback)
    {
        auto it =
            map.find(
                flutter::EncodableValue(key)
            );

        if (it == map.end())
        {
            return fallback;
        }

        const auto* value =
            std::get_if<int32_t>(
                &it->second
            );

        if (!value)
        {
            return fallback;
        }

        return static_cast<int>(*value);
    }

    // ========================================================
    // Register global hotkey
    // ========================================================

    bool RegisterGlobalHotkey()
    {
        if (!g_mainWindow)
        {
            return false;
        }

        const AppSettings& settings =
            GetSettings();

        if (!settings.hotkeyEnabled)
        {
            return true;
        }

        if (settings.hotkeyModifiers == 0 ||
            settings.hotkeyVk == 0)
        {
            return false;
        }

        return RegisterHotKey(
            g_mainWindow,
            kHotkeyId,
            settings.hotkeyModifiers,
            settings.hotkeyVk
        ) != FALSE;
    }

    // ========================================================
    // Unregister global hotkey
    // ========================================================

    void UnregisterGlobalHotkey()
    {
        if (!g_mainWindow)
        {
            return;
        }

        UnregisterHotKey(
            g_mainWindow,
            kHotkeyId
        );
    }

    // ========================================================
    // Re-register global hotkey
    // ========================================================

    bool ReRegisterGlobalHotkey()
    {
        UnregisterGlobalHotkey();

        if (!GetSettings().hotkeyEnabled)
        {
            return true;
        }

        return RegisterGlobalHotkey();
    }
}

// ============================================================
// Notify Flutter about the real desktop icon state
//
// true  = hidden
// false = visible
// ============================================================

void NotifyDesktopIconStateChanged()
{
    if (!g_channel)
    {
        return;
    }

    const bool hidden =
        AreDesktopIconsHidden();

    g_channel->InvokeMethod(
        "desktopIconStateChanged",
        std::make_unique<
            flutter::EncodableValue
        >(hidden)
    );
}

// ============================================================
// Set main window
// ============================================================

void NativeBridge::SetMainWindow(
    HWND window)
{
    if (g_mainWindow == window)
    {
        return;
    }

    if (g_mainWindow)
    {
        UnregisterGlobalHotkey();
    }

    g_mainWindow = window;

    if (g_mainWindow)
    {
        RegisterGlobalHotkey();
    }
}

// ============================================================
// Handle native window message
// ============================================================

bool NativeBridge::HandleWindowMessage(
    UINT message,
    WPARAM wparam)
{
    if (message == WM_HOTKEY)
    {
        if (wparam == kHotkeyId)
        {
            ToggleDesktopIcons();

            NotifyDesktopIconStateChanged();

            return true;
        }

        return false;
    }

    if (message == kMessageExitApplication)
    {
        if (g_mainWindow)
        {
            DestroyWindow(
                g_mainWindow
            );
        }

        return true;
    }

    return false;
}

// ============================================================
// Request application exit
// ============================================================

bool NativeBridge::RequestExit()
{
    if (!g_mainWindow)
    {
        return false;
    }

    PostMessageW(
        g_mainWindow,
        kMessageExitApplication,
        0,
        0
    );

    return true;
}

// ============================================================
// Cleanup
// ============================================================

void NativeBridge::Shutdown()
{
    UnregisterGlobalHotkey();

    g_channel.reset();

    g_mainWindow = nullptr;
}

// ============================================================
// Register MethodChannel
// ============================================================

void NativeBridge::Register(
    flutter::BinaryMessenger* messenger)
{
    if (!messenger)
    {
        return;
    }

    g_channel =
        std::make_unique<
            flutter::MethodChannel<
                flutter::EncodableValue
            >
        >(
            messenger,
            kChannelName,
            &flutter::StandardMethodCodec::GetInstance()
        );

    g_channel->SetMethodCallHandler(
        [](const auto& call,
           auto result)
        {
            // =================================================
            // getSettings
            // =================================================

            if (call.method_name() ==
                "getSettings")
            {
                result->Success(
                    SettingsToMap()
                );

                return;
            }

            // =================================================
            // getDesktopIconState
            // =================================================

            if (call.method_name() ==
                "getDesktopIconState")
            {
                result->Success(
                    AreDesktopIconsHidden()
                );

                return;
            }

            // =================================================
            // saveSettings
            // =================================================

            if (call.method_name() ==
                "saveSettings")
            {
                const auto* arguments =
                    std::get_if<
                        flutter::EncodableMap
                    >(
                        call.arguments()
                    );

                if (!arguments)
                {
                    result->Error(
                        "INVALID_ARGUMENT",
                        "Invalid settings data."
                    );

                    return;
                }

                const AppSettings oldSettings =
                    GetSettings();

                AppSettings& settings =
                    GetSettingsMutable();

                settings.doubleClickEnabled =
                    ReadBool(
                        *arguments,
                        "doubleClickEnabled",
                        settings.doubleClickEnabled
                    );

                settings.startupEnabled =
                    ReadBool(
                        *arguments,
                        "startupEnabled",
                        settings.startupEnabled
                    );

                settings.trayEnabled =
                    ReadBool(
                        *arguments,
                        "trayEnabled",
                        settings.trayEnabled
                    );

                settings.hotkeyEnabled =
                    ReadBool(
                        *arguments,
                        "hotkeyEnabled",
                        settings.hotkeyEnabled
                    );

                settings.hotkeyModifiers =
                    static_cast<UINT>(
                        ReadInt(
                            *arguments,
                            "hotkeyModifiers",
                            static_cast<int>(
                                settings.hotkeyModifiers
                            )
                        )
                    );

                settings.hotkeyVk =
                    static_cast<UINT>(
                        ReadInt(
                            *arguments,
                            "hotkeyVk",
                            static_cast<int>(
                                settings.hotkeyVk
                            )
                        )
                    );

                SetDoubleClickDetectionEnabled(
                    settings.doubleClickEnabled
                );

                SetStartupEnabled(
                    settings.startupEnabled
                );

                UpdateTrayVisibility(
                    settings.trayEnabled
                );

                if (!ReRegisterGlobalHotkey())
                {
                    settings =
                        oldSettings;

                    SetDoubleClickDetectionEnabled(
                        oldSettings.doubleClickEnabled
                    );

                    SetStartupEnabled(
                        oldSettings.startupEnabled
                    );

                    UpdateTrayVisibility(
                        oldSettings.trayEnabled
                    );

                    ReRegisterGlobalHotkey();

                    result->Error(
                        "HOTKEY_FAILED",
                        "快捷键注册失败，可能已被其他程序占用。"
                    );

                    return;
                }

                SaveSettings();

                NotifyDesktopIconStateChanged();

                result->Success(true);

                return;
            }

            // =================================================
            // toggleDesktopIcons
            // =================================================

            if (call.method_name() ==
                "toggleDesktopIcons")
            {
                ToggleDesktopIcons();

                NotifyDesktopIconStateChanged();

                result->Success(true);

                return;
            }

            // =================================================
            // setDoubleClickEnabled
            // =================================================

            if (call.method_name() ==
                "setDoubleClickEnabled")
            {
                const auto* enabled =
                    std::get_if<bool>(
                        call.arguments()
                    );

                if (!enabled)
                {
                    result->Error(
                        "INVALID_ARGUMENT",
                        "Expected boolean."
                    );

                    return;
                }

                GetSettingsMutable()
                    .doubleClickEnabled =
                    *enabled;

                SetDoubleClickDetectionEnabled(
                    *enabled
                );

                SaveSettings();

                result->Success(true);

                return;
            }

            // =================================================
            // setStartupEnabled
            // =================================================

            if (call.method_name() ==
                "setStartupEnabled")
            {
                const auto* enabled =
                    std::get_if<bool>(
                        call.arguments()
                    );

                if (!enabled)
                {
                    result->Error(
                        "INVALID_ARGUMENT",
                        "Expected boolean."
                    );

                    return;
                }

                GetSettingsMutable()
                    .startupEnabled =
                    *enabled;

                SetStartupEnabled(
                    *enabled
                );

                SaveSettings();

                result->Success(true);

                return;
            }

            // =================================================
            // setTrayEnabled
            // =================================================

            if (call.method_name() ==
                "setTrayEnabled")
            {
                const auto* enabled =
                    std::get_if<bool>(
                        call.arguments()
                    );

                if (!enabled)
                {
                    result->Error(
                        "INVALID_ARGUMENT",
                        "Expected boolean."
                    );

                    return;
                }

                GetSettingsMutable()
                    .trayEnabled =
                    *enabled;

                UpdateTrayVisibility(
                    *enabled
                );

                SaveSettings();

                result->Success(true);

                return;
            }

            // =================================================
            // setHotkeyEnabled
            // =================================================

            if (call.method_name() ==
                "setHotkeyEnabled")
            {
                const auto* enabled =
                    std::get_if<bool>(
                        call.arguments()
                    );

                if (!enabled)
                {
                    result->Error(
                        "INVALID_ARGUMENT",
                        "Expected boolean."
                    );

                    return;
                }

                const bool oldEnabled =
                    GetSettings()
                        .hotkeyEnabled;

                GetSettingsMutable()
                    .hotkeyEnabled =
                    *enabled;

                if (!ReRegisterGlobalHotkey())
                {
                    GetSettingsMutable()
                        .hotkeyEnabled =
                        oldEnabled;

                    ReRegisterGlobalHotkey();

                    result->Error(
                        "HOTKEY_FAILED",
                        "快捷键注册失败。"
                    );

                    return;
                }

                SaveSettings();

                result->Success(true);

                return;
            }

            // =================================================
            // setHotkey
            // =================================================

            if (call.method_name() ==
                "setHotkey")
            {
                const auto* arguments =
                    std::get_if<
                        flutter::EncodableMap
                    >(
                        call.arguments()
                    );

                if (!arguments)
                {
                    result->Error(
                        "INVALID_ARGUMENT",
                        "Invalid hotkey data."
                    );

                    return;
                }

                const AppSettings oldSettings =
                    GetSettings();

                AppSettings& settings =
                    GetSettingsMutable();

                settings.hotkeyModifiers =
                    static_cast<UINT>(
                        ReadInt(
                            *arguments,
                            "modifiers",
                            static_cast<int>(
                                settings.hotkeyModifiers
                            )
                        )
                    );

                settings.hotkeyVk =
                    static_cast<UINT>(
                        ReadInt(
                            *arguments,
                            "virtualKey",
                            static_cast<int>(
                                settings.hotkeyVk
                            )
                        )
                    );

                if (!ReRegisterGlobalHotkey())
                {
                    settings =
                        oldSettings;

                    ReRegisterGlobalHotkey();

                    result->Error(
                        "HOTKEY_FAILED",
                        "快捷键注册失败，可能已被其他程序占用。"
                    );

                    return;
                }

                SaveSettings();

                result->Success(true);

                return;
            }

            // =================================================
            // exitApp
            // =================================================

            if (call.method_name() ==
                "exitApp")
            {
                if (!NativeBridge::RequestExit())
                {
                    result->Error(
                        "EXIT_FAILED",
                        "无法退出应用。"
                    );

                    return;
                }

                result->Success(true);

                return;
            }

            // =================================================
            // Unknown method
            // =================================================

            result->NotImplemented();
        }
    );
}