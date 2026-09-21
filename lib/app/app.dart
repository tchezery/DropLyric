import '../src/core/services/app_strings.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../src/widgets/dock/dock.dart';
import '../src/core/services/spotify_session.dart';
import '../src/core/services/language_service.dart';
import '../src/pages/onboarding_page.dart';
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
    // Remove o splash nativo apenas após o primeiro frame renderizado + um pequeno
    // delay proposital (estilo Spotify) para a logo "pousar" na tela.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 1500));
      FlutterNativeSplash.remove();
    });
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
    final completed = await LanguageService().isOnboardingComplete();
    if (!mounted) return;
    setState(() {
      _languageSelected = selected;
      _onboardingLoading = false;
      _onboardingFinished =
          selected && (completed || SpotifySession.instance.connected);
    });
  }

  void _refreshOnboarding() async {
    if (_onboardingLoading || !mounted) return;
    final selected = _languageSelected || AppLanguage.instance.loaded;
    final completed = await LanguageService().isOnboardingComplete();
    final finished =
        selected && (completed || SpotifySession.instance.connected);
    if (!mounted) return;
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
          final isNativeMacOS =
              !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
          final mediaQuery = MediaQuery.of(context);
          final updatedMediaQuery = isNativeMacOS
              ? mediaQuery.copyWith(
                  padding: mediaQuery.padding.copyWith(
                    top: mediaQuery.padding.top + 28.0,
                  ),
                  viewPadding: mediaQuery.viewPadding.copyWith(
                    top: mediaQuery.viewPadding.top + 28.0,
                  ),
                )
              : mediaQuery;

          // Define a cor da status bar para o tema dark
          SystemChrome.setSystemUIOverlayStyle(
            const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
          );

          return MediaQuery(
            data: updatedMediaQuery,
            child: Stack(
              children: [
                // O Navigator ocupa toda a tela
                Positioned.fill(child: child ?? const SizedBox.shrink()),
              // O Dock flutua sobre o conteúdo (oculto no modo player ou quando há popups/modais abertos)
              ValueListenableBuilder<int>(
                valueListenable: AppRouteObserver.popupRouteCount,
                builder: (context, popupCount, _) {
                  if (popupCount > 0) {
                    return const SizedBox.shrink();
                  }

                  return ValueListenableBuilder<String>(
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
                          if (!AppRoutes.shouldShowDock(route)) {
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
          ),
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
