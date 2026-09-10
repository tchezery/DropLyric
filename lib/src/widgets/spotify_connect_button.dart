import 'package:flutter/material.dart';

import '../core/services/spotify_session.dart';

class SpotifyConnectButton extends StatelessWidget {
  const SpotifyConnectButton({super.key});
  @override
  Widget build(BuildContext context) {
    final session = SpotifySession.instance;
    if (!session.supported) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              icon: Icon(
                session.connected ? Icons.check_circle : Icons.music_note,
              ),
              label: Text(
                session.connected
                    ? 'Spotify conectado · Desconectar'
                    : 'Conectar Spotify Premium',
              ),
              onPressed: () async {
                try {
                  await session.command(session.connected ? 'logout' : 'login');
                } catch (_) {
                  /* O erro é exibido abaixo pelo estado da sessão. */
                }
              },
            ),
            if (session.error.isNotEmpty)
              Text(
                session.error,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
          ],
        ),
      ),
    );
  }
}
