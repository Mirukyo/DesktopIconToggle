import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/message_bubble.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  // ==========================================================
  // Application information
  // ==========================================================

  static const String repositoryOwner = 'Mirukyo';

  static const String repositoryName = 'DesktopIconToggle';

  static final Uri githubUri = Uri.parse(
    'https://github.com/Mirukyo/DesktopIconToggle',
  );

  static final Uri websiteUri = Uri.parse('https://soyoo.top/');

  String _currentVersion = '';

  OverlayEntry? _loadingEntry;

  // ==========================================================
  // Lifecycle
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _loadVersion();
  }

  @override
  void dispose() {
    _hideLoadingMessage();
    super.dispose();
  }

  // ==========================================================
  // Load application version
  // ==========================================================

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentVersion = packageInfo.version;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _currentVersion = '未知';
      });
    }
  }

  // ==========================================================
  // Open URL
  // ==========================================================

  Future<void> _openUrl(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ==========================================================
  // Show persistent loading bubble
  // ==========================================================

  void _showLoadingMessage() {
    if (!mounted || _loadingEntry != null) {
      return;
    }

    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) {
        return AnimatedMessageBubble(
          message: '正在检查更新...',
          type: MessageBubbleType.loading,
          visibleDuration: const Duration(days: 1),
          onFinished: () {
            if (entry.mounted) {
              entry.remove();
            }
          },
        );
      },
    );

    _loadingEntry = entry;

    overlay.insert(entry);
  }

  // ==========================================================
  // Hide loading bubble
  // ==========================================================

  void _hideLoadingMessage() {
    final entry = _loadingEntry;

    _loadingEntry = null;

    if (entry != null && entry.mounted) {
      entry.remove();
    }
  }

  // ==========================================================
  // Show result message
  // ==========================================================

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) {
      return;
    }

    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) {
        return AnimatedMessageBubble(
          message: message,
          type: error ? MessageBubbleType.error : MessageBubbleType.success,
          onFinished: () {
            if (entry.mounted) {
              entry.remove();
            }
          },
        );
      },
    );

    overlay.insert(entry);
  }

  // ==========================================================
  // Check for updates
  // ==========================================================

  Future<void> _checkForUpdates() async {
    if (!mounted ||
        _loadingEntry != null ||
        _currentVersion.isEmpty ||
        _currentVersion == '未知') {
      return;
    }

    _showLoadingMessage();

    try {
      final release = await _fetchLatestRelease().timeout(
        const Duration(seconds: 10),
      );

      if (!mounted) {
        return;
      }

      _hideLoadingMessage();

      if (release == null) {
        _showMessage('检查更新失败，请稍后再试', error: true);

        return;
      }

      final latestVersion = release.tagName;

      if (_compareVersions(latestVersion, _currentVersion) > 0) {
        await _showUpdateDialog(release: release);
      } else {
        _showMessage('当前已是最新版本');
      }
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      _hideLoadingMessage();

      _showMessage('检查更新超时，请稍后再试', error: true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _hideLoadingMessage();

      _showMessage('检查更新失败，请稍后再试', error: true);
    }
  }

  // ==========================================================
  // GitHub latest release
  // ==========================================================

  Future<_ReleaseInfo?> _fetchLatestRelease() async {
    final uri = Uri.parse(
      'https://api.github.com/repos/'
      '$repositoryOwner/'
      '$repositoryName/'
      'releases/latest',
    );

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);

    try {
      final request = await client.getUrl(uri);

      request.headers.set(HttpHeaders.userAgentHeader, 'DesktopIconToggle');

      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );

      final response = await request.close();

      if (response.statusCode != 200) {
        return null;
      }

      final body = await response.transform(utf8.decoder).join();

      final json = jsonDecode(body);

      if (json is! Map<String, dynamic>) {
        return null;
      }

      final tagName = json['tag_name'];

      final releaseBody = json['body'];

      final htmlUrl = json['html_url'];

      if (tagName is! String || htmlUrl is! String) {
        return null;
      }

      return _ReleaseInfo(
        tagName: _normalizeVersion(tagName),
        body: releaseBody is String ? releaseBody.trim() : '',
        htmlUrl: htmlUrl,
      );
    } finally {
      client.close();
    }
  }

  // ==========================================================
  // Normalize version
  // ==========================================================

  String _normalizeVersion(String version) {
    var result = version.trim();

    if (result.startsWith('v') || result.startsWith('V')) {
      result = result.substring(1);
    }

    return result;
  }

  // ==========================================================
  // Compare versions
  // ==========================================================

  int _compareVersions(String a, String b) {
    final aParts = _parseVersion(a);

    final bParts = _parseVersion(b);

    for (var i = 0; i < 3; i++) {
      if (aParts[i] > bParts[i]) {
        return 1;
      }

      if (aParts[i] < bParts[i]) {
        return -1;
      }
    }

    return 0;
  }

  List<int> _parseVersion(String version) {
    final normalized = _normalizeVersion(version);

    final mainVersion = normalized.split('-').first;

    final parts = mainVersion.split('.');

    return [
      _parseVersionPart(parts, 0),
      _parseVersionPart(parts, 1),
      _parseVersionPart(parts, 2),
    ];
  }

  int _parseVersionPart(List<String> parts, int index) {
    if (index >= parts.length) {
      return 0;
    }

    return int.tryParse(parts[index]) ?? 0;
  }

  // ==========================================================
  // Update dialog
  // ==========================================================

  Future<void> _showUpdateDialog({required _ReleaseInfo release}) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) {
        final theme = Theme.of(context);

        final colors = theme.colorScheme;

        return AlertDialog(
          title: const Text('发现新版本'),

          content: SizedBox(
            width: 520,
            height: 360,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'v${release.tagName}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  '版本更新内容',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(16),

                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,

                      borderRadius: BorderRadius.circular(16),

                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),

                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        child: MarkdownBody(
                          data: release.body.isEmpty
                              ? '本次更新没有提供详细说明。'
                              : release.body,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet.fromTheme(theme)
                              .copyWith(
                                p: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.55,
                                ),
                                h1: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                                h2: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                                h3: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                                listBullet: theme.textTheme.bodyMedium
                                    ?.copyWith(height: 1.55),
                                listIndent: 20,
                                blockSpacing: 10,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();

                _openUrl(Uri.parse(release.htmlUrl));
              },
              child: const Text('前往下载'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // Build
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final versionReady = _currentVersion.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(36, 32, 36, 40),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // ==================================================
          // Title
          // ==================================================

          Text(
            '关于',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 28),

          // ==================================================
          // Hero
          // ==================================================
          Container(
            width: double.infinity,

            padding: const EdgeInsets.all(32),

            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,

              borderRadius: BorderRadius.circular(28),

              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.35),
              ),
            ),

            child: Row(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Icon(
                    Icons.desktop_windows_rounded,
                    size: 48,
                    color: colors.onPrimaryContainer,
                  ),
                ),

                const SizedBox(width: 28),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '桌面图标开关',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'DesktopIconToggle',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 14),

                      _VersionChip(
                        label: versionReady ? 'v$_currentVersion' : '读取版本中...',
                        color: colors.primary,
                      ),

                      const SizedBox(height: 14),

                      Text(
                        '一个简单、快速的 Windows 桌面小工具，'
                        '让桌面图标随时隐藏或显示。',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ==================================================
          // GitHub / Website
          // ==================================================
          Row(
            children: [
              Expanded(
                child: _LinkCard(
                  icon: Icons.code_rounded,
                  title: 'GitHub',
                  subtitle: '项目主页',
                  onTap: () => _openUrl(githubUri),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: _LinkCard(
                  icon: Icons.language_rounded,
                  title: '网站',
                  subtitle: 'soyoo.top',
                  onTap: () => _openUrl(websiteUri),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ==================================================
          // Check update
          // ==================================================
          SizedBox(
            width: double.infinity,

            child: Material(
              color: colors.surfaceContainerLow,

              borderRadius: BorderRadius.circular(20),

              child: InkWell(
                onTap: versionReady ? _checkForUpdates : null,

                borderRadius: BorderRadius.circular(20),

                child: Padding(
                  padding: const EdgeInsets.all(20),

                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.system_update_alt_rounded,
                          color: colors.primary,
                          size: 22,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '检查更新',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 3),

                            Text(
                              versionReady ? '检查 GitHub 是否有新版本' : '正在读取当前版本...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ==================================================
          // Information
          // ==================================================
          Container(
            width: double.infinity,

            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,

              borderRadius: BorderRadius.circular(22),

              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),

            child: Column(
              children: [
                const _InfoTile(title: '开发者', value: 'Mirukyo'),

                const _InfoDivider(),

                const _InfoTile(
                  title: '技术',
                  value: 'Flutter · Dart · C++ · CMake',
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Center(
            child: Column(
              children: [
                Text(
                  '基于 Flutter + C++ 构建',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '© 2026 Mirukyo',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Version chip
// ============================================================

class _VersionChip extends StatelessWidget {
  final String label;
  final Color color;

  const _VersionChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),

        borderRadius: BorderRadius.circular(100),
      ),

      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================
// Link card
// ============================================================

class _LinkCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_LinkCard> createState() => _LinkCardState();
}

class _LinkCardState extends State<_LinkCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },

      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),

        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),

        child: Material(
          color: _hovered
              ? colors.primaryContainer.withValues(alpha: 0.45)
              : colors.surfaceContainerLow,

          borderRadius: BorderRadius.circular(20),

          child: InkWell(
            onTap: widget.onTap,

            borderRadius: BorderRadius.circular(20),

            child: Padding(
              padding: const EdgeInsets.all(20),

              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,

                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.10),

                      borderRadius: BorderRadius.circular(14),
                    ),

                    child: Icon(widget.icon, color: colors.primary, size: 22),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          widget.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Information tile
// ============================================================

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;

  const _InfoTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),

      child: Row(
        children: [
          SizedBox(
            width: 110,

            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Information divider
// ============================================================

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 22,
      endIndent: 22,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.35),
    );
  }
}

// ============================================================
// Release information
// ============================================================

class _ReleaseInfo {
  final String tagName;
  final String body;
  final String htmlUrl;

  const _ReleaseInfo({
    required this.tagName,
    required this.body,
    required this.htmlUrl,
  });
}
