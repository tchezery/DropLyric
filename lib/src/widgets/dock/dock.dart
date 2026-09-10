import 'package:flutter/material.dart';

import '../../../app/theme.dart';

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

  const Dock({
    super.key,
    this.isVisible = true,
    this.selectedIndex = 0,
    required this.onItemSelected,
    required this.items,
    // Ignored legacy params
    double height = 76.0,
    double bottomMargin = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final media = MediaQuery.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: AppTheme.spotifyBlack,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(bottom: media.padding.bottom),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.separator, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = selectedIndex == index;

              return _DockItem(
                item: item,
                isSelected: isSelected,
                onTap: () => onItemSelected(index),
              );
            }),
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
    final color = isSelected ? AppTheme.yellow : AppTheme.spotifyLightGray;

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
