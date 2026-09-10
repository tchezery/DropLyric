import 'package:flutter/material.dart';

import '../src/pages/home_page.dart';
import '../src/pages/library_page.dart';

import '../src/pages/profile_page.dart';
import '../src/pages/search_page.dart';

class AppRoutes {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();
  static final ValueNotifier<String> currentRoute = ValueNotifier<String>(home);

  static const home = '/';
  static const search = '/search';
  static const library = '/library';
  static const profile = '/profile';
  static const player = '/player';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Mantém rastreamento da rota ativa para o Dock global
    if (settings.name != null) {
      currentRoute.value = settings.name!;
    }

    switch (settings.name) {
      case home:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomePage(),
          transitionDuration: Duration.zero,
        );
      case search:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const SearchPage(),
          transitionDuration: Duration.zero,
        );
      case library:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LibraryPage(),
          transitionDuration: Duration.zero,
        );
      case profile:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const ProfilePage(),
          transitionDuration: Duration.zero,
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Rota não encontrada'))),
        );
    }
  }

  static void navigateTo(String route) {
    if (currentRoute.value == route) return;
    navigatorKey.currentState?.pushReplacementNamed(route);
  }

  /// Rotas onde o Dock NÃO deve ser exibido (modo imersivo).
  static bool shouldShowDock(String route) {
    return route != player;
  }
}
