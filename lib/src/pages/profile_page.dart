import '../core/services/app_strings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../core/repositories/known_words_repository.dart';
import '../core/services/language_service.dart';
import '../widgets/spotify_connect_button.dart';
import '../widgets/language_flag.dart';

/// Perfil com design Apple Settings & Health stats.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final LanguageService _languageService = LanguageService();
  final KnownWordsRepository _wordsRepo = KnownWordsRepository();

  String _appLanguage = 'en';
  ({int total, Map<String, int> perLanguage})? _stats;
  String t(String pt, String en) =>
      Localizations.localeOf(context).languageCode == 'pt' ? pt : en;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final appLanguage = await _languageService.getAppLanguage();
    final stats = await _wordsRepo.getVocabularyStats();
    if (mounted) {
      setState(() {
        _appLanguage = appLanguage;
        _stats = stats;
      });
    }
  }

  Future<void> _chooseAppLanguage() async {
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(tr(context, "App language")),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'en'),
            child: const Text('English'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'pt'),
            child: const Text('Português'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, "Cancel")),
        ),
      ),
    );
    if (selected == null) return;
    await AppLanguage.instance.set(selected);
    if (mounted) setState(() => _appLanguage = selected);
  }

  Future<void> _removeAllWordHistory() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(tr(context, "Remove all word history?")),
        content: Text(
          tr(
            context,
            "This will permanently remove every saved word from your dictionary.",
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, "Cancel")),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
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

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: AppTheme.fontSF,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    ),
  );

  Widget _groupedCard(BuildContext context, List<Widget> children) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            // Large Title Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text(
                tr(context, "Profile"),
                style: const TextStyle(
                  fontFamily: AppTheme.fontSF,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
            ),

            // Vocabulary Metrics
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _MetricCard(
                    value: '${_stats?.total ?? 0}',
                    label: t('Palavras aprendidas', 'Words learned'),
                    icon: CupertinoIcons.textformat_abc,
                    color: AppTheme.appleBlue,
                  ),
                  const SizedBox(width: 12),
                  _MetricCard(
                    value: '${_stats?.perLanguage.length ?? 0}',
                    label: t('Idiomas ativos', 'Active languages'),
                    icon: CupertinoIcons.globe,
                    color: AppTheme.spotifyGreen,
                  ),
                ],
              ),
            ),

            // By language
            if (_stats != null && _stats!.perLanguage.isNotEmpty) ...[
              _heading(t('Idiomas', 'Languages')),
              _groupedCard(
                context,
                [
                  for (final e in _stats!.perLanguage.entries) ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              LanguageFlag(
                                countryCode:
                                    LanguageService().findByCode(e.key)?.flagCode ??
                                    e.key,
                                width: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  localizedLanguageName(context, e.key),
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontSF,
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Text(
                                '${e.value} ${t('palavras', 'words')}',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontSF,
                                  color: colors.onSurfaceVariant,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _stats!.total > 0 ? e.value / _stats!.total : 0.0,
                              minHeight: 5,
                              backgroundColor: colors.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // Spotify Sync Card
            _heading('Spotify'),
            _groupedCard(
              context,
              const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: SpotifyConnectButton(showDisconnect: true),
                ),
              ],
            ),

            // Settings Inset Grouped
            _heading(tr(context, "Settings")),
            _groupedCard(
              context,
              [
                _SettingsRow(
                  icon: isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
                  iconColor: isDark ? const Color(0xFF5E5CE6) : const Color(0xFFFF9500),
                  title: isDark ? t('Modo Escuro', 'Dark Mode') : t('Modo Claro', 'Light Mode'),
                    trailing: CupertinoSwitch(
                      value: isDark,
                      onChanged: (val) async {
                        await AppThemeMode.instance.setLight(!val);
                        if (mounted) setState(() {});
                      },
                    ),
                ),
                Divider(color: Theme.of(context).dividerColor, height: 1),
                _SettingsRow(
                  icon: CupertinoIcons.globe,
                  iconColor: AppTheme.appleBlue,
                  title: tr(context, "App language"),
                  value: _appLanguage == 'pt' ? 'Português' : 'English',
                  onTap: _chooseAppLanguage,
                ),
                Divider(color: Theme.of(context).dividerColor, height: 1),
                _SettingsRow(
                  icon: CupertinoIcons.trash,
                  iconColor: AppTheme.appleRed,
                  title: t('Limpar histórico', 'Clear history'),
                  onTap: _removeAllWordHistory,
                ),
                Divider(color: Theme.of(context).dividerColor, height: 1),
                _SettingsRow(
                  icon: CupertinoIcons.info_circle,
                  iconColor: const Color(0xFF8E8E93),
                  title: t('Sobre o DropLyric', 'About DropLyric'),
                  value: 'v1.0.0',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'DropLyric',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(
                      CupertinoIcons.music_note_2,
                      size: 44,
                      color: AppTheme.spotifyGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontFamily: AppTheme.fontSF,
                color: colors.onSurface,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontSF,
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(icon, color: iconColor, size: 18),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: AppTheme.fontSF,
          color: colors.onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      trailing: trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                Text(
                  value!,
                  style: TextStyle(
                    fontFamily: AppTheme.fontSF,
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              const SizedBox(width: 6),
              Icon(
                CupertinoIcons.chevron_right,
                color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
    );
  }
}
