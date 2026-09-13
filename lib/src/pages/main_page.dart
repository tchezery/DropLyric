import 'package:flutter/material.dart';

import 'home_page.dart';
import 'search_page.dart';

import '../widgets/dock.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
{
  int _currentIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    SearchPage()
  ];

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: DockWidget(
        currentIndex: _currentIndex,
        onTab: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}