import '../core/services/app_strings.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../core/models/known_word_model.dart';
import '../core/repositories/known_words_repository.dart';
import '../core/services/dictionary_service.dart';
import '../core/services/language_service.dart';

Map<String, List<String>> starterDictionaries = {
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

/// Personal dictionary with a single A-Z list of saved words.
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
  String _selectedLetter = 'ALL';
  String _selectedLanguage = 'ALL';
  String _translationLanguage = 'en';
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
      final appLanguage = await _languageService.getAppLanguage();
      if (!mounted) return;
      setState(() {
        _knownWords = migratedWords;
        _translationLanguage = appLanguage;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "Could not load your words.";
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
          SnackBar(content: Text(tr(context, "Could not update word status."))),
        );
      }
    }
  }

  List<DictionaryItem> _getDictionary() {
    final items =
        _knownWords
            .where(
              (word) =>
                  word.language != 'en' ||
                  isLikelyEnglishWord(word.normalizedWord),
            )
            .map(
              (word) => DictionaryItem(
                word: word.word,
                normalizedWord: word.normalizedWord,
                language: word.language,
                trackName: word.trackName,
                createdAt: word.createdAt,
                isKnown: true,
              ),
            )
            .toList()
          ..sort((a, b) => a.normalizedWord.compareTo(b.normalizedWord));

    return items;
  }

  List<DictionaryItem> _filterByLanguage(
    List<DictionaryItem> items,
    String language,
  ) {
    if (language == 'ALL') return items;
    return items.where((item) => item.language == language).toList();
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
    return _buildWordListView(context);
  }

  Widget _buildWordListView(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dictionaryItems = _getDictionary();
    final languageItems = _filterByLanguage(dictionaryItems, _selectedLanguage);
    final totalWords = languageItems.length;
    final letterCounts = _computeLetterCounts(languageItems);
    final query = _searchController.text.trim().toLowerCase();
    final filteredItems = _filterItems(languageItems, _selectedLetter, query);
    final languageCodes =
        dictionaryItems.map((item) => item.language).toSet().toList()..sort();

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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, "Dictionary"),
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          Localizations.localeOf(context).languageCode == 'pt'
                              ? '$totalWords ${totalWords == 1 ? 'palavra salva' : 'palavras salvas'}'
                              : '$totalWords saved ${totalWords == 1 ? 'word' : 'words'}',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    tooltip: tr(context, "Refresh words"),
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
                  hintText: tr(context, "Search words..."),
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    color: colors.onSurfaceVariant,
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: tr(context, "Clear search"),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Text(
                    tr(context, 'Language'),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container (
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),

                    child: DropdownButton<String>(
                    value: [
                      'ALL',
                      ...languageCodes,
                    ].contains(_selectedLanguage)
                        ? _selectedLanguage
                        : 'ALL',
                    isDense: true,
                    isExpanded: false,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(4),
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('All')),
                      ...languageCodes.map(
                        (code) => DropdownMenuItem(
                          value: code,
                          child: Text(localizedLanguageName(context, code)),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedLanguage = value;
                        _selectedLetter = 'ALL';
                      });
                    },
                  ),
                  ),
                ],
              ),
            ),

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
                      letter == 'ALL'
                          ? '${tr(context, 'ALL')} ($count)'
                          : '$letter ($count)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? colors.onSurface
                            : (count > 0
                                  ? colors.onSurface
                                  : colors.onSurfaceVariant),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: colors.primaryContainer,
                    backgroundColor: count > 0
                        ? colors.surface
                        : colors.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? colors.primary
                            : colors.outlineVariant,
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
              child: _loading
                  ? const Center(child: const CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: TextButton(
                        onPressed: _load,
                        child: Text(
                          '${tr(context, _error!)} ${tr(context, 'Try again')}',
                        ),
                      ),
                    )
                  : filteredItems.isEmpty
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
                                  ? tr(context, "No saved words yet")
                                  : Localizations.localeOf(context)
                                            .languageCode ==
                                        'pt'
                                  ? 'Nenhuma palavra começa com "$_selectedLetter"'
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
                                  ? tr(
                                      context,
                                      "Tap words in lyrics while playing songs to save them!",
                                    )
                                  : tr(
                                      context,
                                      "Select another letter from the A–Z bar above.",
                                    ),
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
                          targetLanguage: _translationLanguage,
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
  final String targetLanguage;
  final VoidCallback onToggleKnown;

  const _DictionaryEntry({
    super.key,
    required this.item,
    required this.targetLanguage,
    required this.onToggleKnown,
  });

  @override
  State<_DictionaryEntry> createState() => _DictionaryEntryState();
}

class _DictionaryEntryState extends State<_DictionaryEntry> {
  Future<WordDefinition?>? _definition;

  void _lookup() {
    final futureDefinition = DictionaryService().lookupWord(
      widget.item.normalizedWord,
      sourceLang: widget.item.language,
      targetLang: widget.targetLanguage,
    );

    setState(() {
      _definition = futureDefinition;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final item = widget.item;
    final dateStr = item.createdAt != null
        ? '${tr(context, 'Saved on')} ${item.createdAt!.day.toString().padLeft(2, '0')}/${item.createdAt!.month.toString().padLeft(2, '0')}/${item.createdAt!.year} · '
        : '';

    return Material(
      color: colors.surface,
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
                style: TextStyle(
                  color: colors.onSurface,
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
                color: item.isKnown
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
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
                    color: item.isKnown
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.isKnown
                        ? tr(context, "Known")
                        : tr(context, "Learning"),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: item.isKnown
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
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
                  '${tr(context, 'From:')} ${item.trackName!}',
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
              dateStr.endsWith(' · ')
                  ? dateStr.substring(0, dateStr.length - 3)
                  : dateStr,
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
                    padding: const EdgeInsets.all(12),
                    child: const LinearProgressIndicator(),
                  );
                }
                final data = snapshot.data;
                if (snapshot.hasError ||
                    data == null ||
                    (data.meanings.isEmpty && data.translation == null)) {
                  return TextButton.icon(
                    onPressed: _lookup,
                    icon: const Icon(CupertinoIcons.refresh, size: 16),
                    label: Text(
                      tr(context, "Definition unavailable. Try again"),
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
                                tr(context, meaning.partOfSpeech),
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
              label: Text(
                item.isKnown
                    ? tr(context, "Remove from known")
                    : tr(context, "Mark as known"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
