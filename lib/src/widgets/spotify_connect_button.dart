import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/services/spotify_session.dart';

class SpotifyConnectButton extends StatelessWidget {
  const SpotifyConnectButton({
    super.key,
    this.session,
    this.compact = false,
    this.showDisconnect = false,
  });
  final SpotifySession? session;
  final bool compact;
  final bool showDisconnect;
  @override
  Widget build(BuildContext context) {
    final session = this.session ?? SpotifySession.instance;
    if (!session.supported) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (compact) {
          if (!session.fullyConnected) return const SizedBox.shrink();
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.checkmark_alt,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                '100% connected',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (session.connected && showDisconnect)
                OutlinedButton.icon(
                  icon: const Icon(CupertinoIcons.xmark_circle),
                  label: const Text('Disconnect'),
                  onPressed: session.initializing || session.connecting
                      ? null
                      : () => session.command('logout'),
                ),
              if (session.connected && !session.appRemoteAuthorized) ...[
                OutlinedButton.icon(
                  icon: const Icon(CupertinoIcons.music_note),
                  label: const Text('Continue with Spotify app'),
                  onPressed: session.initializing || session.connecting
                      ? null
                      : () => session.command('loginApp'),
                ),
              ],
              if (!session.connected) ...[
                OutlinedButton.icon(
                  icon: const Icon(CupertinoIcons.globe),
                  label: const Text('Continue with Web'),
                  onPressed: session.initializing || session.connecting
                      ? null
                      : () => session.command('loginWeb'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(CupertinoIcons.music_note),
                  label: const Text('Continue with Spotify app'),
                  onPressed: session.initializing || session.connecting
                      ? null
                      : () => session.command('loginApp'),
                ),
              ],
              if (session.error.isNotEmpty && !session.fullyConnected)
                Text(
                  session.error,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
            ],
          ),
        );
      },
    );
  }
}
