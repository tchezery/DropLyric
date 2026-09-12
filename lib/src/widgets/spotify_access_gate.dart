import 'package:flutter/material.dart';

import '../core/services/spotify_session.dart';
import 'spotify_connect_button.dart';

/// Mantém as músicas ocultas até a conexão, sem bloquear o dock.
class SpotifyAccessGate extends StatelessWidget {
  const SpotifyAccessGate({super.key, required this.child, this.session});

  final Widget child;
  final SpotifySession? session;

  @override
  Widget build(BuildContext context) {
    final session = this.session ?? SpotifySession.instance;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.initializing) {
          return const Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Restoring your Spotify session…'),
                  ],
                ),
              ),
            ),
          );
        }
        if (session.connected) return child;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.music_note, size: 48),
                    const SizedBox(height: 20),
                    const Text(
                      'Connect Spotify to browse and search for music.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SpotifyConnectButton(session: session),
                    const SizedBox(height: 12),
                    const Text(
                      'Your profile and dictionary remain available below.',
                      textAlign: TextAlign.center,
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
