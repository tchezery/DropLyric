import '../core/services/app_strings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme.dart';
import '../core/repositories/known_words_repository.dart';
import '../core/services/auth_service.dart';
import '../core/services/language_service.dart';
import '../core/services/quiz_service.dart';
import '../core/services/sync_service.dart';
import '../widgets/spotify_connect_button.dart';
import '../widgets/language_flag.dart';
import '../widgets/about_modal.dart';

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
  QuizFrequency _quizFrequency = QuizFrequency.regular;
  ({int total, Map<String, int> perLanguage})? _stats;
  String t(String pt, String en) =>
      Localizations.localeOf(context).languageCode == 'pt' ? pt : en;

  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    AuthService.instance.addListener(_onAuthChanged);
    KnownWordsRepository.changes.addListener(_onWordsChanged);
  }

  @override
  void dispose() {
    KnownWordsRepository.changes.removeListener(_onWordsChanged);
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onWordsChanged() {
    if (mounted) {
      _loadData();
    }
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() {});
      _loadData();
    }
  }

  bool _isLoadingStats = false;

  Future<void> _loadData() async {
    if (_isLoadingStats) return;
    _isLoadingStats = true;
    try {
      final appLanguage = await _languageService.getAppLanguage();
      final quizFreq = await QuizService.instance.getFrequency();
      final stats = await _wordsRepo.getVocabularyStats();
      if (mounted) {
        setState(() {
          _appLanguage = appLanguage;
          _quizFrequency = quizFreq;
          _stats = stats;
        });
      }
    } catch (e) {
      debugPrint('[ProfilePage] Erro ao carregar dados: $e');
    } finally {
      _isLoadingStats = false;
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

  String _quizFrequencyLabel(QuizFrequency freq) {
    switch (freq) {
      case QuizFrequency.always:
        return t('Sempre', 'Always');
      case QuizFrequency.regular:
        return t('Regularmente', 'Regularly');
      case QuizFrequency.rare:
        return t('Pouco', 'Rarely');
    }
  }

  Future<void> _chooseQuizFrequency() async {
    final selected = await showCupertinoModalPopup<QuizFrequency>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(t('Frequência do Quick Quiz', 'Quick Quiz frequency')),
        message: Text(
          t(
            'Escolha com que frequência você deseja praticar após as músicas ou na tela de início.',
            'Choose how often you want vocabulary quizzes to appear after songs or on the home screen.',
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, QuizFrequency.always),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t('Sempre (100%)', 'Always (100%)')),
                if (_quizFrequency == QuizFrequency.always) ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 18),
                ],
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, QuizFrequency.regular),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t('Regularmente (~70%)', 'Regularly (~70%)')),
                if (_quizFrequency == QuizFrequency.regular) ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 18),
                ],
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, QuizFrequency.rare),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t('Pouco (~30%)', 'Rarely (~30%)')),
                if (_quizFrequency == QuizFrequency.rare) ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 18),
                ],
              ],
            ),
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
    await QuizService.instance.setFrequency(selected);
    HapticFeedback.lightImpact();
    if (mounted) setState(() => _quizFrequency = selected);
  }

  Future<void> _chooseTranslationLanguage() async {
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(t('Idioma de tradução', 'Translation language')),
        message: Text(
          t(
            'Escolha o idioma para o qual as letras e palavras serão traduzidas',
            'Choose the language that lyrics and words will be translated to',
          ),
        ),
        actions: supportedLanguages.map((lang) {
          final isCurrent = lang.code == TranslationLanguage.instance.code;
          return CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, lang.code),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LanguageFlag(countryCode: lang.flagCode, width: 22),
                const SizedBox(width: 8),
                Text(
                  lang.name,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
                    color: isCurrent ? AppTheme.spotifyGreen : null,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, "Cancel")),
        ),
      ),
    );
    if (selected == null) return;
    await TranslationLanguage.instance.set(selected);
    if (mounted) setState(() {});
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

  Future<void> _signIn() async {
    setState(() => _signingIn = true);
    final success = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _signingIn = false);
    if (success) {
      SyncService.instance.syncAll(onComplete: () {
        if (mounted) _loadData();
      }).ignore();
      await _loadData();
    } else if (AuthService.instance.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao conectar: ${AuthService.instance.lastError}',
            style: const TextStyle(fontSize: 13),
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (mounted) setState(() {});
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t('Excluir Conta', 'Delete Account')),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            t(
              'Tem certeza de que deseja excluir sua conta? Seus dados sincronizados na nuvem serão excluídos permanentemente. Esta ação não pode ser desfeita.',
              'Are you sure you want to delete your account? Your cloud-synced data will be permanently deleted. This action cannot be undone.',
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Cancelar', 'Cancel')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('Excluir', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final success = await AuthService.instance.deleteAccount();
    if (!mounted) return;

    if (success) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            t('Conta e dados excluídos com sucesso.', 'Account and data successfully deleted.'),
          ),
          backgroundColor: AppTheme.spotifyGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            t('Erro ao excluir conta. Tente novamente.', 'Error deleting account. Try again.'),
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

            // ─── Conta ────────────────────────────────────────────────
            _heading(t('Conta', 'Account')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _AccountCard(
                auth: AuthService.instance,
                signingIn: _signingIn,
                onSignIn: _signIn,
                onSignOut: _signOut,
              ),
            ),
            const SizedBox(height: 16),

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

            // Sync Card
            _heading(t('Sincronizar', 'Sync')),
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
                  icon: CupertinoIcons.chat_bubble_2_fill,
                  iconColor: AppTheme.spotifyGreen,
                  title: t('Idioma de tradução', 'Translation language'),
                  value: TranslationLanguage.instance.displayName,
                  onTap: _chooseTranslationLanguage,
                ),
                Divider(color: Theme.of(context).dividerColor, height: 1),
                _SettingsRow(
                  icon: CupertinoIcons.sparkles,
                  iconColor: const Color(0xFFFF9500),
                  title: t('Frequência do Quick Quiz', 'Quick Quiz frequency'),
                  value: _quizFrequencyLabel(_quizFrequency),
                  onTap: _chooseQuizFrequency,
                ),
                Divider(color: Theme.of(context).dividerColor, height: 1),
                _SettingsRow(
                  icon: CupertinoIcons.trash,
                  iconColor: AppTheme.appleRed,
                  title: t('Limpar histórico', 'Clear history'),
                  onTap: _removeAllWordHistory,
                ),
                if (AuthService.instance.isSignedIn) ...[
                  Divider(color: Theme.of(context).dividerColor, height: 1),
                  _SettingsRow(
                    icon: CupertinoIcons.person_crop_circle_badge_minus,
                    iconColor: AppTheme.appleRed,
                    title: t('Excluir conta', 'Delete account'),
                    onTap: _deleteAccount,
                  ),
                ],
                Divider(color: Theme.of(context).dividerColor, height: 1),
                _SettingsRow(
                  icon: CupertinoIcons.info_circle,
                  iconColor: const Color(0xFF8E8E93),
                  title: t('Sobre o DropLyric', 'About DropLyric'),
                  value: 'v1.0.0',
                  onTap: () => AboutAppModal.show(context),
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

/// Card de conta do usuário — mostra o estado de login e botões de ação.
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.auth,
    required this.signingIn,
    required this.onSignIn,
    required this.onSignOut,
  });

  final AuthService auth;
  final bool signingIn;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    final borderColor =
        isDark ? const Color(0x26FFFFFF) : const Color(0x14000000);
    final cardColor = colors.surface;

    if (auth.isSignedIn) {
      return _SignedInCard(
        auth: auth,
        cardColor: cardColor,
        borderColor: borderColor,
        isDark: isDark,
        onSignOut: onSignOut,
      );
    }

    return _SignedOutCard(
      cardColor: cardColor,
      borderColor: borderColor,
      isDark: isDark,
      signingIn: signingIn,
      onSignIn: onSignIn,
    );
  }
}

