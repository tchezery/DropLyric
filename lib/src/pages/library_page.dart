import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../core/models/known_word_model.dart';
import '../core/repositories/known_words_repository.dart';
import '../core/services/language_service.dart';
import '../core/services/dictionary_service.dart';

/// Personal dictionary: local filtering, with definitions fetched on demand.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _repository = KnownWordsRepository();
  final _languages = LanguageService();
  final _search = TextEditingController();
  List<KnownWordModel> _words = [];
  bool _loading = true;
  bool _alphabetical = true;
  String _language = '';
  String _nativeLanguage = 'pt';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final words = await _repository.getKnownWordsList();
      final native = await _languages.getNativeLanguage();
      if (!mounted) return;
      setState(() {
        _words = words;
        _nativeLanguage = native;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível carregar suas palavras.';
        });
      }
    }
  }

  Future<void> _remove(KnownWordModel word) async {
    try {
      await _repository.removeWord(word.normalizedWord, word.language);
      if (!mounted) return;
      setState(() {
        _words.removeWhere(
          (w) =>
              w.normalizedWord == word.normalizedWord &&
              w.language == word.language,
        );
        if (!_words.any((w) => w.language == _language)) _language = '';
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível remover a palavra.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languages = _words.map((w) => w.language).toSet().toList()..sort();
    final query = _search.text.trim().toLowerCase();
    final visible = _words
        .where(
          (w) =>
              (_language.isEmpty || w.language == _language) &&
              (w.word.toLowerCase().contains(query) ||
                  (w.trackName ?? '').toLowerCase().contains(query)),
        )
        .toList();
    visible.sort(
      (a, b) => _alphabetical
          ? a.normalizedWord.compareTo(b.normalizedWord)
          : b.createdAt.compareTo(a.createdAt),
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Dictionary',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    tooltip: 'Atualizar palavras',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '${_words.length} palavras conhecidas · ${languages.length} idiomas',
                style: const TextStyle(color: AppTheme.muted, fontSize: 14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar palavra ou música',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.muted),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _language,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Todos os idiomas'),
                          ),
                          for (final code in languages)
                            DropdownMenuItem(
                              value: code,
                              child: Text(
                                _languages.findByCode(code)?.name ??
                                    code.toUpperCase(),
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _language = value ?? ''),
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _alphabetical = !_alphabetical),
                    icon: const Icon(Icons.sort, size: 18),
                    label: Text(_alphabetical ? 'A–Z' : 'Recentes'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: TextButton(
                        onPressed: _load,
                        child: Text('$_error Tentar novamente'),
                      ),
                    )
                  : visible.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.menu_book_outlined,
                              size: 46,
                              color: AppTheme.yellow,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _words.isEmpty
                                  ? 'Seu dicionário começa com uma palavra'
                                  : 'Nenhuma palavra encontrada',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _words.isEmpty
                                  ? 'Toque em uma palavra na letra e marque como conhecida para guardar aqui.'
                                  : 'Tente outra busca ou outro idioma.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.muted,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _DictionaryEntry(
                        key: ValueKey(
                          '${visible[i].language}:${visible[i].normalizedWord}',
                        ),
                        word: visible[i],
                        nativeLanguage: _nativeLanguage,
                        languageName:
                            _languages.findByCode(visible[i].language)?.name ??
                            visible[i].language,
                        onRemove: () => _remove(visible[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DictionaryEntry extends StatefulWidget {
  final KnownWordModel word;
  final String languageName;
  final String nativeLanguage;
  final VoidCallback onRemove;
  const _DictionaryEntry({
    super.key,
    required this.word,
    required this.languageName,
    required this.nativeLanguage,
    required this.onRemove,
  });
  @override
  State<_DictionaryEntry> createState() => _DictionaryEntryState();
}

class _DictionaryEntryState extends State<_DictionaryEntry> {
  Future<WordDefinition?>? _definition;
  void _lookup() {
    setState(
      () => _definition = DictionaryService().lookupWord(
        widget.word.normalizedWord,
        sourceLang: widget.word.language,
        targetLang: widget.nativeLanguage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.word;
    final date =
        '${word.createdAt.day.toString().padLeft(2, '0')}/${word.createdAt.month.toString().padLeft(2, '0')}/${word.createdAt.year}';
    return Material(
      color: AppTheme.sheet,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        onExpansionChanged: (expanded) {
          if (expanded && _definition == null) _lookup();
        },
        title: Text(
          word.word,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.languageName} · Conhecida',
                style: const TextStyle(color: AppTheme.yellow, fontSize: 12),
              ),
              if (word.trackName?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    word.trackName!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        children: [
          const Divider(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Salva em $date',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
          if (_definition != null)
            FutureBuilder<WordDefinition?>(
              future: _definition,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  );
                }
                final data = snapshot.data;
                if (snapshot.hasError ||
                    data == null ||
                    (data.meanings.isEmpty && data.translation == null)) {
                  return TextButton.icon(
                    onPressed: _lookup,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text(
                      'Definição indisponível. Tentar novamente',
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (data.phonetic?.isNotEmpty == true)
                      Text(
                        data.phonetic!,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 15,
                        ),
                      ),
                    if (data.translation?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          data.translation!,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    for (final meaning in data.meanings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (meaning.partOfSpeech.isNotEmpty)
                              Text(
                                meaning.partOfSpeech,
                                style: const TextStyle(
                                  color: AppTheme.yellow,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              meaning.definition,
                              style: const TextStyle(fontSize: 15, height: 1.5),
                            ),
                            if (meaning.example?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '“${meaning.example}”',
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    height: 1.5,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.bookmark_remove_outlined, size: 17),
              label: const Text('Remover das conhecidas'),
            ),
          ),
        ],
      ),
    );
  }
}
