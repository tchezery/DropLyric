import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../core/services/dictionary_service.dart';

/// Modal de ações ao pressionar uma palavra da letra:
/// - Ícone de Livrinho (📖 Dicionário) para ver significado completo, fonética e tradução.
/// - Botão para alternar status no vocabulário (Conhecida / Estudo).
/// - Botão para copiar a palavra.
class WordActionSheet extends StatefulWidget {
  final String rawWord;
  final String normalized;
  final bool isInitiallyKnown;
  final String sourceLanguage;
  final String nativeLanguage;
  final VoidCallback onToggleWord;
  final ValueChanged<bool> onWordToggled;

  const WordActionSheet({
    super.key,
    required this.rawWord,
    required this.normalized,
    required this.isInitiallyKnown,
    required this.sourceLanguage,
    required this.nativeLanguage,
    required this.onToggleWord,
    required this.onWordToggled,
  });

  static Future<void> show(
    BuildContext context, {
    required String rawWord,
    required String normalized,
    required bool isInitiallyKnown,
    required String sourceLanguage,
    required String nativeLanguage,
    required VoidCallback onToggleWord,
    required ValueChanged<bool> onWordToggled,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => WordActionSheet(
        rawWord: rawWord,
        normalized: normalized,
        isInitiallyKnown: isInitiallyKnown,
        sourceLanguage: sourceLanguage,
        nativeLanguage: nativeLanguage,
        onToggleWord: onToggleWord,
        onWordToggled: onWordToggled,
      ),
    );
  }

  @override
  State<WordActionSheet> createState() => _WordActionSheetState();
}

class _WordActionSheetState extends State<WordActionSheet> {
  final DictionaryService _dictionaryService = DictionaryService();

  late bool _isKnown;
  bool _loading = true;
  WordDefinition? _definition;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isKnown = widget.isInitiallyKnown;
    _lookup();
  }

  Future<void> _lookup() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await _dictionaryService.lookupWord(
        widget.normalized,
        sourceLang: widget.sourceLanguage,
        targetLang: widget.nativeLanguage,
      );
      if (mounted) {
        setState(() {
          _definition = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Não foi possível carregar a definição no momento.';
        });
      }
    }
  }

  void _handleToggle() {
    HapticFeedback.mediumImpact();
    widget.onToggleWord();
    setState(() {
      _isKnown = !_isKnown;
    });
    widget.onWordToggled(_isKnown);
  }

  void _copyToClipboard() {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: widget.rawWord));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Palavra "${widget.rawWord}" copiada!'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.78),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFEFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: Color(0xFFE4E0D6), width: 1.2),
          left: BorderSide(color: Color(0xFFE4E0D6), width: 1.2),
          right: BorderSide(color: Color(0xFFE4E0D6), width: 1.2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            // Handle de arrastar
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.separator,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Cabeçalho da palavra
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.rawWord.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                            letterSpacing: 1.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _isKnown
                                    ? AppTheme.spotifyGreen.withValues(
                                        alpha: 0.20,
                                      )
                                    : const Color(0xFFFDE68A)
                                          .withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _isKnown ? 'CONHECIDA' : 'EM APRENDIZADO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _isKnown
                                      ? AppTheme.spotifyGreen
                                      : const Color(0xFFFDE68A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.sourceLanguage.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF74716A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Barra de ações (Livrinho de Dicionário, Vocabulário, Copiar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 1. O Livrinho do Dicionário (Destacado conforme solicitado)
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE68A), // Amarelo marca-texto
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.menu_book_rounded, // Livrinho solicitado!
                            size: 19,
                            color: Color(0xFF141F17),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Dicionário',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF141F17),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. Botão de alternar vocabulário
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: _handleToggle,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EDE5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isKnown
                                ? AppTheme.spotifyGreen.withValues(alpha: 0.5)
                                : AppTheme.separator,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isKnown
                                  ? Icons.bookmark_remove_rounded
                                  : Icons.bookmark_add_rounded,
                              size: 18,
                              color: _isKnown
                                  ? AppTheme.spotifyGreen
                                  : AppTheme.muted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isKnown ? 'Desmarcar' : 'Dominar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _isKnown
                                    ? AppTheme.spotifyGreen
                                    : AppTheme.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 3. Botão Copiar
                  InkWell(
                    onTap: _copyToClipboard,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EDE5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.separator),
                      ),
                      child: const Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE4E0D6), height: 1),

            // Área de conteúdo do Dicionário
            Expanded(child: _buildDictionaryBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildDictionaryBody() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Color(0xFFFDE68A),
                strokeWidth: 2.2,
              ),
              SizedBox(height: 14),
              Text(
                'Buscando significado no dicionário...',
                style: TextStyle(fontSize: 12, color: Color(0xFF74716A)),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: AppTheme.muted,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 13, color: AppTheme.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _lookup,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Tentar novamente'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFDE68A),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final def = _definition;
    if (def == null || (def.meanings.isEmpty && def.translation == null)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 44,
                color: AppTheme.muted,
              ),
              const SizedBox(height: 12),
              Text(
                'Nenhum significado detalhado encontrado\npara "${widget.rawWord}".',
                style: const TextStyle(fontSize: 13, color: AppTheme.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        // Pronúncia fonética se disponível
        if (def.phonetic != null && def.phonetic!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.volume_up_rounded,
                  size: 16,
                  color: Color(0xFF74716A),
                ),
                const SizedBox(width: 6),
                Text(
                  def.phonetic!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF74716A),
                  ),
                ),
              ],
            ),
          ),

        // Card de Tradução em Português
        if (def.translation != null && def.translation!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EDE5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFDE68A).withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.translate_rounded,
                      size: 15,
                      color: Color(0xFFFDE68A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'TRADUÇÃO EM PORTUGUÊS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFDE68A).withValues(alpha: 0.9),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  def.translation!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
              ],
            ),
          ),

        // Lista de Significados e Definições
        if (def.meanings.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'DEFINIÇÕES DO DICIONÁRIO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF74716A),
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...def.meanings.map((meaning) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.separator),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meaning.partOfSpeech.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.separator,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        meaning.partOfSpeech.toLowerCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFDE68A),
                        ),
                      ),
                    ),
                  Text(
                    meaning.definition,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF242320),
                    ),
                  ),
                  if (meaning.example != null &&
                      meaning.example!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '“${meaning.example}”',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF74716A),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
