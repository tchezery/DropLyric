import '../../core/services/app_strings.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class VocabularyProgressBar extends StatefulWidget {
  final int knownCount;
  final int totalCount;
  final bool isLightMode;

  const VocabularyProgressBar({
    super.key,
    required this.knownCount,
    required this.totalCount,
    this.isLightMode = true,
  });

  @override
  State<VocabularyProgressBar> createState() => _VocabularyProgressBarState();
}

class _VocabularyProgressBarState extends State<VocabularyProgressBar> {
  bool _celebrating = false;

  @override
  void didUpdateWidget(covariant VocabularyProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasComplete = oldWidget.totalCount > 0 &&
        oldWidget.knownCount >= oldWidget.totalCount;
    final isComplete = widget.totalCount > 0 &&
        widget.knownCount >= widget.totalCount;
    if (!wasComplete && isComplete) {
      setState(() => _celebrating = true);
      Future<void>.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _celebrating = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final knownCount = widget.knownCount;
    final totalCount = widget.totalCount;
    final progress = totalCount == 0 ? 0.0 : knownCount / totalCount;
    final percentage = (progress * 100).round();
    final isComplete = totalCount > 0 && knownCount >= totalCount;

    final labelColor = widget.isLightMode ? const Color(0xFF8E8E93) : AppTheme.spotifyLightGray;
    final badgeBg = isComplete
        ? const Color(0xFF2E9B55)
        : (widget.isLightMode ? Colors.black : AppTheme.spotifyGreen);
    final badgeText = isComplete || !widget.isLightMode ? Colors.white : Colors.white;
    final trackColor = widget.isLightMode ? const Color(0xFFE5E5EA) : AppTheme.spotifyMediumGray;
    final fillColor = isComplete
        ? const Color(0xFF2E9B55)
        : (widget.isLightMode ? Colors.black : AppTheme.spotifyGreen);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr(context, "Vocabulary"),
                style: TextStyle(
                  color: labelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey('$knownCount/$totalCount'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_celebrating) ...[
                        const Icon(Icons.check_circle, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                      ],
                      Text('$knownCount/$totalCount · $percentage%', style: TextStyle(
                        color: badgeText, fontSize: 11, fontWeight: FontWeight.w700,
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: trackColor,
                valueColor: AlwaysStoppedAnimation<Color>(fillColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
