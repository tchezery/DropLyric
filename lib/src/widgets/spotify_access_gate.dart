import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../core/services/app_strings.dart';
import '../core/services/spotify_session.dart';
import 'spotify_connect_button.dart';
import 'spotify_icon.dart';

/// Mantém as músicas ocultas até a conexão Spotify.
class SpotifyAccessGate extends StatelessWidget {
  const SpotifyAccessGate({super.key, required this.child, this.session});

  final Widget child;
  final SpotifySession? session;

  @override
  Widget build(BuildContext context) {
    final session = this.session ?? SpotifySession.instance;
    if (session.remoteOnly) return child;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final colors = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        if (session.initializing) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SpotifyIcon(size: 44),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      tr(context, "Restoring your Spotify session…"),
                      style: TextStyle(
                        fontFamily: AppTheme.fontSF,
                        color: colors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (session.connected) return child;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 100),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SpotifyIcon(size: 52),
                      const SizedBox(height: 18),
                      Text(
                        tr(context, "Connect Spotify to browse and search for music."),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.fontSF,
                          color: colors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SpotifyConnectButton(session: session),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
