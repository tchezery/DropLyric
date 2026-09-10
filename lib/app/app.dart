import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../src/widgets/dock/dock.dart';
import 'routes.dart';
import 'theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Droplyric',
      debugShowCheckedModeBanner: false,
      // Apenas tema escuro — estilo Spotify
      theme: AppTheme.notesTheme,
      darkTheme: AppTheme.notesTheme,
      themeMode: ThemeMode.light,
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
                if (!AppRoutes.shouldShowDock(route)) {
                  return const SizedBox.shrink();
                }

                final selectedIndex = _getRouteIndex(route);

                return Dock(
                  selectedIndex: selectedIndex,
                  onItemSelected: (index) {
                    final targetRoute = _getRouteByIndex(index);
                    AppRoutes.navigateTo(targetRoute);
                  },
                  items: const [
                    DockItem(
                      icon: Icons.folder_outlined,
                      activeIcon: Icons.folder_outlined,
                      label: 'Início',
                    ),
                    DockItem(
                      icon: Icons.search_rounded,
                      activeIcon: Icons.search_rounded,
                      label: 'Buscar',
                    ),
                    DockItem(
                      icon: Icons.menu_book_outlined,
                      activeIcon: Icons.menu_book_outlined,
                      label: 'Dictionary',
                    ),
                    DockItem(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Perfil',
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
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
