import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../core/services/language_service.dart';
import 'language_flag.dart';

/// Modal Apple-style para selecionar 1 ou mais idiomas dominados/nativos pelo usuário.
class FluentLanguagesSheet extends StatefulWidget {
  final Set<String> initialLanguages;
  final ValueChanged<Set<String>> onConfirm;

  const FluentLanguagesSheet({
    super.key,
    required this.initialLanguages,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required Set<String> initialLanguages,
    required ValueChanged<Set<String>> onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => FluentLanguagesSheet(
        initialLanguages: initialLanguages,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<FluentLanguagesSheet> createState() => _FluentLanguagesSheetState();
}

class _FluentLanguagesSheetState extends State<FluentLanguagesSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialLanguages);
  }

  void _toggle(String code) {
    setState(() {
      if (_selected.contains(code)) {
        _selected.remove(code);
      } else {
        _selected.add(code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPt = Localizations.localeOf(context).languageCode == 'pt';
    final bgColor = isDark ? const Color(0xFF1C1C1E) : AppTheme.white;
    final cardColor =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final primaryTextColor = isDark ? AppTheme.labelDark : AppTheme.labelLight;
    final secondaryTextColor =
        isDark ? AppTheme.secondaryLabelDark : AppTheme.secondaryLabelLight;

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
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0x40FFFFFF) : const Color(0x30000000),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPt ? 'Idiomas que já domino' : 'Mastered languages',
                style: TextStyle(
                  fontFamily: AppTheme.fontSF,
                  color: primaryTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  widget.onConfirm(_selected);
                  Navigator.of(context).pop();
                },
                child: Text(
                  isPt ? 'Concluído' : 'Done',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSF,
                    color: AppTheme.spotifyGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Subtitle explanation
          Text(
            isPt
                ? 'Músicas nestes idiomas não contabilizam palavras no seu vocabulário nem salvam no banco de dados.'
                : "Songs in these languages won't track word-by-word vocabulary or store words in the database.",
            style: TextStyle(
              fontFamily: AppTheme.fontSF,
              color: secondaryTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 18),

          // Lista de idiomas suportados
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? const Color(0x26FFFFFF)
                      : const Color(0x14000000),
                  width: 0.8,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: supportedLanguages.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  thickness: 0.6,
                  color: isDark
                      ? const Color(0x26FFFFFF)
                      : const Color(0x14000000),
                ),
                itemBuilder: (context, index) {
                  final lang = supportedLanguages[index];
                  final isSelected = _selected.contains(lang.code);

                  return InkWell(
                    onTap: () => _toggle(lang.code),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          LanguageFlag(countryCode: lang.flagCode, width: 26),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              lang.name,
                              style: TextStyle(
                                fontFamily: AppTheme.fontSF,
                                color: primaryTextColor,
                                fontSize: 15.5,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              CupertinoIcons.checkmark_circle_fill,
                              color: AppTheme.spotifyGreen,
                              size: 22,
                            )
                          else
                            Icon(
                              CupertinoIcons.circle,
                              color: isDark
                                  ? const Color(0x40FFFFFF)
                                  : const Color(0x30000000),
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
