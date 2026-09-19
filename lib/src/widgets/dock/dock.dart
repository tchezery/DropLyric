import 'package:flutter/material.dart';

class DockItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const DockItem({required this.icon, this.activeIcon, required this.label});
}

/// Bottom navigation bar estilo Spotify — dark, minimal, sem glassmorphism.
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
    // Ignored legacy params
    double height = 76.0,
    double bottomMargin = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final colors = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: colors.surface,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(bottom: media.padding.bottom),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: colors.outlineVariant, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                _NowPlayingItem(item: nowPlayingItem!, onTap: onNowPlaying),
              if (nowPlayingItem != null)
                ...List.generate(items.length - items.length ~/ 2, (offset) {
                  final index = offset + items.length ~/ 2;
                  final item = items[index];
                  return _DockItem(
                    item: item,
                    isSelected: selectedIndex == index,
                    onTap: () => onItemSelected(index),
                  );
                }),
            ],
          ),
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
    final colors = Theme.of(context).colorScheme;
    final color = isSelected ? colors.primary : colors.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                color: color,
                size: 23,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: 0.1,
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
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(item.icon, color: colors.onPrimary, size: 23),
            ),
          ),
        ),
      ),
    );
  }
}
