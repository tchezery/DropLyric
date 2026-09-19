import '../core/services/app_strings.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../core/repositories/known_words_repository.dart';
import '../core/services/language_service.dart';
import '../widgets/spotify_connect_button.dart';

/// Perfil no estilo Spotify.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final LanguageService _languageService = LanguageService();
  final KnownWordsRepository _wordsRepo = KnownWordsRepository();

  String _appLanguage = 'en';
  bool _isLightTheme = true;
  ({int total, Map<String, int> perLanguage})? _stats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final appLanguage = await _languageService.getAppLanguage();
    final isLightTheme = AppThemeMode.instance.isLight;
    final stats = await _wordsRepo.getVocabularyStats();
    if (mounted) {
      setState(() {
        _appLanguage = appLanguage;
        _isLightTheme = isLightTheme;
        _stats = stats;
      });
    }
  }

  Future<void> _chooseAppLanguage() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr(context, "App language")),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'en'),
            child: const Text('English'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'pt'),
            child: const Text('Português'),
          ),
        ],
      ),
    );
    if (selected == null) return;
    await AppLanguage.instance.set(selected);
    if (mounted) setState(() => _appLanguage = selected);
  }

  Future<void> _removeAllWordHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, "Remove all word history?")),
        content: Text(
          tr(
            context,
            "This will permanently remove every saved word from your dictionary.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, "Cancel")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, "Remove all")),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _wordsRepo.clearAll();
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header com gradiente verde
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.surface,
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, "Profile"),
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Stats de vocabulário
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, "Progress"),
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatCard(
                        value: '${_stats?.total ?? 0}',
                        label: tr(context, "Known\nWords"),
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        value: '${_stats?.perLanguage.length ?? 0}',
                        label: tr(context, "Practiced\nLanguages"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Por idioma
          if (_stats != null && _stats!.perLanguage.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, "By language"),
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._stats!.perLanguage.entries.map((e) {
                      final total = _stats!.total;
                      final pct = total > 0 ? e.value / total : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${localizedLanguageName(context, e.key)} (${e.key.toUpperCase()})',
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${e.value} ${tr(context, 'words')}',
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 3,
                                backgroundColor: colors.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

          // Configurações
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, "Settings"),
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SpotifyConnectButton(showDisconnect: true),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: _isLightTheme
                        ? CupertinoIcons.moon
                        : CupertinoIcons.sun_max,
                    title: _isLightTheme
                        ? tr(context, "Dark mode")
                        : tr(context, "Paper mode"),
                    subtitle: tr(context, "Use this theme throughout the app"),
                    onTap: () async {
                      await AppThemeMode.instance.setLight(!_isLightTheme);
                      if (mounted) {
                        setState(() => _isLightTheme = !_isLightTheme);
                      }
                    },
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.textformat,
                    title: tr(context, "App language"),
                    subtitle: _appLanguage == 'pt' ? 'Português' : 'English',
                    onTap: _chooseAppLanguage,
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.delete,
                    title: tr(context, "Remove all word history"),
                    subtitle: tr(context, "Delete every saved word"),
                    onTap: _removeAllWordHistory,
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.info,
                    title: tr(context, "About DropLyric"),
                    subtitle: tr(
                      context,
                      "Learn languages with music — v1.0.0",
                    ),
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'DropLyric',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Icon(
                        CupertinoIcons.music_note,
                        size: 48,
                        color: AppTheme.spotifyGreen,
                      ),
                      children: [
                        Text(
                          tr(
                            context,
                            "Listen to music, read the lyrics, and mark the words you already know to build your vocabulary.",
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: const SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
