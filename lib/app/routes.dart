import '../src/widgets/spotify_access_gate.dart';

import 'package:flutter/material.dart';

import '../src/pages/home_page.dart';
import '../src/pages/library_page.dart';

import '../src/pages/games_page.dart';
import '../src/pages/profile_page.dart';
import '../src/pages/search_page.dart';
import '../src/pages/player_page.dart';
import '../src/core/models/track_model.dart';
import '../src/core/services/spotify_session.dart';

class AppRouteObserver extends RouteObserver<PageRoute> {
  static final ValueNotifier<int> popupRouteCount = ValueNotifier<int>(0);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PopupRoute) {
      popupRouteCount.value++;
    } else if (route.settings.name != null && AppRoutes.isTabRoute(route.settings.name)) {
      AppRoutes.currentRoute.value = route.settings.name!;
      AppRoutes.lastContentRoute = route.settings.name!;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is PopupRoute && popupRouteCount.value > 0) {
      popupRouteCount.value--;
    } else if (previousRoute != null &&
        previousRoute.settings.name != null &&
        AppRoutes.isTabRoute(previousRoute.settings.name)) {
      AppRoutes.currentRoute.value = previousRoute.settings.name!;
      AppRoutes.lastContentRoute = previousRoute.settings.name!;
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (route is PopupRoute && popupRouteCount.value > 0) {
      popupRouteCount.value--;
    } else if (previousRoute != null &&
        previousRoute.settings.name != null &&
        AppRoutes.isTabRoute(previousRoute.settings.name)) {
      AppRoutes.currentRoute.value = previousRoute.settings.name!;
      AppRoutes.lastContentRoute = previousRoute.settings.name!;
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    var count = popupRouteCount.value;
    if (oldRoute is PopupRoute && count > 0) count--;
    if (newRoute is PopupRoute) count++;
    popupRouteCount.value = count;

    if (newRoute != null &&
        newRoute.settings.name != null &&
        AppRoutes.isTabRoute(newRoute.settings.name)) {
      AppRoutes.currentRoute.value = newRoute.settings.name!;
      AppRoutes.lastContentRoute = newRoute.settings.name!;
    }
  }
}

class AppRoutes {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final AppRouteObserver routeObserver = AppRouteObserver();
  static final ValueNotifier<String> currentRoute = ValueNotifier<String>(home);
  static String lastContentRoute = home;

  static const home = '/';
  static const search = '/search';
  static const games = '/games';
  static const library = '/library';
  static const profile = '/profile';
  static const player = '/player';

  static bool isTabRoute(String? route) {
    return route == home ||
        route == search ||
        route == games ||
        route == library ||
        route == profile;
  }

  static void restoreLastTabRoute() {
    currentRoute.value = isTabRoute(lastContentRoute) ? lastContentRoute : home;
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Mantém rastreamento da rota ativa para o Dock global
    final name = settings.name ?? '';
    final isCallback =
        name.contains('callback') ||
        name.startsWith('droplyric:') ||
        name.startsWith('/callback');

    if (settings.name != null && !isCallback) {
      if (isTabRoute(settings.name)) {
        lastContentRoute = settings.name!;
      }
      if (currentRoute.value != settings.name!) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (currentRoute.value != settings.name!) {
            currentRoute.value = settings.name!;
          }
        });
      }
    }

    // Trata retornos do Safari / Spotify Deep Links (ex: droplyric://callback?code=...)
    if (isCallback) {
      if (currentRoute.value == AppRoutes.player ||
          lastContentRoute == AppRoutes.player) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.maybePop();
        });
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const SizedBox.shrink(),
          transitionDuration: Duration.zero,
        );
      }
      currentRoute.value = AppRoutes.search;
      lastContentRoute = AppRoutes.search;
      return PageRouteBuilder(
        settings: const RouteSettings(name: AppRoutes.search),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SpotifyAccessGate(child: SearchPage()),
        transitionDuration: Duration.zero,
      );
    }

    switch (settings.name) {
      case home:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const SpotifyAccessGate(child: HomePage()),
          transitionDuration: Duration.zero,
        );
      case search:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const SpotifyAccessGate(child: SearchPage()),
          transitionDuration: Duration.zero,
        );
      case games:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const GamesPage(),
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
        currentRoute.value = AppRoutes.home;
        lastContentRoute = AppRoutes.home;
        return PageRouteBuilder(
          settings: const RouteSettings(name: AppRoutes.home),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const SpotifyAccessGate(child: HomePage()),
          transitionDuration: Duration.zero,
        );
    }
  }

  static void navigateTo(String route) {
    currentRoute.value = route;
    if (isTabRoute(route)) {
      lastContentRoute = route;
    }
    navigatorKey.currentState?.pushReplacementNamed(route);
  }

  static Future<void> openCurrentTrack() async {
    final session = SpotifySession.instance;
    final uri = session.uri;
    if (!session.connected ||
        !RegExp(r'^spotify:track:[a-zA-Z0-9]{22}$').hasMatch(uri)) {
      return;
    }
    final track = await session.resolve(
      TrackModel(
        id: uri,
        title: '',
        artist: '',
        album: '',
        previewAudioUrl: null,
      ),
    );
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    final previous = isTabRoute(currentRoute.value) ? currentRoute.value : lastContentRoute;
    currentRoute.value = player;
    try {
      await navigator.push(
        MaterialPageRoute(
          settings: const RouteSettings(name: player),
          builder: (_) => SpotifyAccessGate(
            child: PlayerPage(track: track, followCurrent: true),
          ),
        ),
      );
    } finally {
      currentRoute.value = previous;
      lastContentRoute = previous;
    }
  }

  /// Rotas onde o Dock NÃO deve ser exibido (modo imersivo).
  static bool shouldShowDock(String route) {
    return route != player;
  }
}
