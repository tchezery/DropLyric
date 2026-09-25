import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class DockItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const DockItem({required this.icon, this.activeIcon, required this.label});
}

/// Floating Apple-style tab bar with translucent frosted glass blur and rounded edges.
class Dock extends StatelessWidget {
  final bool isVisible;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<DockItem> items;
  final DockItem? nowPlayingItem;
  final VoidCallback? onNowPlaying;

  const Dock({
    super.key,
    this.isVisible = true,
    this.selectedIndex = 0,
    required this.onItemSelected,
    required this.items,
    this.nowPlayingItem,
    this.onNowPlaying,
    double height = 76.0,
    double bottomMargin = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Efeito de continuidade: blur suave com fade gradual atrás da dock
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 85 + bottomPadding,
              child: IgnorePointer(
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x33FFFFFF),
                        Colors.white,
                      ],
                      stops: [0.0, 0.35, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              surfaceColor.withValues(alpha: 0.0),
                              surfaceColor.withValues(alpha: isDark ? 0.35 : 0.45),
                              surfaceColor.withValues(alpha: isDark ? 0.75 : 0.85),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Dock flutuante com visual translúcido refinado e drop shadow externa
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xD91C1C1E)
                              : const Color(0xE6FFFFFF),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: isDark
                                ? const Color(0x33FFFFFF)
                                : const Color(0x1F000000),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ...List.generate(
                              nowPlayingItem == null ? items.length : items.length ~/ 2,
                              (index) {
                                final item = items[index];
                                return _DockItem(
                                  item: item,
                                  isSelected: selectedIndex == index,
                                  onTap: () => onItemSelected(index),
                                );
                              },
                            ),
                            if (nowPlayingItem != null)
                              _NowPlayingItem(
                                item: nowPlayingItem!,
                                onTap: onNowPlaying,
                              ),
                            if (nowPlayingItem != null)
                              ...List.generate(
                                items.length - items.length ~/ 2,
                                (offset) {
                                  final index = offset + items.length ~/ 2;
                                  final item = items[index];
                                  return _DockItem(
                                    item: item,
                                    isSelected: selectedIndex == index,
                                    onTap: () => onItemSelected(index),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final DockItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _DockItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: TextStyle(
                  fontFamily: AppTheme.fontSF,
                  color: isSelected ? activeColor : inactiveColor,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NowPlayingItem extends StatelessWidget {
  final DockItem item;
  final VoidCallback? onTap;

  const _NowPlayingItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppTheme.appleBlue,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(item.icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
