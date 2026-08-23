# DesktopIconToggle

一个用于 Windows 的桌面图标隐藏/显示工具。

## 项目简介

DesktopIconToggle 可以快速隐藏或显示 Windows 桌面图标，并提供简洁的设置界面。

项目采用 **C++ + Flutter** 开发：

- C++：负责 Windows 系统功能、桌面图标、全局快捷键、鼠标检测和系统托盘。
- Flutter：负责设置界面和用户交互。

## 主要功能

- 双击桌面空白区域隐藏/显示桌面图标
- 全局快捷键隐藏/显示桌面图标
- 自定义全局快捷键
- 首次启动快捷键设置引导
- Windows 系统托盘
- 开机自动启动
- Material 3 设置界面
- 支持 Windows 明暗主题
- 使用自定义应用图标

## 运行

进入 Flutter 项目目录：

```powershell
cd F:\DesktopIconToggle\ui
```

运行：

```powershell
flutter run -d windows
```

## 构建

```powershell
flutter build windows --release
```

Release 文件位于：

```text
ui\build\windows\x64\runner\Release\
```

## 项目状态

当前项目已经实现基本的桌面图标隐藏/显示、快捷键、托盘和设置功能。

后续可以继续完善界面设计、状态同步和其他 Windows 功能。