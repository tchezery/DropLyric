import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../core/services/app_strings.dart';
import '../core/services/language_service.dart';
import '../core/services/spotify_session.dart';
import '../widgets/spotify_connect_button.dart';
import '../widgets/spotify_icon.dart';

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

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  hasLanguage
                      ? const SpotifyIcon(size: 64)
                      : const Icon(
                          CupertinoIcons.music_note_2,
                          color: AppTheme.spotifyGreen,
                          size: 64,
                        ),
                  const SizedBox(height: 24),
                  Text(
                    'DropLyric',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasLanguage
                        ? tr(
                            context,
                            'Connect your Spotify account to continue.',
                          )
                        : tr(
                            context,
                            'Choose the language you want to use in the app.',
                          ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (!hasLanguage) ...[
                    _LanguageButton(
                      label: 'English',
                      selected: _selectedLanguage == 'en',
                      onPressed: _saving ? null : () => _saveLanguage('en'),
                    ),
                    const SizedBox(height: 12),
                    _LanguageButton(
                      label: 'Português',
                      selected: _selectedLanguage == 'pt',
                      onPressed: _saving ? null : () => _saveLanguage('pt'),
                    ),
                  ] else ...[
                    SpotifyConnectButton(),
                    const SizedBox(height: 18),
                    ListenableBuilder(
                      listenable: SpotifySession.instance,
                      builder: (context, _) {
                        if (!SpotifySession.instance.connected) {
                          return const SizedBox.shrink();
                        }
                        return FilledButton.icon(
                          onPressed: widget.onFinished,
                          icon: const Icon(CupertinoIcons.arrow_right),
                          label: Text(tr(context, 'Continue')),
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
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: selected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(label),
      ),
    );
  }
}
