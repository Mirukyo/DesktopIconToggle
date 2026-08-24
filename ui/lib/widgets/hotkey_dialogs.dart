import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================
// Hotkey result
// ============================================================

class HotkeyResult {
  final int modifiers;
  final int virtualKey;
  final String display;

  const HotkeyResult({
    required this.modifiers,
    required this.virtualKey,
    required this.display,
  });
}

// ============================================================
// First-run hotkey result
// ============================================================

class HotkeyGuideResult {
  final bool skipped;
  final int modifiers;
  final int virtualKey;
  final String display;

  const HotkeyGuideResult({
    required this.skipped,
    this.modifiers = 0,
    this.virtualKey = 0,
    this.display = '',
  });
}

// ============================================================
// First-run hotkey dialog
// ============================================================

class FirstRunHotkeyDialog
    extends StatefulWidget {
  final String initialDisplay;

  const FirstRunHotkeyDialog({
    super.key,
    required this.initialDisplay,
  });

  @override
  State<FirstRunHotkeyDialog> createState() =>
      _FirstRunHotkeyDialogState();
}

class _FirstRunHotkeyDialogState
    extends State<FirstRunHotkeyDialog> {
  final FocusNode _focusNode =
      FocusNode();

  int _modifiers = 0;
  int? _virtualKey;

  String _display =
      '请按下你想使用的快捷键';

  bool _valid = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.handled;
    }

    final keyboard =
        HardwareKeyboard.instance;

    int modifiers = 0;

    if (keyboard.isAltPressed) {
      modifiers |= 1;
    }

    if (keyboard.isControlPressed) {
      modifiers |= 2;
    }

    if (keyboard.isShiftPressed) {
      modifiers |= 4;
    }

    if (keyboard.isMetaPressed) {
      modifiers |= 8;
    }

    if (_isModifierKey(
      event.logicalKey,
    )) {
      setState(() {
        _modifiers = modifiers;
        _valid = false;

        _display =
            modifiers == 0
                ? '请按下你想使用的快捷键'
                : _formatModifiers(
                    modifiers,
                  );
      });

      return KeyEventResult.handled;
    }

    final virtualKey =
        _virtualKeyFromLogicalKey(
      event.logicalKey,
    );

    if (virtualKey == null) {
      return KeyEventResult.handled;
    }

    if (modifiers == 0) {
      setState(() {
        _modifiers = 0;
        _virtualKey = null;
        _valid = false;

        _display =
            '请至少使用 Ctrl、Shift、Alt 或 Win';
      });

      return KeyEventResult.handled;
    }

    setState(() {
      _modifiers = modifiers;
      _virtualKey = virtualKey;
      _valid = true;

      _display =
          _formatHotkey(
        modifiers,
        virtualKey,
      );
    });

    return KeyEventResult.handled;
  }

  bool _isModifierKey(
    LogicalKeyboardKey key,
  ) {
    return key ==
            LogicalKeyboardKey
                .controlLeft ||
        key ==
            LogicalKeyboardKey
                .controlRight ||
        key ==
            LogicalKeyboardKey
                .shiftLeft ||
        key ==
            LogicalKeyboardKey
                .shiftRight ||
        key ==
            LogicalKeyboardKey
                .altLeft ||
        key ==
            LogicalKeyboardKey
                .altRight ||
        key ==
            LogicalKeyboardKey
                .metaLeft ||
        key ==
            LogicalKeyboardKey
                .metaRight;
  }

  String _formatModifiers(
    int modifiers,
  ) {
    final result =
        <String>[];

    if ((modifiers & 2) != 0) {
      result.add('Ctrl');
    }

    if ((modifiers & 4) != 0) {
      result.add('Shift');
    }

    if ((modifiers & 1) != 0) {
      result.add('Alt');
    }

    if ((modifiers & 8) != 0) {
      result.add('Win');
    }

    return result.join(' + ');
  }

  int? _virtualKeyFromLogicalKey(
    LogicalKeyboardKey key,
  ) {
    final letters =
        <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.keyA: 0x41,
      LogicalKeyboardKey.keyB: 0x42,
      LogicalKeyboardKey.keyC: 0x43,
      LogicalKeyboardKey.keyD: 0x44,
      LogicalKeyboardKey.keyE: 0x45,
      LogicalKeyboardKey.keyF: 0x46,
      LogicalKeyboardKey.keyG: 0x47,
      LogicalKeyboardKey.keyH: 0x48,
      LogicalKeyboardKey.keyI: 0x49,
      LogicalKeyboardKey.keyJ: 0x4A,
      LogicalKeyboardKey.keyK: 0x4B,
      LogicalKeyboardKey.keyL: 0x4C,
      LogicalKeyboardKey.keyM: 0x4D,
      LogicalKeyboardKey.keyN: 0x4E,
      LogicalKeyboardKey.keyO: 0x4F,
      LogicalKeyboardKey.keyP: 0x50,
      LogicalKeyboardKey.keyQ: 0x51,
      LogicalKeyboardKey.keyR: 0x52,
      LogicalKeyboardKey.keyS: 0x53,
      LogicalKeyboardKey.keyT: 0x54,
      LogicalKeyboardKey.keyU: 0x55,
      LogicalKeyboardKey.keyV: 0x56,
      LogicalKeyboardKey.keyW: 0x57,
      LogicalKeyboardKey.keyX: 0x58,
      LogicalKeyboardKey.keyY: 0x59,
      LogicalKeyboardKey.keyZ: 0x5A,
    };

    final letter = letters[key];

    if (letter != null) {
      return letter;
    }

    final numbers =
        <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.digit0: 0x30,
      LogicalKeyboardKey.digit1: 0x31,
      LogicalKeyboardKey.digit2: 0x32,
      LogicalKeyboardKey.digit3: 0x33,
      LogicalKeyboardKey.digit4: 0x34,
      LogicalKeyboardKey.digit5: 0x35,
      LogicalKeyboardKey.digit6: 0x36,
      LogicalKeyboardKey.digit7: 0x37,
      LogicalKeyboardKey.digit8: 0x38,
      LogicalKeyboardKey.digit9: 0x39,
    };

    final number = numbers[key];

    if (number != null) {
      return number;
    }

    final functions =
        <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.f1: 0x70,
      LogicalKeyboardKey.f2: 0x71,
      LogicalKeyboardKey.f3: 0x72,
      LogicalKeyboardKey.f4: 0x73,
      LogicalKeyboardKey.f5: 0x74,
      LogicalKeyboardKey.f6: 0x75,
      LogicalKeyboardKey.f7: 0x76,
      LogicalKeyboardKey.f8: 0x77,
      LogicalKeyboardKey.f9: 0x78,
      LogicalKeyboardKey.f10: 0x79,
      LogicalKeyboardKey.f11: 0x7A,
      LogicalKeyboardKey.f12: 0x7B,
    };

    return functions[key];
  }

  String _formatHotkey(
    int modifiers,
    int virtualKey,
  ) {
    final result =
        <String>[];

    if ((modifiers & 2) != 0) {
      result.add('Ctrl');
    }

    if ((modifiers & 4) != 0) {
      result.add('Shift');
    }

    if ((modifiers & 1) != 0) {
      result.add('Alt');
    }

    if ((modifiers & 8) != 0) {
      result.add('Win');
    }

    if (virtualKey >= 0x41 &&
        virtualKey <= 0x5A) {
      result.add(
        String.fromCharCode(
          virtualKey,
        ),
      );
    } else if (virtualKey >= 0x30 &&
        virtualKey <= 0x39) {
      result.add(
        String.fromCharCode(
          virtualKey,
        ),
      );
    } else if (virtualKey >= 0x70 &&
        virtualKey <= 0x7B) {
      result.add(
        'F${virtualKey - 0x6F}',
      );
    }

    return result.join(' + ');
  }

  void _skip() {
    Navigator.of(context).pop(
      const HotkeyGuideResult(
        skipped: true,
      ),
    );
  }

  void _confirm() {
    if (!_valid ||
        _virtualKey == null) {
      return;
    }

    Navigator.of(context).pop(
      HotkeyGuideResult(
        skipped: false,
        modifiers: _modifiers,
        virtualKey: _virtualKey!,
        display: _display,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return AlertDialog(
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(24),
      ),

      title:
          const Text(
        '设置快捷键',
      ),

      content:
          SizedBox(
        width: 430,

        child:
            Focus(
          focusNode:
              _focusNode,
          autofocus:
              true,
          onKeyEvent:
              _handleKeyEvent,

          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              Icon(
                Icons.keyboard_rounded,
                size: 48,
                color:
                    colors.primary,
              ),

              const SizedBox(
                height: 16,
              ),

              Text(
                '设置一个快捷键，快速隐藏或显示桌面图标。',
                textAlign:
                    TextAlign.center,
                style:
                    theme.textTheme.bodyLarge,
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                '不需要快捷键可以直接跳过，之后也可以在设置中开启。',
                textAlign:
                    TextAlign.center,
                style:
                    theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color:
                          colors
                              .onSurfaceVariant,
                    ),
              ),

              const SizedBox(
                height: 24,
              ),

              AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 180,
                ),

                width:
                    double.infinity,

                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      colors
                          .surfaceContainerHighest,

                  borderRadius:
                      BorderRadius.circular(16),

                  border:
                      Border.all(
                    color:
                        _valid
                            ? colors.primary
                            : colors.outlineVariant,
                    width:
                        _valid ? 2 : 1,
                  ),
                ),

                child:
                    Text(
                  _display,
                  textAlign:
                      TextAlign.center,
                  style:
                      theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                    fontWeight:
                        FontWeight.w600,
                    color:
                        _valid
                            ? colors.primary
                            : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: _skip,
          child:
              const Text(
            '跳过',
          ),
        ),

        FilledButton(
          onPressed:
              _valid
                  ? _confirm
                  : null,
          child:
              const Text(
            '保存并启用',
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Normal hotkey recorder
// ============================================================

class HotkeyRecorderDialog
    extends StatefulWidget {
  final String initialDisplay;

  const HotkeyRecorderDialog({
    super.key,
    required this.initialDisplay,
  });

  @override
  State<HotkeyRecorderDialog> createState() =>
      _HotkeyRecorderDialogState();
}

class _HotkeyRecorderDialogState
    extends State<HotkeyRecorderDialog> {
  final FocusNode _focusNode =
      FocusNode();

  int _modifiers = 0;
  int? _virtualKey;

  String _display =
      '请按下新的快捷键';

  bool _valid = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.handled;
    }

    final keyboard =
        HardwareKeyboard.instance;

    int modifiers = 0;

    if (keyboard.isAltPressed) {
      modifiers |= 1;
    }

    if (keyboard.isControlPressed) {
      modifiers |= 2;
    }

    if (keyboard.isShiftPressed) {
      modifiers |= 4;
    }

    if (keyboard.isMetaPressed) {
      modifiers |= 8;
    }

    if (_isModifierKey(
      event.logicalKey,
    )) {
      setState(() {
        _modifiers = modifiers;
        _valid = false;

        _display =
            _formatModifiers(
          modifiers,
        );
      });

      return KeyEventResult.handled;
    }

    final virtualKey =
        _virtualKeyFromLogicalKey(
      event.logicalKey,
    );

    if (virtualKey == null) {
      return KeyEventResult.handled;
    }

    if (modifiers == 0) {
      setState(() {
        _valid = false;
        _virtualKey = null;

        _display =
            '请至少使用 Ctrl、Shift、Alt 或 Win';
      });

      return KeyEventResult.handled;
    }

    setState(() {
      _modifiers = modifiers;
      _virtualKey = virtualKey;
      _valid = true;

      _display =
          _formatHotkey(
        modifiers,
        virtualKey,
      );
    });

    return KeyEventResult.handled;
  }

  bool _isModifierKey(
    LogicalKeyboardKey key,
  ) {
    return key ==
            LogicalKeyboardKey
                .controlLeft ||
        key ==
            LogicalKeyboardKey
                .controlRight ||
        key ==
            LogicalKeyboardKey
                .shiftLeft ||
        key ==
            LogicalKeyboardKey
                .shiftRight ||
        key ==
            LogicalKeyboardKey
                .altLeft ||
        key ==
            LogicalKeyboardKey
                .altRight ||
        key ==
            LogicalKeyboardKey
                .metaLeft ||
        key ==
            LogicalKeyboardKey
                .metaRight;
  }

  String _formatModifiers(
    int modifiers,
  ) {
    final result =
        <String>[];

    if ((modifiers & 2) != 0) {
      result.add('Ctrl');
    }

    if ((modifiers & 4) != 0) {
      result.add('Shift');
    }

    if ((modifiers & 1) != 0) {
      result.add('Alt');
    }

    if ((modifiers & 8) != 0) {
      result.add('Win');
    }

    return result.join(' + ');
  }

  int? _virtualKeyFromLogicalKey(
    LogicalKeyboardKey key,
  ) {
    final letters =
        <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.keyA: 0x41,
      LogicalKeyboardKey.keyB: 0x42,
      LogicalKeyboardKey.keyC: 0x43,
      LogicalKeyboardKey.keyD: 0x44,
      LogicalKeyboardKey.keyE: 0x45,
      LogicalKeyboardKey.keyF: 0x46,
      LogicalKeyboardKey.keyG: 0x47,
      LogicalKeyboardKey.keyH: 0x48,
      LogicalKeyboardKey.keyI: 0x49,
      LogicalKeyboardKey.keyJ: 0x4A,
      LogicalKeyboardKey.keyK: 0x4B,
      LogicalKeyboardKey.keyL: 0x4C,
      LogicalKeyboardKey.keyM: 0x4D,
      LogicalKeyboardKey.keyN: 0x4E,
      LogicalKeyboardKey.keyO: 0x4F,
      LogicalKeyboardKey.keyP: 0x50,
      LogicalKeyboardKey.keyQ: 0x51,
      LogicalKeyboardKey.keyR: 0x52,
      LogicalKeyboardKey.keyS: 0x53,
      LogicalKeyboardKey.keyT: 0x54,
      LogicalKeyboardKey.keyU: 0x55,
      LogicalKeyboardKey.keyV: 0x56,
      LogicalKeyboardKey.keyW: 0x57,
      LogicalKeyboardKey.keyX: 0x58,
      LogicalKeyboardKey.keyY: 0x59,
      LogicalKeyboardKey.keyZ: 0x5A,
    };

    final letter = letters[key];

    if (letter != null) {
      return letter;
    }

    final numbers =
        <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.digit0: 0x30,
      LogicalKeyboardKey.digit1: 0x31,
      LogicalKeyboardKey.digit2: 0x32,
      LogicalKeyboardKey.digit3: 0x33,
      LogicalKeyboardKey.digit4: 0x34,
      LogicalKeyboardKey.digit5: 0x35,
      LogicalKeyboardKey.digit6: 0x36,
      LogicalKeyboardKey.digit7: 0x37,
      LogicalKeyboardKey.digit8: 0x38,
      LogicalKeyboardKey.digit9: 0x39,
    };

    final number = numbers[key];

    if (number != null) {
      return number;
    }

    final functions =
        <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.f1: 0x70,
      LogicalKeyboardKey.f2: 0x71,
      LogicalKeyboardKey.f3: 0x72,
      LogicalKeyboardKey.f4: 0x73,
      LogicalKeyboardKey.f5: 0x74,
      LogicalKeyboardKey.f6: 0x75,
      LogicalKeyboardKey.f7: 0x76,
      LogicalKeyboardKey.f8: 0x77,
      LogicalKeyboardKey.f9: 0x78,
      LogicalKeyboardKey.f10: 0x79,
      LogicalKeyboardKey.f11: 0x7A,
      LogicalKeyboardKey.f12: 0x7B,
    };

    return functions[key];
  }

  String _formatHotkey(
    int modifiers,
    int virtualKey,
  ) {
    final result =
        <String>[];

    if ((modifiers & 2) != 0) {
      result.add('Ctrl');
    }

    if ((modifiers & 4) != 0) {
      result.add('Shift');
    }

    if ((modifiers & 1) != 0) {
      result.add('Alt');
    }

    if ((modifiers & 8) != 0) {
      result.add('Win');
    }

    if (virtualKey >= 0x41 &&
        virtualKey <= 0x5A) {
      result.add(
        String.fromCharCode(
          virtualKey,
        ),
      );
    } else if (virtualKey >= 0x30 &&
        virtualKey <= 0x39) {
      result.add(
        String.fromCharCode(
          virtualKey,
        ),
      );
    } else if (virtualKey >= 0x70 &&
        virtualKey <= 0x7B) {
      result.add(
        'F${virtualKey - 0x6F}',
      );
    }

    return result.join(' + ');
  }

  void _confirm() {
    if (!_valid ||
        _virtualKey == null) {
      return;
    }

    Navigator.of(context).pop(
      HotkeyResult(
        modifiers: _modifiers,
        virtualKey: _virtualKey!,
        display: _display,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return AlertDialog(
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(24),
      ),

      title:
          const Text(
        '修改快捷键',
      ),

      content:
          SizedBox(
        width: 420,

        child:
            Focus(
          focusNode:
              _focusNode,
          autofocus:
              true,
          onKeyEvent:
              _handleKeyEvent,

          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              Icon(
                Icons.keyboard_rounded,
                size: 42,
                color:
                    colors.primary,
              ),

              const SizedBox(
                height: 20,
              ),

              Text(
                '请按下新的快捷键',
                style:
                    theme
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w600,
                    ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                '例如 Ctrl + Alt + H',
                style:
                    theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color:
                          colors
                              .onSurfaceVariant,
                    ),
              ),

              const SizedBox(
                height: 24,
              ),

              AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 200,
                ),

                width:
                    double.infinity,

                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      colors
                          .surfaceContainerHighest,

                  borderRadius:
                      BorderRadius.circular(16),

                  border:
                      Border.all(
                    color:
                        _valid
                            ? colors.primary
                            : colors
                                .outlineVariant,
                    width:
                        _valid ? 2 : 1,
                  ),
                ),

                child:
                    Center(
                  child:
                      Text(
                    _display,
                    textAlign:
                        TextAlign.center,
                    style:
                        theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w600,
                          color:
                              _valid
                                  ? colors.primary
                                  : colors
                                      .onSurfaceVariant,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop();
          },
          child:
              const Text(
            '取消',
          ),
        ),

        FilledButton(
          onPressed:
              _valid
                  ? _confirm
                  : null,
          child:
              const Text(
            '确定',
          ),
        ),
      ],
    );
  }
}