import '../../core/services/app_strings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../core/services/language_service.dart';

/// Bottom sheet para selecionar idioma nativo e idioma da música/tradução.
class LanguageSelectorSheet extends StatefulWidget {
  final String currentNativeLanguage;
  final String currentTargetLanguage;
  final LanguageService languageService;
  final void Function(String native, String target) onConfirm;

  const LanguageSelectorSheet({
    super.key,
    required this.currentNativeLanguage,
    required this.currentTargetLanguage,
    required this.languageService,
    required this.onConfirm,
  });

  /// Exibe o sheet como um modal.
  static Future<void> show(
    BuildContext context, {
    required String currentNativeLanguage,
    required String currentTargetLanguage,
    required LanguageService languageService,
    required void Function(String native, String target) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LanguageSelectorSheet(
        currentNativeLanguage: currentNativeLanguage,
        currentTargetLanguage: currentTargetLanguage,
        languageService: languageService,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<LanguageSelectorSheet> createState() => _LanguageSelectorSheetState();
}

class _LanguageSelectorSheetState extends State<LanguageSelectorSheet> {
  late String _selectedNative;
  late String _selectedTarget;

  @override
  void initState() {
    super.initState();
    _selectedNative = widget.currentNativeLanguage;
    _selectedTarget = widget.currentTargetLanguage;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : AppTheme.white;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final primaryTextColor = isDark ? AppTheme.labelDark : AppTheme.labelLight;
    final secondaryTextColor = isDark ? AppTheme.secondaryLabelDark : AppTheme.secondaryLabelLight;
    final isPortuguese = Localizations.localeOf(context).languageCode == 'pt';

    return Container(
      constraints: const BoxConstraints(maxWidth: 640),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // iOS Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(
                CupertinoIcons.globe,
                color: AppTheme.appleBlue,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                tr(context, "Study languages"),
                style: TextStyle(
                  fontFamily: '.SF Pro Display',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Native Language Section
          _SectionLabel(
            label: isPortuguese ? 'Meu idioma nativo' : 'My native language',
            textColor: secondaryTextColor,
          ),
          const SizedBox(height: 10),
          _LanguageGrid(
            selectedCode: _selectedNative,
            cardColor: cardColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onSelect: (code) => setState(() => _selectedNative = code),
          ),
          const SizedBox(height: 22),

          // Track / Target Language Section
          _SectionLabel(
            label: isPortuguese ? 'Idioma que quero aprender' : 'Language to learn',
            textColor: secondaryTextColor,
          ),
          const SizedBox(height: 10),
          _LanguageGrid(
            selectedCode: _selectedTarget,
            cardColor: cardColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onSelect: (code) => setState(() => _selectedTarget = code),
          ),
          const SizedBox(height: 26),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _selectedNative != _selectedTarget
                  ? () {
                      widget.onConfirm(_selectedNative, _selectedTarget);
                      Navigator.of(context).pop();
                    }
                  : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedNative != _selectedTarget
                      ? AppTheme.appleBlue
                      : (_selectedNative == _selectedTarget
                          ? AppTheme.appleBlue.withValues(alpha: 0.4)
                          : AppTheme.appleBlue),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.checkmark_alt,
                      color: AppTheme.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr(context, "Confirm"),
                      style: const TextStyle(
                        fontFamily: '.SF Pro Text',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_selectedNative == _selectedTarget) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                tr(context, "The native and study languages must be different."),
                style: const TextStyle(
                  fontFamily: '.SF Pro Text',
                  fontSize: 12,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color textColor;
  const _SectionLabel({required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _LanguageGrid extends StatelessWidget {
  final String selectedCode;
  final Color cardColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final ValueChanged<String> onSelect;

  const _LanguageGrid({
    required this.selectedCode,
    required this.cardColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: supportedLanguages.map((lang) {
        final isSelected = lang.code == selectedCode;
        return GestureDetector(
          onTap: () => onSelect(lang.code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.appleBlue : cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lang.code.toUpperCase(),
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppTheme.white
                        : secondaryTextColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  localizedLanguageName(context, lang.code),
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.white
                        : primaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
