import '../core/services/app_strings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../core/repositories/known_words_repository.dart';
import '../core/services/auth_service.dart';
import '../core/services/language_service.dart';
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
  ({int total, Map<String, int> perLanguage})? _stats;
  String t(String pt, String en) =>
      Localizations.localeOf(context).languageCode == 'pt' ? pt : en;

  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    AuthService.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
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
                onSignIn: () async {
                  setState(() => _signingIn = true);
                  await AuthService.instance.signInWithGoogle();
                  if (mounted) setState(() => _signingIn = false);
                },
                onSignOut: () async {
                  await AuthService.instance.signOut();
                  if (mounted) setState(() {});
                },
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
                  icon: CupertinoIcons.chat_bubble_2_fill,
                  iconColor: AppTheme.spotifyGreen,
                  title: t('Idioma de tradução', 'Translation language'),
                  value: TranslationLanguage.instance.displayName,
                  onTap: _chooseTranslationLanguage,
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

/// Logo do Google desenhado com CustomPainter (sem depender de assets externos).
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final cy = s / 2;
    final r = s * 0.46;

    // Blue arc (top)
    _drawArc(canvas, cx, cy, r, -0.52, 1.62, const Color(0xFF4285F4), s);
    // Red arc (left)
    _drawArc(canvas, cx, cy, r, -2.17, 1.04, const Color(0xFFEA4335), s);
    // Yellow arc (bottom)
    _drawArc(canvas, cx, cy, r, 0.97, 1.23, const Color(0xFFFBBC05), s);
    // Green arc (right)
    _drawArc(canvas, cx, cy, r, -0.52, 1.52, const Color(0xFF34A853), s);

    // White center cutout
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.62,
      Paint()..color = Colors.white,
    );

    // Blue right bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx, cy - r * 0.22, r + s * 0.04, r * 0.44),
        Radius.circular(r * 0.1),
      ),
      barPaint,
    );

    // White center again
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.58,
      Paint()..color = Colors.white,
    );
  }

  void _drawArc(Canvas canvas, double cx, double cy, double r, double start,
      double sweep, Color color, double s) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.19
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      start,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
