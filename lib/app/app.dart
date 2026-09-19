import '../src/core/services/app_strings.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import '../src/widgets/dock/dock.dart';
import '../src/core/services/spotify_session.dart';
import '../src/core/services/language_service.dart';
import '../src/pages/onboarding_page.dart';
import '../src/widgets/spotify_icon.dart';
import 'routes.dart';
import 'theme.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _onboardingLoading = true;
  bool _languageSelected = false;
  bool _onboardingFinished = false;

  @override
  void initState() {
    super.initState();
    AppLanguage.instance.addListener(_refreshOnboarding);
    AppThemeMode.instance.addListener(_refreshOnboarding);
    SpotifySession.instance.addListener(_refreshOnboarding);
    _loadOnboarding();
  }

  @override
  void dispose() {
    AppLanguage.instance.removeListener(_refreshOnboarding);
    AppThemeMode.instance.removeListener(_refreshOnboarding);
    SpotifySession.instance.removeListener(_refreshOnboarding);
    super.dispose();
  }

  Future<void> _loadOnboarding() async {
    final selected = await LanguageService().hasAppLanguage();
    if (!mounted) return;
    setState(() {
      _languageSelected = selected;
      _onboardingLoading = false;
      _onboardingFinished = selected && SpotifySession.instance.connected;
    });
  }

  void _refreshOnboarding() {
    if (_onboardingLoading || !mounted) return;
    final selected = _languageSelected || AppLanguage.instance.loaded;
    final finished = selected && SpotifySession.instance.connected;
    if (selected != _languageSelected || finished != _onboardingFinished) {
      setState(() {
        _languageSelected = selected;
        _onboardingFinished = finished;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppLanguage.instance,
        AppThemeMode.instance,
      ]),
      builder: (context, _) => MaterialApp(
        title: 'DropLyric',
        locale: Locale(AppLanguage.instance.code),
        supportedLocales: const [Locale('en'), Locale('pt')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        debugShowCheckedModeBanner: false,
        // Apenas tema escuro — estilo Spotify
        theme: AppTheme.notesTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: AppThemeMode.instance.isLight
            ? ThemeMode.light
            : ThemeMode.dark,
        navigatorKey: AppRoutes.navigatorKey,
        navigatorObservers: [AppRoutes.routeObserver],
        initialRoute: AppRoutes.home,
        onGenerateRoute: AppRoutes.generateRoute,
        builder: (context, child) {
          // Define a cor da status bar para o tema dark
          SystemChrome.setSystemUIOverlayStyle(
            const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
          );

          return Stack(
            children: [
              // O Navigator ocupa toda a tela
              Positioned.fill(child: child ?? const SizedBox.shrink()),
              // O Dock flutua sobre o conteúdo (oculto no modo player)
              ValueListenableBuilder<String>(
                valueListenable: AppRoutes.currentRoute,
                builder: (context, route, _) {
                  final selectedIndex = _getRouteIndex(route);

                  return ListenableBuilder(
                    listenable: SpotifySession.instance,
                    builder: (context, _) {
                      final spotify = SpotifySession.instance;
                      final hasCurrentTrack = RegExp(
                        r'^spotify:track:[a-zA-Z0-9]{22}$',
                      ).hasMatch(spotify.uri);
                      if (!AppRoutes.shouldShowDock(route) &&
                          spotify.connected) {
                        return const SizedBox.shrink();
                      }
                      final items = <DockItem>[
                        DockItem(
                          icon: CupertinoIcons.music_note_list,
                          activeIcon: CupertinoIcons.music_note_list,
                          label: tr(context, "Home"),
                        ),
                        DockItem(
                          icon: CupertinoIcons.search,
                          activeIcon: CupertinoIcons.search,
                          label: AppLanguage.instance.isPortuguese
                              ? 'Buscar'
                              : 'Search',
                        ),
                        DockItem(
                          icon: CupertinoIcons.book,
                          activeIcon: CupertinoIcons.book,
                          label: tr(context, "Dictionary"),
                        ),
                        DockItem(
                          icon: Icons.person_outline_rounded,
                          activeIcon: CupertinoIcons.person,
                          label: tr(context, "Profile"),
                        ),
                      ];
                      return Dock(
                        selectedIndex: selectedIndex,
                        onItemSelected: (index) {
                          AppRoutes.navigateTo(_getRouteByIndex(index));
                        },
                        items: items,
                        nowPlayingItem: hasCurrentTrack
                            ? DockItem(
                                icon: CupertinoIcons.music_note_2,
                                label: tr(context, "Lyrics"),
                              )
                            : null,
                        onNowPlaying: hasCurrentTrack
                            ? AppRoutes.openCurrentTrack
                            : null,
                      );
                    },
                  );
                },
              ),
              ListenableBuilder(
                listenable: SpotifySession.instance,
                builder: (context, _) {
                  final spotify = SpotifySession.instance;
                  final colors = Theme.of(context).colorScheme;
                  if (spotify.error.isEmpty || spotify.connected) {
                    return const SizedBox.shrink();
                  }
                  return Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.all(28),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SpotifyIcon(size: 48),
                              const SizedBox(height: 14),
                              Text(
                                tr(context, "Spotify connection required"),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                spotify.error,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                icon: const SpotifyIcon(size: 18, color: Colors.black),
                                label: Text(tr(context, "Reconnect Spotify")),
                                onPressed: spotify.connecting
                                    ? null
                                    : () => spotify.command('loginWeb'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (!_onboardingLoading && !_onboardingFinished)
                Positioned.fill(
                  child: OnboardingPage(
                    languageSelected: _languageSelected,
                    onFinished: _refreshOnboarding,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static int _getRouteIndex(String route) {
    switch (route) {
      case AppRoutes.home:
        return 0;
      case AppRoutes.search:
        return 1;
      case AppRoutes.library:
        return 2;
      case AppRoutes.profile:
        return 3;
      default:
        return 0;
    }
  }

  static String _getRouteByIndex(int index) {
    switch (index) {
      case 0:
        return AppRoutes.home;
      case 1:
        return AppRoutes.search;
      case 2:
        return AppRoutes.library;
      case 3:
        return AppRoutes.profile;
      default:
        return AppRoutes.home;
    }
  }
}
