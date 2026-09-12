import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../core/models/known_word_model.dart';
import '../core/repositories/known_words_repository.dart';
import '../core/services/dictionary_service.dart';
import '../core/services/language_service.dart';

/// Dicionário starter pré-carregado por idioma para enriquecer a busca e indicar total de palavras
const Map<String, List<String>> starterDictionaries = {
  'en': [
    'about',
    'after',
    'again',
    'all',
    'always',
    'amazing',
    'beautiful',
    'before',
    'blinding',
    'boy',
    'cause',
    'dance',
    'dark',
    'day',
    'dream',
    'eyes',
    'feel',
    'find',
    'fire',
    'forever',
    'friend',
    'girl',
    'give',
    'heart',
    'heartbreak',
    'hold',
    'hope',
    'keep',
    'know',
    'life',
    'light',
    'like',
    'listen',
    'look',
    'love',
    'make',
    'mind',
    'music',
    'never',
    'night',
    'people',
    'remember',
    'shape',
    'shining',
    'smile',
    'someone',
    'song',
    'soul',
    'stay',
    'story',
    'sweet',
    'time',
    'together',
    'touch',
    'voice',
    'way',
    'world',
  ],
  'es': [
    'agua',
    'alma',
    'amor',
    'bailar',
    'beso',
    'cantar',
    'cielo',
    'corazón',
    'despacito',
    'día',
    'dulce',
    'estrella',
    'flor',
    'fuego',
    'hola',
    'luz',
    'mar',
    'mirada',
    'música',
    'noche',
    'olvidar',
    'palabra',
    'paso',
    'paz',
    'sabor',
    'siempre',
    'sol',
    'sombra',
    'soñar',
    'sonrisa',
    'suave',
    'tiempo',
    'tierra',
    'vida',
    'viento',
    'voz',
  ],
  'pt': [
    'abraço',
    'alegria',
    'amor',
    'beleza',
    'bossa',
    'caminho',
    'canto',
    'carinho',
    'coração',
    'destino',
    'dia',
    'esperança',
    'estrela',
    'flor',
    'garota',
    'harmonia',
    'ipanema',
    'linda',
    'luz',
    'mar',
    'melodia',
    'música',
    'noite',
    'olhar',
    'onda',
    'paixão',
    'passar',
    'poesia',
    'rio',
    'saudade',
    'silêncio',
    'sol',
    'sombra',
    'sorriso',
    'sonho',
    'vento',
    'vida',
    'voz',
  ],
  'fr': [
    'amour',
    'beau',
    'bonjour',
    'chanson',
    'ciel',
    'coeur',
    'danse',
    'dernière',
    'douceur',
    'ensemble',
    'étoile',
    'fleur',
    'histoire',
    'espoir',
    'jour',
    'lumière',
    'mer',
    'monde',
    'musique',
    'nuit',
    'ombre',
    'papaoutai',
    'pensée',
    'rêve',
    'silence',
    'soleil',
    'souvenir',
    'temps',
    'toujours',
    'vent',
    'vie',
    'voix',
  ],
  'it': [
    'amore',
    'anima',
    'bello',
    'bacio',
    'canto',
    'cielo',
    'cuore',
    'dolce',
    'estate',
    'fiori',
    'giorno',
    'luce',
    'mare',
    'mondo',
    'musica',
    'notte',
    'parola',
    'pensiero',
    'poesia',
    'sempre',
    'sole',
    'sogno',
    'tempo',
    'vita',
    'voce',
  ],
  'de': [
    'abend',
    'augen',
    'blume',
    'dank',
    'freud',
    'freund',
    'herz',
    'himmel',
    'hoffnung',
    'licht',
    'liebe',
    'leben',
    'musik',
    'nacht',
    'sonne',
    'stille',
    'traum',
    'welt',
    'zeit',
  ],
  'ja': [
    'ai',
    'hikari',
    'kokoro',
    'kumo',
    'hana',
    'hosi',
    'kaiwa',
    'kaze',
    'machi',
    'mirai',
    'ongaku',
    'sora',
    'tsuki',
    'yume',
  ],
  'ko': [
    'sarang',
    'maeum',
    'gureum',
    'kkot',
    'byeol',
    'baram',
    'eumak',
    'haneul',
    'dal',
    'kkum',
    'bitch',
  ],
};

