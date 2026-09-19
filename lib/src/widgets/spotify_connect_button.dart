import '../core/services/app_strings.dart';
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
        if (session.remoteOnly && !compact) {
          final pt = Localizations.localeOf(context).languageCode == 'pt';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!session.fullyConnected || showDisconnect)
                  OutlinedButton.icon(
                    icon: const Icon(CupertinoIcons.music_note),
                    label: Text(
                      session.connecting
                          ? (pt ? 'Conectando…' : 'Connecting…')
                          : session.connected && showDisconnect
                          ? (pt ? 'Desconectar' : tr(context, "Disconnect"))
                          : (pt
                                ? 'Conectar ao app Spotify'
                                : 'Connect to Spotify app'),
                    ),
                    onPressed: session.connecting
                        ? null
                        : () async {
                            try {
                              await session.command(
                                session.connected && showDisconnect
                                    ? 'logout'
                                    : 'loginApp',
                              );
                            } catch (_) {
                              /* The session exposes the native error below. */
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
          );
        }
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
              Text(
                tr(context, "100% connected"),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
                  label: Text(tr(context, "Disconnect")),
                  onPressed: session.initializing || session.connecting
                      ? null
                      : () => session.command('logout'),
                ),
              if (session.connected && !session.appRemoteAuthorized) ...[
                OutlinedButton.icon(
                  icon: const Icon(CupertinoIcons.music_note),
                  label: Text(tr(context, "Continue with Spotify app")),
                  onPressed: session.initializing || session.connecting
                      ? null
                      : () => session.command('loginApp'),
                ),
              ],
              if (!session.connected) ...[
                OutlinedButton.icon(
                  icon: const Icon(CupertinoIcons.globe),
                  label: Text(tr(context, "Continue with Web")),
                  onPressed: session.initializing || session.connecting
                      ? null
                      : () => session.command('loginWeb'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(CupertinoIcons.music_note),
                  label: Text(tr(context, "Continue with Spotify app")),
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
