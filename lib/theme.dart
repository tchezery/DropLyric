import 'package:flutter/material.dart';

class ThemeOsListener extends ChangeNotifier
{
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setTheme(ThemeMode mode)
  {
    _themeMode = mode;
    notifyListeners();
  } 
}