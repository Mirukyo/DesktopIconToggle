#include "flutter_window.h"

#include <optional>

#include "bridge.h"
#include "flutter/generated_plugin_registrant.h"

#include "DesktopManager.h"
#include "MouseManager.h"
#include "Resources.h"
#include "Settings.h"
#include "TrayManager.h"

// ============================================================
// Constructor
// ============================================================

FlutterWindow::FlutterWindow(
    const flutter::DartProject& project)
    : project_(project)
{
}

// ============================================================
// Destructor
// ============================================================

FlutterWindow::~FlutterWindow()
{
}

// ============================================================
// Get native HWND
// ============================================================

HWND FlutterWindow::GetWindowHandle()
{
  return GetHandle();
}

// ============================================================
// Create
// ============================================================

bool FlutterWindow::OnCreate()
{
  if (!Win32Window::OnCreate())
  {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ =
      std::make_unique<
          flutter::FlutterViewController>(
          frame.right - frame.left,
          frame.bottom - frame.top,
          project_);

  if (!flutter_controller_->engine() ||
      !flutter_controller_->view())
  {
    return false;
  }

  // ----------------------------------------------------------
  // Flutter plugins
  // ----------------------------------------------------------

  RegisterPlugins(
      flutter_controller_->engine()
  );

  // ----------------------------------------------------------
  // Load settings
  // ----------------------------------------------------------

  LoadSettings();

  // ----------------------------------------------------------
  // Native bridge
  // ----------------------------------------------------------

  NativeBridge::Register(
      flutter_controller_->engine()->messenger()
  );

  NativeBridge::SetMainWindow(
      GetWindowHandle()
  );

  // ----------------------------------------------------------
  // Mouse manager
  //
  // This was previously missing after migrating to Flutter.
  // It is responsible for detecting double-clicks on the
  // empty desktop area.
  // ----------------------------------------------------------

  if (!InitializeMouseManager(
          GetWindowHandle()))
  {
    // Mouse detection failure should not prevent
    // the Flutter UI itself from starting.
  }

  // ----------------------------------------------------------
  // Tray
  // ----------------------------------------------------------

  if (GetSettings().trayEnabled)
  {
    InitializeTrayManager(
        GetWindowHandle()
    );
  }

  // ----------------------------------------------------------
  // Flutter content
  // ----------------------------------------------------------

  SetChildContent(
      flutter_controller_->view()
          ->GetNativeWindow()
  );

  // ----------------------------------------------------------
  // First frame
  // ----------------------------------------------------------

  flutter_controller_->engine()
      ->SetNextFrameCallback(
          [&]() {
            this->Show();
          });

  flutter_controller_->ForceRedraw();

  return true;
}

// ============================================================
// Destroy
// ============================================================

void FlutterWindow::OnDestroy()
{
  // ----------------------------------------------------------
  // Mouse manager
  // ----------------------------------------------------------

  ShutdownMouseManager();

  // ----------------------------------------------------------
  // Tray
  // ----------------------------------------------------------

  ShutdownTrayManager();

  // ----------------------------------------------------------
  // Native bridge
  // ----------------------------------------------------------

  NativeBridge::Shutdown();

  // ----------------------------------------------------------
  // Flutter controller
  // ----------------------------------------------------------

  if (flutter_controller_)
  {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

// ============================================================
// Window message handler
// ============================================================

LRESULT FlutterWindow::MessageHandler(
    HWND hwnd,
    UINT const message,
    WPARAM const wparam,
    LPARAM const lparam) noexcept
{
  // ----------------------------------------------------------
  // Tray
  // ----------------------------------------------------------

  if (message == WM_TRAYICON)
  {
    if (lparam == WM_LBUTTONDBLCLK)
    {
      Show();

      SetForegroundWindow(
          hwnd
      );

      return 0;
    }

    if (lparam == WM_RBUTTONUP)
    {
      ShowTrayMenu();

      return 0;
    }
  }

  // ----------------------------------------------------------
  // Tray menu commands
  // ----------------------------------------------------------

  if (message == WM_COMMAND)
  {
    switch (LOWORD(wparam))
    {
      case ID_TRAY_TOGGLE:
      {
        ToggleDesktopIcons();
        return 0;
      }

      case ID_TRAY_SETTINGS:
      {
        Show();

        SetForegroundWindow(
            hwnd
        );

        return 0;
      }

      case ID_TRAY_EXIT:
      {
        PostMessageW(
            hwnd,
            WM_APP + 100,
            0,
            0
        );

        return 0;
      }
    }
  }

  // ----------------------------------------------------------
  // Close button
  //
  // X hides the settings window to tray.
  // It does NOT exit the application.
  // ----------------------------------------------------------

  if (message == WM_CLOSE)
  {
    ShowWindow(
        hwnd,
        SW_HIDE
    );

    return 0;
  }

  // ----------------------------------------------------------
  // Native bridge
  // ----------------------------------------------------------

  if (NativeBridge::HandleWindowMessage(
          message,
          wparam))
  {
    return 0;
  }

  // ----------------------------------------------------------
  // Flutter
  // ----------------------------------------------------------

  if (flutter_controller_)
  {
    std::optional<LRESULT> result =
        flutter_controller_
            ->HandleTopLevelWindowProc(
                hwnd,
                message,
                wparam,
                lparam
            );

    if (result)
    {
      return *result;
    }
  }

  // ----------------------------------------------------------
  // Font change
  // ----------------------------------------------------------

  if (message == WM_FONTCHANGE)
  {
    if (flutter_controller_ &&
        flutter_controller_->engine())
    {
      flutter_controller_->engine()
          ->ReloadSystemFonts();
    }
  }

  return Win32Window::MessageHandler(
      hwnd,
      message,
      wparam,
      lparam
  );
}