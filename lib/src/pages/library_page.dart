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
  String _translationLanguage = 'pt';
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
      final translationLanguage = await _languageService.getTranslationLanguage();
      if (!mounted) return;
      setState(() {
        _knownWords = migratedWords;
        _translationLanguage = translationLanguage;
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
            // Large Title Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, "Dictionary"),
                          style: TextStyle(
                            fontFamily: AppTheme.fontSF,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Localizations.localeOf(context).languageCode == 'pt'
                              ? '$totalWords ${totalWords == 1 ? 'palavra salva' : 'palavras salvas'}'
                              : '$totalWords saved ${totalWords == 1 ? 'word' : 'words'}',
                          style: TextStyle(
                            fontFamily: AppTheme.fontSF,
                            color: colors.onSurfaceVariant,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    tooltip: tr(context, "Refresh words"),
                    icon: const Icon(CupertinoIcons.arrow_clockwise, size: 20),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: tr(context, "Search words..."),
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    color: colors.onSurfaceVariant,
                    size: 20,
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: tr(context, "Clear search"),
                          icon: const Icon(CupertinoIcons.clear_circled_solid, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),

            // Language Filter Pill
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(16),
                      items: [
                        DropdownMenuItem(
                          value: 'ALL',
                          child: Text(
                            tr(context, 'All Languages'),
                            style: const TextStyle(
                              fontFamily: AppTheme.fontSF,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...languageCodes.map(
                          (code) => DropdownMenuItem(
                            value: code,
                            child: Text(
                              localizedLanguageName(context, code),
                              style: const TextStyle(
                                fontFamily: AppTheme.fontSF,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

            // A-Z selector with Apple rounded pill chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: alphabetList.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final letter = alphabetList[index];
                  final count = letterCounts[letter] ?? 0;
                  final isSelected = _selectedLetter == letter;

                  return Material(
                    color: isSelected ? colors.primary : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(19),
                    child: InkWell(
                      onTap: () => setState(() => _selectedLetter = letter),
                      borderRadius: BorderRadius.circular(19),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Text(
                          letter == 'ALL'
                              ? '${tr(context, 'ALL')} ($count)'
                              : '$letter ($count)',
                          style: TextStyle(
                            fontFamily: AppTheme.fontSF,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? colors.onPrimary
                                : (count > 0 ? colors.onSurface : colors.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Word List
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
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
                            Icon(
                              CupertinoIcons.book,
                              size: 44,
                              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              dictionaryItems.isEmpty
                                  ? tr(context, "No saved words yet")
                                  : (Localizations.localeOf(context).languageCode == 'pt'
                                      ? 'Nenhuma palavra em "$_selectedLetter"'
                                      : 'No words in "$_selectedLetter"'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: AppTheme.fontSF,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
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
                  fontFamily: AppTheme.fontSF,
                  color: colors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            // Known Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: item.isKnown
                    ? AppTheme.appleBlue.withValues(alpha: 0.12)
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
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
                        ? AppTheme.appleBlue
                        : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.isKnown
                        ? tr(context, "Known")
                        : tr(context, "Learning"),
                    style: TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: item.isKnown
                          ? AppTheme.appleBlue
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
                  style: TextStyle(
                    fontFamily: AppTheme.fontSF,
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        children: [
          Divider(color: Theme.of(context).dividerColor, height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              dateStr.endsWith(' · ')
                  ? dateStr.substring(0, dateStr.length - 3)
                  : dateStr,
              style: TextStyle(
                fontFamily: AppTheme.fontSF,
                color: colors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_definition != null)
            FutureBuilder<WordDefinition?>(
              future: _definition,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: CupertinoActivityIndicator(),
                  );
                }
                final data = snapshot.data;
                if (snapshot.hasError ||
                    data == null ||
                    (data.meanings.isEmpty && data.translation == null)) {
                  return TextButton.icon(
                    onPressed: _lookup,
                    icon: const Icon(CupertinoIcons.arrow_clockwise, size: 16),
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
                        style: TextStyle(
                          fontFamily: AppTheme.fontSF,
                          color: colors.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    if (data.translation?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          data.translation!,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontSF,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    for (final meaning in data.meanings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (meaning.partOfSpeech.isNotEmpty)
                              Text(
                                tr(context, meaning.partOfSpeech),
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontSF,
                                  color: AppTheme.appleBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            const SizedBox(height: 3),
                            Text(
                              meaning.definition,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontSF,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            if (meaning.example?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '“${meaning.example}”',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontSF,
                                    color: colors.onSurfaceVariant,
                                    fontSize: 13,
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
                    ? CupertinoIcons.bookmark_fill
                    : CupertinoIcons.bookmark,
                size: 16,
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
