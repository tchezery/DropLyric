import '../../app/theme.dart';
import '../core/services/app_strings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/services/spotify_session.dart';
import 'spotify_icon.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppTheme.labelDark : AppTheme.labelLight;
    final secondaryTextColor = isDark ? AppTheme.secondaryLabelDark : AppTheme.secondaryLabelLight;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.remoteOnly && !compact) {
          final pt = Localizations.localeOf(context).languageCode == 'pt';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!session.fullyConnected || showDisconnect)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: session.connecting
                        ? null
                        : () async {
                            try {
                              await session.command(
                                session.connected && showDisconnect
                                    ? 'logout'
                                    : 'loginApp',
                              );
                            } catch (_) {}
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SpotifyIcon(size: 18),
                          const SizedBox(width: 8),
                          Text(
                            session.connecting
                                ? (pt ? 'Conectando…' : 'Connecting…')
                                : session.connected && showDisconnect
                                ? (pt ? 'Desconectar' : tr(context, "Disconnect"))
                                : (pt
                                      ? 'Conectar ao Spotify'
                                      : 'Connect Spotify'),
                            style: TextStyle(
                              fontFamily: '.SF Pro Text',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (session.error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      session.error,
                      style: const TextStyle(
                        fontFamily: '.SF Pro Text',
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
        if (compact) {
          if (!session.fullyConnected) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.spotifyGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SpotifyIcon(size: 14),
                const SizedBox(width: 5),
                Text(
                  tr(context, "connected"),
                  style: const TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.spotifyGreen,
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (session.connected && showDisconnect)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: session.initializing || session.connecting
                      ? null
                      : () => session.command('logout'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.xmark_circle, size: 16, color: secondaryTextColor),
                        const SizedBox(width: 6),
                        Text(
                          tr(context, "Disconnect"),
                          style: TextStyle(
                            fontFamily: '.SF Pro Text',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (session.connected && !session.appRemoteAuthorized) ...[
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: session.initializing || session.connecting
                      ? null
                      : () => session.command('loginApp'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SpotifyIcon(size: 16),
                        const SizedBox(width: 6),
                        Text(
                          tr(context, "Continue with Spotify app"),
                          style: TextStyle(
                            fontFamily: '.SF Pro Text',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (!session.connected) ...[
                Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: session.initializing || session.connecting
                          ? null
                          : () => session.command('loginWeb'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.globe, size: 16, color: AppTheme.appleBlue),
                            const SizedBox(width: 6),
                            Text(
                              tr(context, "Continue with Web"),
                              style: TextStyle(
                                fontFamily: '.SF Pro Text',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: session.initializing || session.connecting
                          ? null
                          : () => session.command('loginApp'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SpotifyIcon(size: 16),
                            const SizedBox(width: 6),
                            Text(
                              tr(context, "Spotify app"),
                              style: TextStyle(
                                fontFamily: '.SF Pro Text',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (session.error.isNotEmpty && !session.fullyConnected)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    session.error,
                    style: const TextStyle(
                      fontFamily: '.SF Pro Text',
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