class DictionaryItem {
  final String word;
  final String normalizedWord;
  final String language;
  final String? trackName;
  final DateTime? createdAt;
  final bool isKnown;

  const DictionaryItem({
    required this.word,
    required this.normalizedWord,
    required this.language,
    this.trackName,
    this.createdAt,
    required this.isKnown,
  });
}

/// Personal dictionary with language list, A-Z letter index, word counts, total language counts, and known badges.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _repository = KnownWordsRepository();
  final _languageService = LanguageService();
  final _searchController = TextEditingController();

  List<KnownWordModel> _knownWords = [];
  bool _loading = true;
  String? _selectedLanguageCode;
  String _selectedLetter = 'ALL';
  String _nativeLanguage = 'pt';
  bool _knownOnly = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final words = await _repository.getKnownWordsList();
      for (final word in words.where(
        (word) =>
            word.language == 'en' && !isLikelyEnglishWord(word.normalizedWord),
      )) {
        await _repository.moveWord(word.normalizedWord, 'en', 'es');
      }
      final migratedWords = await _repository.getKnownWordsList();
      final native = await _languageService.getNativeLanguage();
      if (!mounted) return;
      setState(() {
        _knownWords = migratedWords;
        _nativeLanguage = native;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load your words.';
        });
      }
    }
  }

  Future<void> _toggleKnown(
    String rawWord,
    String normWord,
    String langCode, {
    String? trackName,
  }) async {
    try {
      final isNowKnown = await _repository.toggleWord(
        rawWord,
        langCode,
        trackName: trackName,
      );
      if (!mounted) return;
      setState(() {
        if (!isNowKnown) {
          _knownWords.removeWhere(
            (w) => w.normalizedWord == normWord && w.language == langCode,
          );
        } else {
          final existing = _knownWords.any(
            (w) => w.normalizedWord == normWord && w.language == langCode,
          );
          if (!existing) {
            _knownWords.insert(
              0,
              KnownWordModel(
                word: rawWord,
                normalizedWord: normWord,
                language: langCode,
                trackName: trackName,
                createdAt: DateTime.now(),
              ),
            );
          }
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update word status.')),
        );
      }
    }
  }

  /// Retorna a lista unificada de palavras (Dicionário Starter + Palavras salvas pelo usuário) para um idioma.
  List<DictionaryItem> _getLanguageDictionary(String langCode) {
    final knownMap = <String, KnownWordModel>{};
    for (final kw in _knownWords.where((w) => w.language == langCode)) {
      if (langCode == 'en' && !isLikelyEnglishWord(kw.normalizedWord)) {
        continue;
      }
      knownMap[kw.normalizedWord] = kw;
    }

    final itemsMap = <String, DictionaryItem>{};

    // The dictionary contains only words the user has saved.
    for (final kw in knownMap.values) {
      itemsMap[kw.normalizedWord] = DictionaryItem(
        word: kw.word,
        normalizedWord: kw.normalizedWord,
        language: langCode,
        trackName: kw.trackName,
        createdAt: kw.createdAt,
        isKnown: true,
      );
    }

    final result = itemsMap.values.toList()
      ..sort((a, b) => a.normalizedWord.compareTo(b.normalizedWord));

    return result;
  }

  Map<String, int> _computeLetterCounts(List<DictionaryItem> items) {
    final counts = <String, int>{'ALL': items.length};
    for (var i = 65; i <= 90; i++) {
      counts[String.fromCharCode(i)] = 0;
    }
    counts['#'] = 0;

    for (final item in items) {
      final first = item.normalizedWord.trim().toUpperCase();
      if (first.isEmpty) continue;
      final char = first[0];
      if (RegExp(r'[A-Z]').hasMatch(char)) {
        counts[char] = (counts[char] ?? 0) + 1;
      } else {
        counts['#'] = (counts['#'] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<DictionaryItem> _filterItems(
    List<DictionaryItem> items,
    String letter,
    String query,
  ) {
    return items.where((item) {
      final norm = item.normalizedWord.trim().toLowerCase();
      final display = item.word.trim().toLowerCase();
      final track = (item.trackName ?? '').toLowerCase();

      // Busca por texto
      if (query.isNotEmpty &&
          !display.contains(query) &&
          !track.contains(query)) {
        return false;
      }

      // Filtro por letra A-Z
      if (letter == 'ALL') return true;
      if (letter == '#') {
        final first = norm.isNotEmpty ? norm[0].toUpperCase() : '';
        return !RegExp(r'[A-Z]').hasMatch(first);
      }

      final firstChar = norm.isNotEmpty ? norm[0].toUpperCase() : '';
      return firstChar == letter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedLanguageCode != null) {
      return _buildLanguageDictionaryView(_selectedLanguageCode!);
    }

    return _buildLanguageListView();
  }

  /// Visão 1: Lista de Idiomas com total de palavras do idioma e palavras conhecidas
  Widget _buildLanguageListView() {
    final languagesWithWords = supportedLanguages
        .where((lang) => _getLanguageDictionary(lang.code).isNotEmpty)
        .toList();
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
                    tooltip: 'Refresh words',
                    icon: const Icon(CupertinoIcons.refresh),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '${_knownWords.length} total words known · Select a language to explore',
                style: const TextStyle(color: AppTheme.muted, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: TextButton(
                        onPressed: _load,
                        child: Text('$_error Try again'),
                      ),
                    )
                  : languagesWithWords.isEmpty
                  ? const Center(
                      child: Text(
                        'No saved words yet. Open a lyric and mark words as known.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      itemCount: languagesWithWords.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final lang = languagesWithWords[index];
                        final items = _getLanguageDictionary(lang.code);
                        final totalWords = items.length;
                        final knownWordsCount = items
                            .where((i) => i.isKnown)
                            .length;
                        final percent = totalWords > 0
                            ? ((knownWordsCount / totalWords) * 100).round()
                            : 0;

                        return Material(
                          color: AppTheme.sheet,
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppTheme.paper,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                lang.flag,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    lang.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                ),
                                
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '$knownWordsCount known',
                                style: TextStyle(
                                  color: knownWordsCount > 0
                                      ? AppTheme.yellow
                                      : AppTheme.muted,
                                  fontSize: 13,
                                  fontWeight: knownWordsCount > 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            trailing: const Icon(
                              CupertinoIcons.chevron_right,
                              color: AppTheme.muted,
                              size: 18,
                            ),
                            onTap: () {
                              setState(() {
                                _selectedLanguageCode = lang.code;
                                _selectedLetter = 'ALL';
                                _knownOnly = false;
                                _searchController.clear();
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Visão 2: Dicionário do Idioma selecionado com A-Z index, contagem total de palavras e badges
  Widget _buildLanguageDictionaryView(String langCode) {
    final lang = _languageService.findByCode(langCode);
    final langName = lang?.name ?? langCode.toUpperCase();
    final langFlag = lang?.flag ?? '';

    final dictionaryItems = _getLanguageDictionary(langCode);
    final totalWords = dictionaryItems.length;
    final knownCount = dictionaryItems.where((i) => i.isKnown).length;
    final percent = totalWords > 0
        ? ((knownCount / totalWords) * 100).round()
        : 0;

    final visibleSource = _knownOnly
        ? dictionaryItems.where((item) => item.isKnown).toList()
        : dictionaryItems;
    final letterCounts = _computeLetterCounts(visibleSource);
    final query = _searchController.text.trim().toLowerCase();
    final filteredItems = _filterItems(visibleSource, _selectedLetter, query);

    final alphabetList = [
      'ALL',
      for (var i = 65; i <= 90; i++) String.fromCharCode(i),
      '#',
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar com botão voltar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedLanguageCode = null;
                      });
                    },
                    icon: const Icon(CupertinoIcons.chevron_left, size: 28),
                    color: AppTheme.ink,
                    tooltip: 'Back to Languages',
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$langFlag $langName Dictionary',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$knownCount known · $totalWords in app dictionary ($percent% mastered)',
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    tooltip: 'Refresh words',
                    icon: const Icon(CupertinoIcons.refresh),
                  ),
                ],
              ),
            ),

            // Campo de busca
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search word in $langName...',
                  prefixIcon: const Icon(
                    CupertinoIcons.search,
                    color: AppTheme.muted,
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(CupertinoIcons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(value: false, label: Text('All')),
                  ButtonSegment<bool>(value: true, label: Text('Known')),
                ],
                selected: {_knownOnly},
                onSelectionChanged: (selection) {
                  setState(() => _knownOnly = selection.first);
                },
              ),
            ),
            const SizedBox(height: 10),

            // Barra Seletora A-Z com contagem de palavras por letra
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: alphabetList.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final letter = alphabetList[index];
                  final count = letterCounts[letter] ?? 0;
                  final isSelected = _selectedLetter == letter;

                  return ChoiceChip(
                    showCheckmark: false,
                    label: Text(
                      letter == 'ALL' ? 'ALL ($count)' : '$letter ($count)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.ink
                            : (count > 0 ? AppTheme.ink : AppTheme.muted),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.marker,
                    backgroundColor: count > 0
                        ? AppTheme.sheet
                        : AppTheme.paper,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.yellow
                            : AppTheme.separator,
                        width: isSelected ? 1.5 : 0.5,
                      ),
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedLetter = letter;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Lista de palavras filtradas
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.book,
                              size: 46,
                              color: AppTheme.yellow,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              dictionaryItems.isEmpty
                                  ? 'No words in $langName dictionary'
                                  : 'No words starting with "$_selectedLetter"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dictionaryItems.isEmpty
                                  ? 'Tap words in lyrics while playing songs to save them!'
                                  : 'Select another letter from the A–Z bar above.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                      itemCount: filteredItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final item = filteredItems[i];
                        return _DictionaryEntry(
                          key: ValueKey(
                            '${item.language}:${item.normalizedWord}',
                          ),
                          item: item,
                          nativeLanguage: _nativeLanguage,
                          languageName: langName,
                          onToggleKnown: () => _toggleKnown(
                            item.word,
                            item.normalizedWord,
                            item.language,
                            trackName: item.trackName,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DictionaryEntry extends StatefulWidget {
  final DictionaryItem item;
  final String languageName;
  final String nativeLanguage;
  final VoidCallback onToggleKnown;

  const _DictionaryEntry({
    super.key,
    required this.item,
    required this.languageName,
    required this.nativeLanguage,
    required this.onToggleKnown,
  });

  @override
  State<_DictionaryEntry> createState() => _DictionaryEntryState();
}

class _DictionaryEntryState extends State<_DictionaryEntry> {
  Future<WordDefinition?>? _definition;

  void _lookup() {
    setState(
      () => _definition = DictionaryService().lookupWord(
        widget.item.normalizedWord,
        sourceLang: widget.item.language,
        targetLang: widget.nativeLanguage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final dateStr = item.createdAt != null
        ? 'Saved on ${item.createdAt!.day.toString().padLeft(2, '0')}/${item.createdAt!.month.toString().padLeft(2, '0')}/${item.createdAt!.year} · '
        : '';

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
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.word,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            // Marca visível da palavra conhecida / aprendendo (Known badge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: item.isKnown ? AppTheme.marker : AppTheme.paper,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.isKnown
                        ? CupertinoIcons.checkmark_seal_fill
                        : CupertinoIcons.circle,
                    size: 13,
                    color: item.isKnown ? AppTheme.yellow : AppTheme.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.isKnown ? 'Known' : 'Learning',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: item.isKnown ? AppTheme.ink : AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.trackName?.isNotEmpty == true)
                Text(
                  'From: ${item.trackName!}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
            ],
          ),
        ),
        children: [
          const Divider(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$dateStr${widget.languageName}',
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
                    icon: const Icon(CupertinoIcons.refresh, size: 16),
                    label: const Text('Definition unavailable. Try again'),
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
              onPressed: widget.onToggleKnown,
              icon: Icon(
                item.isKnown
                    ? CupertinoIcons.bookmark_solid
                    : CupertinoIcons.bookmark,
                size: 17,
              ),
              label: Text(item.isKnown ? 'Remove from known' : 'Mark as known'),
            ),
          ),
        ],
      ),
    );
  }
}
