import '../widgets/spotify_access_gate.dart';

import 'package:flutter/cupertino.dart';

import '../widgets/spotify_connect_button.dart';
import '../core/services/spotify_session.dart';

import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../core/models/track_model.dart';
import '../core/services/spotify_service.dart';
import '../core/services/youtube_music_service.dart';
import 'player_page.dart';

/// Music notebook with grouped, Notes-inspired rows.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _service;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _selectService(String service) async {
    setState(() => _service = service);
    if (service == 'spotify') {
      await SpotifySession.instance.command('loginWeb');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_service == null) return _buildRequiredChoiceScreen();
    final tracks = SpotifyService.curatedTracks;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 20, 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'DropLyric',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    if (_service == 'spotify')
                      const SpotifyConnectButton(compact: true),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Learn new languages.',
                  style: TextStyle(color: AppTheme.muted, fontSize: 15),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildServiceSelector()),
            if (_service == 'spotify')
              const SliverToBoxAdapter(child: SpotifyConnectButton()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.music_note_list,
                      color: AppTheme.yellow,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'All songs',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${tracks.length}',
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Material(
                    color: AppTheme.sheet,
                    child: Column(
                      children: [
                        for (var i = 0; i < tracks.length; i++) ...[
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            leading: const Icon(
                              CupertinoIcons.music_note,
                              color: AppTheme.yellow,
                            ),
                            title: Text(
                              tracks[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                            ),
                            subtitle: Text(
                              tracks[i].artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 14,
                              ),
                            ),
                            trailing: const Icon(
                              CupertinoIcons.chevron_right,
                              color: AppTheme.muted,
                              size: 18,
                            ),
                            onTap: () => _openPlayer(context, tracks[i]),
                          ),
                          if (i < tracks.length - 1)
                            const Divider(height: 1, indent: 58),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  Widget _buildRequiredChoiceScreen() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'DropLyric',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Entre para começar a usar o DropLyric.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _selectService('spotify'),
                    icon: const Icon(Icons.music_note),
                    label: const Text('Entrar com Spotify'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _selectService('youtube'),
                    icon: const Icon(Icons.ondemand_video),
                    label: const Text('Entrar com YouTube Music'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'spotify',
            label: Text('Spotify'),
            icon: Icon(Icons.music_note),
          ),
          ButtonSegment(
            value: 'youtube',
            label: Text('YouTube Music'),
            icon: Icon(Icons.ondemand_video),
          ),
        ],
        selected: {_service!},
        onSelectionChanged: (selection) => _selectService(selection.first),
      ),
    );
  }

  Future<void> _openPlayer(BuildContext context, TrackModel track) async {
    if (_service == 'youtube') {
      final opened = await YouTubeMusicService.openTrack(track);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o YouTube Music.'),
          ),
        );
      }
      return;
    }
    if (SpotifySession.instance.connected) {
      try {
        track = await SpotifySession.instance.resolve(track);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'It was not possible to open the track. Try searching for it.',
              ),
            ),
          );
        }
        return;
      }
    }
    if (!context.mounted) return;
    final previous = AppRoutes.currentRoute.value;
    AppRoutes.currentRoute.value = AppRoutes.player;
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.player),
        builder: (_) => SpotifyAccessGate(child: PlayerPage(track: track)),
      ),
    );
    AppRoutes.currentRoute.value = previous;
  }
}
