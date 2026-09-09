import 'package:flutter/material.dart';

/// Standard, highly accessible back navigation button for ShilpSetu.
///
/// Designed with a generous >= 48dp touch target, high contrast icon,
/// and consistent placement across all non-root screens.
class AppBackButton extends StatelessWidget {
  final Color? color;
  final VoidCallback? onPressed;
  final String tooltip;

  const AppBackButton({
    super.key,
    this.color = Colors.white,
    this.onPressed,
    this.tooltip = 'पीछे जाएं (Back)',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded, size: 24),
      color: color,
      tooltip: tooltip,
      splashRadius: 24,
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: onPressed ?? () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    );
  }
}
