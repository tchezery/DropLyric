import '../core/services/app_strings.dart';

import 'package:flutter/material.dart';

import '../core/services/spotify_session.dart';
import 'spotify_connect_button.dart';
import 'spotify_icon.dart';

/// Mantém as músicas ocultas até a conexão, sem bloquear o dock.
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
        if (session.initializing) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SpotifyIcon(size: 48),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(tr(context, "Restoring your Spotify session…")),
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SpotifyIcon(size: 56),
                    const SizedBox(height: 20),
                    Text(
                      tr(
                        context,
                        "Connect Spotify to browse and search for music.",
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurface),
                    ),
                    const SizedBox(height: 12),
                    SpotifyConnectButton(session: session),
                    const SizedBox(height: 12),
                    Text(
                      tr(
                        context,
                        "Your profile and dictionary remain available below.",
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
