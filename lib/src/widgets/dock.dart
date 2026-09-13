import 'package:flutter/material.dart';

class DockWidget extends StatelessWidget
{
  final int currentIndex;
  final ValueChanged<int> onTab;

  const DockWidget({ super.key, required this.currentIndex, required this.onTab });

  @override
  Widget build(BuildContext context)
  {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTab,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.indigo,
      unselectedItemColor: Colors.grey,
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
        BottomNavigationBarItem(icon: Icon(Icons.language), label: 'Vocabulary'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}