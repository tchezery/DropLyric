import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../core/repositories/known_words_repository.dart';
import '../core/services/language_service.dart';
import '../widgets/lyrics/language_selector_sheet.dart';

/// Perfil no estilo Spotify.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final LanguageService _languageService = LanguageService();
  final KnownWordsRepository _wordsRepo = KnownWordsRepository();

  String _nativeLanguage = 'pt';
  String _targetLanguage = 'en';
  ({int total, Map<String, int> perLanguage})? _stats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final native = await _languageService.getNativeLanguage();
    final target = await _languageService.getTargetLanguage();
    final stats = await _wordsRepo.getVocabularyStats();
    if (mounted) {
      setState(() {
        _nativeLanguage = native;
        _targetLanguage = target;
        _stats = stats;
      });
    }
  }

  Future<void> _onLanguagesUpdated(String native, String target) async {
    await _languageService.setNativeLanguage(native);
    await _languageService.setTargetLanguage(target);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final nativeLang = _languageService.findByCode(_nativeLanguage);
    final targetLang = _languageService.findByCode(_targetLanguage);

    return Scaffold(
      backgroundColor: AppTheme.spotifyBlack,
      body: CustomScrollView(
        slivers: [
          // Header com gradiente verde
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.sheet, AppTheme.spotifyBlack],
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
                      const Text(
                        'Profile',
                        style: TextStyle(
                          color: AppTheme.spotifyWhite,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Avatar + nome
                      Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: AppTheme.spotifyMediumGray,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.person,
                              color: AppTheme.spotifyLightGray,
                              size: 44,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Estudante',
                                style: TextStyle(
                                  color: AppTheme.spotifyWhite,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${nativeLang?.name ?? _nativeLanguage} (${_nativeLanguage.toUpperCase()})',
                                style: const TextStyle(
                                  color: AppTheme.spotifyLightGray,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
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
                  const Text(
                    'Progresso',
                    style: TextStyle(
                      color: AppTheme.spotifyWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatCard(
                        value: '${_stats?.total ?? 0}',
                        label: 'Known\nWords',
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        value: '${_stats?.perLanguage.length ?? 0}',
                        label: 'Practiced\nLanguages',
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
                    const Text(
                      'By language',
                      style: TextStyle(
                        color: AppTheme.spotifyWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._stats!.perLanguage.entries.map((e) {
                      final lang = _languageService.findByCode(e.key);
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
                                  '${lang?.name ?? e.key} (${e.key.toUpperCase()})',
                                  style: const TextStyle(
                                    color: AppTheme.spotifyWhite,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${e.value} words',
                                  style: const TextStyle(
                                    color: AppTheme.spotifyGreen,
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
                                backgroundColor: AppTheme.spotifyMediumGray,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.spotifyGreen,
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
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: AppTheme.spotifyWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: CupertinoIcons.globe,
                    title: 'Study languages',
                    subtitle:
                        '${nativeLang?.name ?? _nativeLanguage} (${_nativeLanguage.toUpperCase()}) → '
                        '${targetLang?.name ?? _targetLanguage} (${_targetLanguage.toUpperCase()})',
                    onTap: () => LanguageSelectorSheet.show(
                      context,
                      currentNativeLanguage: _nativeLanguage,
                      currentTargetLanguage: _targetLanguage,
                      languageService: _languageService,
                      onConfirm: _onLanguagesUpdated,
                    ),
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.info,
                    title: 'About Droplyric',
                    subtitle: 'Learn languages with music — v1.0.0',
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'Droplyric',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Icon(
                        CupertinoCupertinoIcons.music_note,
                        size: 48,
                        color: AppTheme.spotifyGreen,
                      ),
                      children: [
                        const Text(
                          'Listen to music, read the lyrics, and mark the words you already know to build your vocabulary.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
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
          color: AppTheme.spotifyDarkCard,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.spotifyGreen,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.spotifyLightGray,
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
      leading: Icon(icon, color: AppTheme.spotifyLightGray),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.spotifyWhite,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.spotifyLightGray, fontSize: 12),
      ),
      trailing: const Icon(
        CupertinoCupertinoIcons.chevron_right,
        color: AppTheme.spotifyLightGray,
      ),
    );
  }
}