class _SignedInCard extends StatelessWidget {
  const _SignedInCard({
    required this.auth,
    required this.cardColor,
    required this.borderColor,
    required this.isDark,
    required this.onSignOut,
  });

  final AuthService auth;
  final Color cardColor;
  final Color borderColor;
  final bool isDark;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = auth.avatarUrl;
    final name = auth.displayName ?? auth.email ?? '—';
    final email = auth.email ?? '';

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.appleBlue.withValues(alpha: 0.15),
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl) : null,
            onBackgroundImageError:
                avatarUrl != null ? (exception, stackTrace) {} : null,
            child: avatarUrl == null
                ? const Icon(
                    CupertinoIcons.person_fill,
                    color: AppTheme.appleBlue,
                    size: 28,
                  )
                : null,
          ),
          const SizedBox(width: 14),
          // Nome e email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSF,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 13,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppTheme.spotifyGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Sincronizado',
                      style: TextStyle(
                        fontFamily: AppTheme.fontSF,
                        fontSize: 12,
                        color: AppTheme.spotifyGreen.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Botão sair
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onSignOut,
            child: Text(
              'Sair',
              style: TextStyle(
                fontFamily: AppTheme.fontSF,
                fontSize: 14,
                color: AppTheme.appleRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard({
    required this.cardColor,
    required this.borderColor,
    required this.isDark,
    required this.signingIn,
    required this.onSignIn,
  });

  final Color cardColor;
  final Color borderColor;
  final bool isDark;
  final bool signingIn;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.person_crop_circle,
            size: 48,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            'Crie uma conta para sincronizar\nseu vocabulário e histórico\nentre dispositivos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontSF,
              fontSize: 14,
              height: 1.45,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: _GoogleSignInButton(
              loading: signingIn,
              onPressed: signingIn ? null : onSignIn,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão "Continuar com o Google" com logo oficial e estilo premium.
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({this.onPressed, this.loading = false});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF48484A) : const Color(0xFFE0E0E0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Google (SVG inline via CustomPaint)
                  _GoogleLogo(size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Continuar com o Google',
                    style: TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1F1F1F),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

const String _googleLogoSvg =
    '<svg viewBox="0 0 24 24" width="24" height="24" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>'
    '<path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>'
    '<path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z" fill="#FBBC05"/>'
    '<path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z" fill="#EA4335"/>'
    '</svg>';

/// Logo oficial do Google em vetor SVG nítido.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _googleLogoSvg,
      width: size,
      height: size,
    );
  }
}
