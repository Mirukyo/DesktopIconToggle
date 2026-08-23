cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# ============================================================
# Application target
# ============================================================

add_executable(${BINARY_NAME} WIN32

  # Flutter Windows runner
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"

  # Flutter generated plugin registration
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"

  # DesktopIconToggle native core
  "bridge.cpp"
  "DesktopManager.cpp"
  "MouseManager.cpp"
  "TrayManager.cpp"
  "Settings.cpp"

  # Windows resources
  "Runner.rc"
  "runner.exe.manifest"
)

# ============================================================
# Copy custom application / tray icon
# ============================================================

set(APP_ICON_SOURCE
  "${CMAKE_CURRENT_SOURCE_DIR}/resources/desktop_icon.ico"
)

add_custom_command(
  TARGET ${BINARY_NAME}
  POST_BUILD

  COMMAND ${CMAKE_COMMAND} -E make_directory
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/resources"

  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${APP_ICON_SOURCE}"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/resources/desktop_icon.ico"
)

# ============================================================
# Standard build settings
# ============================================================

apply_standard_settings(${BINARY_NAME})

# ============================================================
# Flutter version definitions
# ============================================================

target_compile_definitions(
  ${BINARY_NAME}
  PRIVATE
  "FLUTTER_VERSION=\"${FLUTTER_VERSION}\""
)

target_compile_definitions(
  ${BINARY_NAME}
  PRIVATE
  "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}"
)

target_compile_definitions(
  ${BINARY_NAME}
  PRIVATE
  "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}"
)

target_compile_definitions(
  ${BINARY_NAME}
  PRIVATE
  "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}"
)

target_compile_definitions(
  ${BINARY_NAME}
  PRIVATE
  "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}"
)

# ============================================================
# Windows definitions
# ============================================================

target_compile_definitions(
  ${BINARY_NAME}
  PRIVATE
  "NOMINMAX"
)

# ============================================================
# Include directories
# ============================================================

target_include_directories(
  ${BINARY_NAME}
  PRIVATE
  "${CMAKE_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}"
)

# ============================================================
# Libraries
# ============================================================

target_link_libraries(
  ${BINARY_NAME}
  PRIVATE
  flutter
  flutter_wrapper_app
)

target_link_libraries(
  ${BINARY_NAME}
  PRIVATE
  "dwmapi.lib"
)

target_link_libraries(
  ${BINARY_NAME}
  PRIVATE
  "shell32.lib"
)

target_link_libraries(
  ${BINARY_NAME}
  PRIVATE
  "oleacc.lib"
)

# ============================================================
# Flutter build dependency
# ============================================================

add_dependencies(
  ${BINARY_NAME}
  flutter_assemble
)