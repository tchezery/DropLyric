import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Barra de vocabulário elegante compatível com o tema Stoic e Dark.
class VocabularyProgressBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final progress = totalCount == 0 ? 0.0 : knownCount / totalCount;
    final percentage = (progress * 100).round();

    final labelColor = isLightMode ? const Color(0xFF8E8E93) : AppTheme.spotifyLightGray;
    final badgeBg = isLightMode ? Colors.black : AppTheme.spotifyGreen;
    final badgeText = isLightMode ? Colors.white : Colors.black;
    final trackColor = isLightMode ? const Color(0xFFE5E5EA) : AppTheme.spotifyMediumGray;
    final fillColor = isLightMode ? Colors.black : AppTheme.spotifyGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vocabulary',
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
                  child: Text(
                    '$knownCount/$totalCount · $percentage%',
                    style: TextStyle(
                      color: badgeText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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
