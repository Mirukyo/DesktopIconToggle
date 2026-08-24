import 'package:flutter/material.dart';

// ============================================================
// Quick info card
// ============================================================

class QuickInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const QuickInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),

            const SizedBox(height: 16),

            Text(
              title,
              style:
                  theme.textTheme.bodyMedium?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              value,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  theme.textTheme.titleMedium?.copyWith(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Section card
// ============================================================

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 4,
            bottom: 10,
          ),
          child: Text(
            title,
            style:
                theme.textTheme.titleMedium?.copyWith(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),

        Card(
          clipBehavior:
              Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: child,
        ),
      ],
    );
  }
}

// ============================================================
// Setting tile
// ============================================================

class SettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 12,
      ),

      title: Text(
        title,
        style: const TextStyle(
          fontWeight:
              FontWeight.w500,
        ),
      ),

      subtitle: Padding(
        padding: const EdgeInsets.only(
          top: 4,
        ),
        child: Text(
          subtitle,
          style: TextStyle(
            color:
                colors.onSurfaceVariant,
          ),
        ),
      ),

      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}