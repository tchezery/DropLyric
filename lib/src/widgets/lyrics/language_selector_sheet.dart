import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(
                Icons.language_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Idiomas de estudo',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Configure seu idioma nativo e o idioma da música para personalizar o aprendizado.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),

          // Idioma nativo
          _SectionLabel(label: 'Meu idioma nativo'),
          const SizedBox(height: 8),
          _LanguageGrid(
            selectedCode: _selectedNative,
            onSelect: (code) => setState(() => _selectedNative = code),
          ),
          const SizedBox(height: 20),

          // Idioma da música
          _SectionLabel(label: 'Idioma da música / que quero aprender'),
          const SizedBox(height: 8),
          _LanguageGrid(
            selectedCode: _selectedTarget,
            onSelect: (code) => setState(() => _selectedTarget = code),
          ),
          const SizedBox(height: 28),

          // Botão confirmar
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _selectedNative != _selectedTarget
                  ? () {
                      widget.onConfirm(_selectedNative, _selectedTarget);
                      Navigator.of(context).pop();
                    }
                  : null,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Confirmar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          if (_selectedNative == _selectedTarget) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Os idiomas nativo e de estudo devem ser diferentes.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
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
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.primary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _LanguageGrid extends StatelessWidget {
  final String selectedCode;
  final ValueChanged<String> onSelect;

  const _LanguageGrid({
    required this.selectedCode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: supportedLanguages.map((lang) {
        final isSelected = lang.code == selectedCode;
        return GestureDetector(
          onTap: () => onSelect(lang.code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : theme.colorScheme.outline.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    lang.code.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  lang.name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
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
