import 'package:flutter/material.dart';

class NavigationPane extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const NavigationPane({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: 190,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: colors.outlineVariant.withValues(
              alpha: 0.45,
            ),
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(
            height: 24,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.desktop_windows_rounded,
                    size: 22,
                    color:
                        colors.onPrimaryContainer,
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child: Text(
                    '桌面图标\n隐藏工具',
                    style: theme
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          NavigationItem(
            icon: Icons.home_rounded,
            label: '首页',
            selected: selectedIndex == 0,
            onTap: () => onSelected(0),
          ),

          NavigationItem(
            icon: Icons.settings_rounded,
            label: '设置',
            selected: selectedIndex == 1,
            onTap: () => onSelected(1),
          ),

          NavigationItem(
            icon: Icons.info_outline_rounded,
            label: '关于',
            selected: selectedIndex == 2,
            onTap: () => onSelected(2),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

// ============================================================
// Navigation item
// ============================================================

class NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const NavigationItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 2,
      ),
      child: Material(
        color: selected
            ? colors.secondaryContainer
            : Colors.transparent,
        borderRadius:
            BorderRadius.circular(14),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: selected
                      ? colors
                          .onSecondaryContainer
                      : colors.onSurfaceVariant,
                ),

                const SizedBox(
                  width: 12,
                ),

                Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: selected
                        ? colors
                            .onSecondaryContainer
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}