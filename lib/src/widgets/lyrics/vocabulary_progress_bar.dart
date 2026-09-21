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
    final progress = totalCount == 0 ? 0.0 : (knownCount / totalCount).clamp(0.0, 1.0);
    final percentage = (progress * 100).round();
    final isComplete = totalCount > 0 && knownCount >= totalCount;

    final labelColor = widget.isLightMode
        ? AppTheme.secondaryLabelLight
        : AppTheme.secondaryLabelDark;
    final trackColor = widget.isLightMode
        ? const Color(0xFFE5E5EA)
        : const Color(0xFF2C2C2E);
    final fillColor = isComplete
        ? AppTheme.spotifyGreen
        : (widget.isLightMode ? Colors.black : Colors.white);
    final badgeBg = isComplete
        ? AppTheme.spotifyGreen
        : (widget.isLightMode ? const Color(0xFFE9E9EB) : const Color(0xFF2C2C2E));
    final badgeText = isComplete
        ? Colors.black
        : (widget.isLightMode ? Colors.black : Colors.white);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr(context, "Vocabulary"),
                style: TextStyle(
                  fontFamily: AppTheme.fontSF,
                  color: labelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Container(
                  key: ValueKey('$knownCount/$totalCount'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_celebrating) ...[
                        const Icon(Icons.check_circle, color: Colors.black, size: 13),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '$knownCount/$totalCount · $percentage%',
                        style: TextStyle(
                          fontFamily: AppTheme.fontSF,
                          color: badgeText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: trackColor,
              valueColor: AlwaysStoppedAnimation<Color>(fillColor),
            ),
          ),
        ],
      ),
    );
  }
}
