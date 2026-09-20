import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../core/services/app_strings.dart';
import '../core/services/language_service.dart';
import '../core/services/spotify_session.dart';
import '../widgets/spotify_connect_button.dart';
import '../widgets/language_flag.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.languageSelected,
    required this.onFinished,
  });

  final bool languageSelected;
  final VoidCallback onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  String? _selectedLanguage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.languageSelected) {
      _selectedLanguage = AppLanguage.instance.code;
    }
  }

  Future<void> _saveLanguage(String code) async {
    setState(() {
      _selectedLanguage = code;
      _saving = true;
    });
    await AppLanguage.instance.set(code);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasLanguage = _selectedLanguage != null;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.08,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/logo.jpg',
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: colors.primary.withValues(alpha: 0.15),
                          child: Icon(
                            CupertinoIcons.music_note_2,
                            color: colors.primary,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'DropLyric',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                    Text(
                      hasLanguage
                          ? tr(context, 'Choose how you want to listen:')
                          : tr(context, 'Choose your preferred language.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontSF,
                        color: colors.onSurfaceVariant,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (!hasLanguage) ...[
                      _LanguageButton(
                        flagCode: 'us',
                        label: 'English',
                        selected: _selectedLanguage == 'en',
                        onPressed: _saving ? null : () => _saveLanguage('en'),
                      ),
                      const SizedBox(height: 12),
                      _LanguageButton(
                        flagCode: 'br',
                        label: 'Português',
                        selected: _selectedLanguage == 'pt',
                        onPressed: _saving ? null : () => _saveLanguage('pt'),
                      ),
                    ] else ...[
                      // 1. Botão YouTube Music (Livre de cotas / reprodução direta)
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF0000),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: const Icon(
                            CupertinoIcons.play_rectangle_fill,
                            color: Colors.white,
                            size: 22,
                          ),
                          label: Text(
                            AppLanguage.instance.isPortuguese
                                ? 'Continuar com YouTube'
                                : 'Continue with YouTube',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontSF,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () async {
                            await LanguageService().setOnboardingComplete(true);
                            widget.onFinished();
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              AppLanguage.instance.isPortuguese ? 'ou' : 'or',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 2. Conectar Spotify
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? const Color(0x26FFFFFF)
                                : const Color(0x14000000),
                            width: 0.8,
                          ),
                        ),
                        child: const SpotifyConnectButton(),
                      ),
                      const SizedBox(height: 16),
                      ListenableBuilder(
                        listenable: SpotifySession.instance,
                        builder: (context, _) {
                          if (!SpotifySession.instance.connected) {
                            return const SizedBox.shrink();
                          }
                          return SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                await LanguageService().setOnboardingComplete(true);
                                widget.onFinished();
                              },
                              icon: const Icon(CupertinoIcons.arrow_right, size: 18),
                              label: Text(tr(context, 'Continue')),
                            ),
                          );
                        },
                      ),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.flagCode,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String flagCode;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: selected ? colors.primary : colors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? Colors.transparent
                    : (isDark ? const Color(0x26FFFFFF) : const Color(0x14000000)),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                LanguageFlag(countryCode: flagCode, width: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppTheme.fontSF,
                      color: selected ? colors.onPrimary : colors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: colors.onPrimary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
