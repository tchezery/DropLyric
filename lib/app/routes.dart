import '../src/widgets/spotify_access_gate.dart';

import 'package:flutter/material.dart';

import '../src/pages/home_page.dart';
import '../src/pages/library_page.dart';

import '../src/pages/profile_page.dart';
import '../src/pages/search_page.dart';
import '../src/pages/player_page.dart';
import '../src/core/models/track_model.dart';
import '../src/core/services/spotify_session.dart';

class AppRoutes {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();
  static final ValueNotifier<String> currentRoute = ValueNotifier<String>(home);
  static String _lastContentRoute = home;

  static const home = '/';
  static const search = '/search';
  static const library = '/library';
  static const profile = '/profile';
  static const player = '/player';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Mantém rastreamento da rota ativa para o Dock global
    final name = settings.name ?? '';
    final isCallback =
        name.contains('callback') ||
        name.startsWith('droplyric:') ||
        name.startsWith('/callback');

    if (settings.name != null && !isCallback) {
      _lastContentRoute = settings.name!;
      currentRoute.value = settings.name!;
    }

    // Trata retornos do Safari / Spotify Deep Links (ex: droplyric://callback?code=...)
    if (isCallback) {
      if (currentRoute.value == AppRoutes.player ||
          _lastContentRoute == AppRoutes.player) {
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
        return PageRouteBuilder(
          settings: const RouteSettings(name: AppRoutes.home),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const SpotifyAccessGate(child: HomePage()),
          transitionDuration: Duration.zero,
        );
    }
  }

  static void navigateTo(String route) {
    if (currentRoute.value == route) return;
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
    currentRoute.value = player;
    await navigator.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: player),
        builder: (_) => SpotifyAccessGate(
          child: PlayerPage(track: track, followCurrent: true),
        ),
      ),
    );
  }

  /// Rotas onde o Dock NÃO deve ser exibido (modo imersivo).
  static bool shouldShowDock(String route) {
    return route != player;
  }
}
