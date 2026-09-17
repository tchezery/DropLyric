import 'package:flutter/material.dart';

// --- Pages section ---
import 'src/pages/login_page.dart';
import 'src/pages/main_page.dart';

abstract class AppRoutes 
{
  static const loginPage = "/login"; 
  static const mainPage = "/";
  static const lyricPage = "/lyric";
}

class Routes extends StatelessWidget 
{
  const Routes({super.key});

  @override
  Widget build(BuildContext context)
  {
    return MaterialApp(
      title: 'DropLyric',
      // theme: ThemeData(
      //   brightness: Brightness.dark,
      //   scaffoldBackgroundColor: Colors.black,
      // ),
      initialRoute: AppRoutes.loginPage,
      routes: 
      {
        AppRoutes.loginPage: (context) => const LoginPage(),
        AppRoutes.mainPage: (context) => const MainPage(),
      },
    );
  }
}