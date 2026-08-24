import 'package:flutter/material.dart';

enum MessageBubbleType {
  loading,
  success,
  error,
}

class AnimatedMessageBubble extends StatefulWidget {
  final String message;
  final MessageBubbleType type;
  final Duration visibleDuration;
  final VoidCallback onFinished;

  const AnimatedMessageBubble({
    super.key,
    required this.message,
    required this.type,
    required this.onFinished,
    this.visibleDuration =
        const Duration(
      milliseconds: 1500,
    ),
  });

  @override
  State<AnimatedMessageBubble> createState() =>
      _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState
    extends State<AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 360,
      ),
    );

    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _controller.forward();

    Future.delayed(
      widget.visibleDuration,
      () async {
        if (!mounted) {
          return;
        }

        await _controller.reverse();

        if (mounted) {
          widget.onFinished();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ==========================================================
  // Icon
  // ==========================================================

  Widget _buildIcon(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    switch (widget.type) {
      case MessageBubbleType.loading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: colors.primary,
          ),
        );

      case MessageBubbleType.success:
        return Icon(
          Icons.check_circle_outline_rounded,
          size: 22,
          color: colors.primary,
        );

      case MessageBubbleType.error:
        return Icon(
          Icons.error_outline_rounded,
          size: 22,
          color: colors.error,
        );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final textStyle =
        theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colors.onSurfaceVariant,
            ) ??
            TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.onSurfaceVariant,
            );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 32,
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _progress,
            builder: (
              context,
              child,
            ) {
              final progress =
                  _progress.value;

              // ------------------------------------------------
              // Calculate target width.
              // ------------------------------------------------

              final painter =
                  TextPainter(
                text: TextSpan(
                  text: widget.message,
                  style: textStyle,
                ),
                textDirection:
                    TextDirection.ltr,
                maxLines: 1,
              )..layout();

              const iconSize = 22.0;
              const gap = 10.0;
              const horizontalPadding = 18.0;

              final targetWidth =
                  iconSize +
                  gap +
                  painter.width +
                  horizontalPadding * 2;

              const minWidth = 46.0;
              const height = 46.0;

              final width =
                  minWidth +
                  (targetWidth - minWidth) *
                      progress;

              final radius =
                  23.0 -
                  (9.0 * progress);

              // ------------------------------------------------
              // Content only becomes visible after the bubble
              // is large enough.
              // This prevents Flutter's overflow warning during
              // the opening animation.
              // ------------------------------------------------

              final contentProgress =
                  ((progress - 0.70) / 0.30)
                      .clamp(
                0.0,
                1.0,
              );

              return Container(
                width: width,
                height: height,

                clipBehavior:
                    Clip.antiAlias,

                decoration:
                    BoxDecoration(
                  color:
                      colors.surfaceContainerHighest,

                  borderRadius:
                      BorderRadius.circular(
                    radius,
                  ),

                  border:
                      Border.all(
                    color:
                        colors.outlineVariant
                            .withValues(
                      alpha: 0.45,
                    ),
                  ),

                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(
                        alpha:
                            theme.brightness ==
                                    Brightness.dark
                                ? 0.30
                                : 0.12,
                      ),
                      blurRadius: 18,
                      offset:
                          const Offset(
                        0,
                        6,
                      ),
                    ),
                  ],
                ),

                child: Center(
                  child: Opacity(
                    opacity:
                        Curves.easeOut.transform(
                      contentProgress,
                    ),

                    child: Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: iconSize,
                          height: iconSize,
                          child: Center(
                            child:
                                _buildIcon(
                              context,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: gap,
                        ),

                        Text(
                          widget.message,
                          maxLines: 1,
                          softWrap: false,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              textStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}