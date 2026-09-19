import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme.dart';

/// Modal e componente de informações "Sobre o App" do DropLyric
/// com informações do desenvolvedor e links sociais com ação de copiar ao tocar.
class AboutAppModal extends StatefulWidget {
  const AboutAppModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AboutAppModal(),
    );
  }

  @override
  State<AboutAppModal> createState() => _AboutAppModalState();
}

class _AboutAppModalState extends State<AboutAppModal> {
  String? _copiedKey;
  Timer? _copiedTimer;

  static const String _githubUrl = 'https://github.com/tchezery';
  static const String _linkedinUrl = 'https://linkedin.com/in/tchezery';
  static const String _instagramUrl = 'https://instagram.com/tchesery';
  static const String _emailAddress = 'tchezeryribeiro@gmail.com';

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyToClipboard(String key, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();

    if (!mounted) return;

    _copiedTimer?.cancel();
    setState(() {
      _copiedKey = key;
    });

    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copiedKey = null;
        });
      }
    });
  }

  String _t(String pt, String en) =>
      Localizations.localeOf(context).languageCode == 'pt' ? pt : en;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // App Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/logo.jpg',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.spotifyGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    CupertinoIcons.music_note_2,
                    size: 36,
                    color: AppTheme.spotifyGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // App Title & Version
            const Text(
              'DropLyric',
              style: TextStyle(
                fontFamily: AppTheme.fontSF,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'v1.0.0',
              style: TextStyle(
                fontFamily: AppTheme.fontSF,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _t(
                  'Aprenda idiomas ouvindo suas músicas favoritas, sincronizando letras e salvando vocabulário.',
                  'Learn languages by listening to your favorite songs, syncing lyrics, and building vocabulary.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontSF,
                  fontSize: 14,
                  height: 1.35,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Developer Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000),
                  width: 0.8,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _t('Criador', 'Creator'),
                    style: TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tchézery Ribeiro',
                    style: TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Social Icons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Email
                      _SocialIconButton(
                        id: 'email',
                        isCopied: _copiedKey == 'email',
                        tooltip: 'tchezeryribeiro@gmail.com',
                        svgPath: _SocialSvgPaths.email,
                        iconColor: const Color(0xFFEA4335),
                        onTap: () => _copyToClipboard(
                          'email',
                          _emailAddress,
                          _t('Email', 'Email'),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // LinkedIn
                      _SocialIconButton(
                        id: 'linkedin',
                        isCopied: _copiedKey == 'linkedin',
                        tooltip: 'LinkedIn: tchezery',
                        svgPath: _SocialSvgPaths.linkedin,
                        iconColor: const Color(0xFF0A66C2),
                        onTap: () => _copyToClipboard(
                          'linkedin',
                          _linkedinUrl,
                          'LinkedIn',
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Instagram
                      _SocialIconButton(
                        id: 'instagram',
                        isCopied: _copiedKey == 'instagram',
                        tooltip: 'Instagram: @tchesery',
                        svgPath: _SocialSvgPaths.instagram,
                        iconColor: const Color(0xFFE4405F),
                        onTap: () => _copyToClipboard(
                          'instagram',
                          _instagramUrl,
                          'Instagram',
                        ),
                      ),
                      const SizedBox(width: 14),

                      // GitHub
                      _SocialIconButton(
                        id: 'github',
                        isCopied: _copiedKey == 'github',
                        tooltip: 'GitHub: tchezery',
                        svgPath: _SocialSvgPaths.github,
                        iconColor: isDark ? Colors.white : const Color(0xFF24292F),
                        onTap: () => _copyToClipboard(
                          'github',
                          _githubUrl,
                          'GitHub',
                        ),
                      ),
                    ],
                  ),

                  // Copied feedback banner
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: _copiedKey != null
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.checkmark_alt_circle_fill,
                            size: 15,
                            color: AppTheme.spotifyGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _copiedKey == 'email'
                                ? _t('Email copiado!', 'Email copied!')
                                : _t('Link copiado!', 'Link copied!'),
                            style: const TextStyle(
                              fontFamily: AppTheme.fontSF,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.spotifyGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    secondChild: const SizedBox(height: 0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Licenses option
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.pop(context);
                showLicensePage(
                  context: context,
                  applicationName: 'DropLyric',
                  applicationVersion: '1.0.0',
                  applicationIcon: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/logo.jpg',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        CupertinoIcons.music_note_2,
                        size: 40,
                        color: AppTheme.spotifyGreen,
                      ),
                    ),
                  ),
                );
              },
              child: Text(
                _t('Licenças de Código Aberto', 'Open Source Licenses'),
                style: TextStyle(
                  fontFamily: AppTheme.fontSF,
                  fontSize: 13,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final String id;
  final bool isCopied;
  final String tooltip;
  final String svgPath;
  final Color iconColor;
  final VoidCallback onTap;

  const _SocialIconButton({
    required this.id,
    required this.isCopied,
    required this.tooltip,
    required this.svgPath,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(46, 46),
        onPressed: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isCopied
                ? AppTheme.spotifyGreen.withValues(alpha: 0.2)
                : isDark
                    ? const Color(0xFF2C2C2E)
                    : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCopied
                  ? AppTheme.spotifyGreen
                  : (isDark
                      ? const Color(0x26FFFFFF)
                      : const Color(0x14000000)),
              width: isCopied ? 1.5 : 1,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Center(
            child: isCopied
                ? const Icon(
                    CupertinoIcons.checkmark,
                    size: 20,
                    color: AppTheme.spotifyGreen,
                  )
                : SvgPicture.string(
                    svgPath,
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(
                      iconColor,
                      BlendMode.srcIn,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SocialSvgPaths {
  static const String email = '''
<svg viewBox="0 0 24 24">
  <path d="M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z"/>
</svg>
''';

  static const String linkedin = '''
<svg viewBox="0 0 24 24">
  <path d="M19 3a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h14m-.5 15.5v-5.3a3.26 3.26 0 0 0-3.26-3.26c-.85 0-1.84.52-2.28 1.3v-1.11h-2.79v8.37h2.79v-4.93c0-.77.62-1.4 1.39-1.4a1.4 1.4 0 0 1 1.4 1.4v4.93h2.75M6.88 8.56a1.68 1.68 0 0 0 1.68-1.68c0-.93-.75-1.69-1.68-1.69a1.69 1.69 0 0 0-1.69 1.69c0 .93.76 1.68 1.69 1.68m1.39 9.94v-8.37H5.5v8.37h2.77z"/>
</svg>
''';

  static const String instagram = '''
<svg viewBox="0 0 24 24">
  <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/>
</svg>
''';

  static const String github = '''
<svg viewBox="0 0 24 24">
  <path fill-rule="evenodd" clip-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"/>
</svg>
''';
}
