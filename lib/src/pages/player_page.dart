import 'dart:async';

import '../core/services/app_strings.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt;

import '../core/models/lyric_line_model.dart';
import '../core/models/track_model.dart';
import '../core/repositories/known_words_repository.dart';
import '../core/services/audio_player_service.dart';
import '../core/services/dictionary_service.dart';
import '../core/services/language_service.dart';
import '../core/services/lyrics_service.dart';
import '../core/services/spotify_service.dart';
import '../core/services/saved_tracks.dart';
import '../core/services/spotify_session.dart';
import '../core/services/youtube_service.dart';
import '../widgets/lyrics/interactive_word.dart';
import '../widgets/lyrics/language_selector_sheet.dart';
import '../widgets/lyrics/vocabulary_progress_bar.dart';
import '../widgets/lyrics/word_action_sheet.dart';
import '../widgets/playback_source_badge.dart';
import '../widgets/spotify_icon.dart';

/// Modo de exibição das letras:
/// - `synced`: a letra acompanha a música com rolagem automática e destaque na linha ativa.
/// - `manual`: a letra completa fica na tela e o usuário rola manualmente livremente.
enum LyricsDisplayMode { synced, manual }

/// Tela do player minimalista com tipografia monoespaçada e controles estilo Spotify.
class PlayerPage extends StatefulWidget {
  final TrackModel track;
  final bool followCurrent;
  final bool lyricsOnly;
  final LyricsResult? initialLyrics;
  final LanguageService? languageService;
  final KnownWordsRepository? wordsRepository;
  final List<TrackModel>? playlist;
  final int? initialIndex;

  const PlayerPage({
    super.key,
    required this.track,
    this.followCurrent = false,
    this.lyricsOnly = false,
    this.initialLyrics,
    this.languageService,
    this.wordsRepository,
    this.playlist,
    this.initialIndex,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with SingleTickerProviderStateMixin {
  // Apple Clean Light & Dark Themes
  static const Color _lightBg = AppTheme.white;
  static const Color _lightInk = AppTheme.labelLight;
  static const Color _lightMuted = AppTheme.secondaryLabelLight;
  static const Color _spotifyGreen = AppTheme.spotifyGreen;

  // Apple OLED Dark Theme
  static const Color _darkBg = AppTheme.black;
  static const Color _darkInk = AppTheme.labelDark;
  static const Color _darkMuted = AppTheme.secondaryLabelDark;

  Color get _canvasColor => _isLightStyle ? _lightBg : _darkBg;
  Color get _primaryInk => _isLightStyle ? _lightInk : _darkInk;
  Color get _secondaryInk => _isLightStyle ? _lightMuted : _darkMuted;

  // Serviços
  final AudioPlayerService _audioService = AudioPlayerService();
  final LyricsService _lyricsService = LyricsService();
  late final KnownWordsRepository _wordsRepo =
      widget.wordsRepository ?? KnownWordsRepository();
  late final LanguageService _languageService =
      widget.languageService ?? LanguageService();

  // Faixa atual e playlist
  late TrackModel _currentTrack;
  late List<TrackModel> _playlist;
  late int _currentIndex;
  int _trackLoadGeneration = 0;
  bool _requestingTrack = false;
  String? _expectedUri;
  int _lyricsGeneration = 0;

  // Estado da letra
  LyricsResult? _lyricsResult;
  bool _lyricsLoading = true;
  LyricsDisplayMode _lyricsMode = LyricsDisplayMode.manual;

  // Palavras conhecidas
  Set<String> _knownWords = {};
  int _knownUniqueInLyrics = 0;
  int _totalUniqueWords = 0;
  Set<String> _uniqueLyricWords = {};

  // Sincronização
  int _activeLineIndex = -1;
  final ScrollController _lyricsScrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};

  // YouTube Controller & Estado
  yt.YoutubePlayerController? _ytController;
  Timer? _ytProgressTimer;
  bool _showVideo = false;
  bool get _isYouTubeTrack =>
      _currentTrack.id.startsWith('youtube:') ||
      (_currentTrack.previewAudioUrl?.startsWith('youtube:') == true);

  void _startYouTubeProgressTimer() {
    _ytProgressTimer?.cancel();
    _ytProgressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (!mounted || _ytController == null) return;
      try {
        final pos = await _ytController!.currentTime;
        final dur = await _ytController!.duration;
        if (mounted && pos >= 0) {
          _audioService.position.value = Duration(
            milliseconds: (pos * 1000).round(),
          );
        }
        if (mounted && dur > 0) {
          final targetDur = Duration(milliseconds: (dur * 1000).round());
          if (_audioService.duration.value != targetDur) {
            _audioService.duration.value = targetDur;
          }
        }
      } catch (_) {}
    });
  }

  void _stopYouTubeProgressTimer() {
    _ytProgressTimer?.cancel();
    _ytProgressTimer = null;
  }

  void _initYouTubeController(String videoId) {
    _stopYouTubeProgressTimer();
    _ytController?.close();
    _audioService.playerState.value = PlayerState(
      false,
      ProcessingState.loading,
    );
    final controller = yt.YoutubePlayerController(
      params: const yt.YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        mute: false,
        showVideoAnnotations: false,
        loop: false,
        enableCaption: false,
        playsInline: true,
      ),
    );

    controller.loadVideoById(videoId: videoId);

    controller.listen((event) async {
      if (!mounted) return;
      if (event.playerState == yt.PlayerState.playing) {
        _audioService.playerState.value = PlayerState(
          true,
          ProcessingState.ready,
        );
        _startYouTubeProgressTimer();
      } else if (event.playerState == yt.PlayerState.paused) {
        _audioService.playerState.value = PlayerState(
          false,
          ProcessingState.ready,
        );
        _stopYouTubeProgressTimer();
      } else if (event.playerState == yt.PlayerState.buffering) {
        _audioService.playerState.value = PlayerState(
          false,
          ProcessingState.buffering,
        );
      } else if (event.playerState == yt.PlayerState.ended) {
        _audioService.playerState.value = PlayerState(
          false,
          ProcessingState.completed,
        );
        _stopYouTubeProgressTimer();
        _onPlayerStateChanged();
      }

      final pos = await controller.currentTime;
      final dur = await controller.duration;
      if (mounted && pos >= 0) {
        _audioService.position.value = Duration(
          milliseconds: (pos * 1000).round(),
        );
      }
      if (dur > 0 && mounted) {
        _audioService.duration.value = Duration(
          milliseconds: (dur * 1000).round(),
        );
      }
    });

    setState(() {
      _ytController = controller;
    });
  }

  // Offset manual de sincronização em milissegundos
  int _syncOffsetMs = 0;

  // Idiomas
  String _targetLanguage = 'en';
  String? _detectedTrackLanguage;
  String? _manualTrackLanguage;
  String _preferredTargetLanguage = 'en';
  int _knownWordsGeneration = 0;
  bool _knownWordsLoading = false;
  String _nativeLanguage = 'pt';
  String _translationLanguage = 'en';

  // Tema: false = Dark Minimal com texto branco (padrão solicitado), true = Sage Paper minimalista
  bool _isLightStyle = true;

  // Animação de entrada
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _isLightStyle = AppThemeMode.instance.isLight;
    AppThemeMode.instance.addListener(_onThemeChanged);
    AppRoutes.currentRoute.value = AppRoutes.player;
    _currentTrack = widget.track;
    _targetLanguage = _currentTrack.language.isEmpty
        ? 'en'
        : _currentTrack.language;
    _playlist = widget.playlist != null && widget.playlist!.isNotEmpty
        ? widget.playlist!
        : SpotifyService.curatedTracks;
    _currentIndex =
        widget.initialIndex ??
        _playlist.indexWhere((t) => t.id == _currentTrack.id);
    if (_currentIndex == -1) _currentIndex = 0;

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _loadLyrics();
    _loadAll();
    _audioService.position.addListener(_onPositionChanged);
    _audioService.playerState.addListener(_onPlayerStateChanged);
    if (!widget.lyricsOnly) {
      SpotifySession.instance.playbackChanges.addListener(
        _onSpotifyTrackChanged,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.lyricsOnly) return;
      if (_isYouTubeTrack) {
        final videoId = YouTubeService.extractVideoId(_currentTrack.id) ??
            YouTubeService.extractVideoId(_currentTrack.previewAudioUrl ?? '');
        if (videoId != null && videoId.isNotEmpty) {
          _initYouTubeController(videoId);
        }
      } else if (widget.followCurrent) {
        _audioService.syncSpotifyTrack(_currentTrack.id);
      } else {
        _expectedUri = _currentTrack.id;
        _requestingTrack = true;
        await _audioService.play(
          _currentTrack.previewAudioUrl ?? '',
          track: _currentTrack,
        );
        _requestingTrack = false;
      }
      if (mounted) _updateSpotifyTrack();
    });
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() => _isLightStyle = AppThemeMode.instance.isLight);
    }
  }

  void _onPlayerStateChanged() {
    final state = _audioService.playerState.value;
    if (state.processingState == ProcessingState.completed) {
      if (_audioService.loopMode.value == LoopMode.all) {
        _onNext();
      }
    }
  }

  void _onSpotifyTrackChanged() {
    _updateSpotifyTrack();
  }

  Future<void> _updateSpotifyTrack() async {
    if (widget.lyricsOnly || _requestingTrack) return;
    if (_currentTrack.id.startsWith('youtube:')) return;
    final session = SpotifySession.instance;
    final uri = session.uri;
    final metadata = session.currentTrack;
    if (_expectedUri != null) {
      if (uri != _expectedUri) return;
      _expectedUri = null;
    }
    if (session.remoteOnly &&
        (session.state['ready'] != true || metadata == null)) {
      return;
    }
    if (!RegExp(r'^spotify:track:[a-zA-Z0-9]{22}$').hasMatch(uri) ||
        (uri == _currentTrack.id &&
            (!session.remoteOnly ||
                (metadata!.title == _currentTrack.title &&
                    metadata.artist == _currentTrack.artist &&
                    metadata.album == _currentTrack.album)))) {
      return;
    }
    final generation = ++_trackLoadGeneration;
    final resolved = await SpotifySession.instance.resolve(
      TrackModel(
        id: uri,
        title: '',
        artist: '',
        album: '',
        previewAudioUrl: null,
        language: uri == _currentTrack.id ? _currentTrack.language : '',
      ),
    );
    if (!mounted || generation != _trackLoadGeneration) return;
    setState(() {
      if (_currentTrack.id != resolved.id) {
        _manualTrackLanguage = null;
        _detectedTrackLanguage = null;
      }
      _currentTrack = resolved;
      _targetLanguage = _resolveTargetLanguage();
      _knownWords = {};
      _lyricsLoading = true;
      _lyricsResult = null;
      _activeLineIndex = -1;
      _lineKeys.clear();
    });
    _audioService.syncSpotifyTrack(uri);
    await _loadLyrics();
    await _loadAll();
  }

  String _resolveTargetLanguage() =>
      _manualTrackLanguage ??
      _detectedTrackLanguage ??
      (_currentTrack.language.isNotEmpty
          ? _currentTrack.language
          : _preferredTargetLanguage);

  Future<void> _loadAll() async {
    final generation = _lyricsGeneration;
    try {
      final native = await _languageService.getNativeLanguage();
      final preferred = await _languageService.getTargetLanguage();
      final appLanguage = await _languageService.getAppLanguage();
      if (!mounted || generation != _lyricsGeneration) return;
      setState(() {
        _nativeLanguage = native;
        _preferredTargetLanguage = preferred;
        _translationLanguage = appLanguage;
        // Resolve after all awaits: a lyric/manual choice may have arrived meanwhile.
        _targetLanguage = _resolveTargetLanguage();
        if (_lyricsResult != null) _buildUniqueWords(_lyricsResult!.lines);
      });
      await _loadKnownWords();
    } catch (e) {
      debugPrint('Error loading language preferences: $e');
    }
  }

  Future<void> _loadKnownWords() async {
    final generation = ++_knownWordsGeneration;
    final language = _targetLanguage;
    final track = _currentTrack.id;
    if (mounted) setState(() => _knownWordsLoading = true);
    try {
      await _wordWrites;
      final words = await _wordsRepo.getKnownWordsSet(language);
      if (mounted &&
          generation == _knownWordsGeneration &&
          language == _targetLanguage &&
          track == _currentTrack.id) {
        setState(() => _knownWords = words);
        _updateStats();
      }
    } catch (e) {
      debugPrint('Error loading known words: $e');
    } finally {
      if (mounted && generation == _knownWordsGeneration) {
        setState(() => _knownWordsLoading = false);
      }
    }
  }

  Future<void> _loadLyrics() async {
    final generation = ++_lyricsGeneration;
    if (_currentTrack.title.isEmpty || _currentTrack.artist.isEmpty) {
      if (mounted) setState(() => _lyricsLoading = false);
      _fadeCtrl.forward();
      return;
    }
    SavedTracks.instance.remember(_currentTrack).catchError((Object error) {
      debugPrint('Could not save recent track: $error');
    });
    if (mounted) setState(() => _lyricsLoading = true);
    try {
      final result =
          (_currentTrack.id == widget.track.id ? widget.initialLyrics : null) ??
          await _lyricsService.getLyrics(
            trackName: _currentTrack.title,
            artistName: _currentTrack.artist,
            albumName: _currentTrack.album.isNotEmpty
                ? _currentTrack.album
                : null,
            duration: _currentTrack.duration,
          );
      if (mounted && generation == _lyricsGeneration) {
        final detected = detectLyricLanguage(
          result?.plainText?.trim().isNotEmpty == true
              ? result!.plainText!
              : result?.lines.map((line) => line.rawText).join(' ') ?? '',
        );
        _detectedTrackLanguage = detected;
        final previousLanguage = _targetLanguage;
        _targetLanguage = _resolveTargetLanguage();
        if (_targetLanguage != previousLanguage) _knownWords = {};
        setState(() {
          _lyricsResult = result;
          _lyricsLoading = false;
          _lineKeys.clear();
          _activeLineIndex = -1;
          _lyricsMode = !widget.lyricsOnly && result?.isSynced == true
              ? LyricsDisplayMode.synced
              : LyricsDisplayMode.manual;
        });
        if (result != null) {
          _buildUniqueWords(result.lines);
          // The language may have changed after the lyrics were identified.
          // Reload the dictionary for this track so words from another
          // language are never used to calculate or display this song's state.
          await _loadKnownWords();
          if (!mounted || generation != _lyricsGeneration) return;
          _updateStats();
          _onPositionChanged();
        }
        _fadeCtrl.forward();
      }
    } catch (e) {
      debugPrint('Error loading lyrics: $e');
      if (mounted && generation == _lyricsGeneration) {
        setState(() => _lyricsLoading = false);
      }
    }
  }

  void _buildUniqueWords(List<LyricLine> lines) {
    _uniqueLyricWords = lines
        .expand((l) => l.words)
        .where(_isStudyWord)
        .map((t) => t.normalizedWord)
        .toSet();
    _totalUniqueWords = _uniqueLyricWords.length;
  }

  void _updateStats() {
    _knownUniqueInLyrics = _uniqueLyricWords.intersection(_knownWords).length;
    if (mounted) setState(() {});
  }

  bool _isStudyWord(WordToken token) {
    if (!token.isWord) return false;
    // Non-ASCII tokens are not English vocabulary; show them as already known
    // instead of adding Spanish/other accented words to the English dictionary.
    if (_targetLanguage == 'en' && !isLikelyEnglishWord(token.displayText)) {
      return false;
    }
    return true;
  }

  void _onPositionChanged() {
    if (!mounted || _lyricsResult == null || !_lyricsResult!.isSynced) return;
    final lines = _lyricsResult!.lines;
    // Aplica o offset de sincronização (atrasando a letra para sincronizar perfeitamente com a voz)
    final pos =
        _audioService.position.value + Duration(milliseconds: _syncOffsetMs);

    final newActive = LyricParser.activeLineAt(lines, pos);

    if (newActive != _activeLineIndex) {
      if (newActive >= 0 && newActive < lines.length) {
        DictionaryService().prefetchSentence(
          lines[newActive].rawText,
          sourceLang: _targetLanguage,
          targetLang: _translationLanguage,
        );
      }
      if (_lyricsMode == LyricsDisplayMode.synced) {
        setState(() => _activeLineIndex = newActive);
      } else {
        _activeLineIndex = newActive;
      }
      if (newActive >= 0 && _lyricsMode == LyricsDisplayMode.synced) {
        _scrollToActive(newActive);
      }
    }
  }

  void _scrollToActive(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _lyricsMode != LyricsDisplayMode.synced ||
          index != _activeLineIndex) {
        return;
      }
      final lineContext = _lineKeys[index]?.currentContext;
      if (lineContext == null) return;
      Scrollable.ensureVisible(
        lineContext,
        alignment: 0.35,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _wordWrites = Future<void>.value();
  final Map<String, int> _wordVersions = {};
  final Map<String, bool> _savedWordStates = {};

  Future<void> _toggleWord(String word, String normalized) async {
    if (_knownWordsLoading || _lyricsLoading) return;
    final language = _targetLanguage;
    final key = '$language:$normalized';
    final previous = _knownWords.contains(normalized);
    final desired = !previous;
    final version = (_wordVersions[key] ?? 0) + 1;
    _wordVersions[key] = version;
    _savedWordStates.putIfAbsent(key, () => previous);
    final trackName = _currentTrack.title;
    final artistName = _currentTrack.artist;
    final trackId = _currentTrack.id;
    setState(() {
      desired ? _knownWords.add(normalized) : _knownWords.remove(normalized);
      _updateStats();
    });

    // Preserve tap order without delaying visual feedback or later taps.
    final write = _wordWrites.then((_) async {
      await _wordsRepo.setWordKnown(
        word,
        language,
        desired,
        trackName: trackName,
        artistName: artistName,
      );
      _savedWordStates[key] = desired;
    });
    _wordWrites = write.catchError((Object _) {});
    try {
      await write;
    } catch (_) {
      if (mounted &&
          language == _targetLanguage &&
          trackId == _currentTrack.id &&
          _wordVersions[key] == version) {
        setState(() {
          _savedWordStates[key] == true
              ? _knownWords.add(normalized)
              : _knownWords.remove(normalized);
          _updateStats();
        });
      }
      rethrow;
    }
  }

  Future<void> _markSentenceWordsKnown(List<String> words) async {
    if (_knownWordsLoading || _lyricsLoading || words.isEmpty) return;
    final language = _targetLanguage;
    final trackName = _currentTrack.title;
    final artistName = _currentTrack.artist;
    final trackId = _currentTrack.id;

    final normalizedList =
        words.map((w) => w.toLowerCase().trim()).where((w) => w.isNotEmpty).toList();
    if (normalizedList.isEmpty) return;

    setState(() {
      _knownWords.addAll(normalizedList);
      _updateStats();
    });

    final write = _wordWrites.then((_) async {
      await _wordsRepo.setWordsKnown(
        words,
        language,
        true,
        trackName: trackName,
        artistName: artistName,
      );
      for (final norm in normalizedList) {
        _savedWordStates['$language:$norm'] = true;
      }
    });
    _wordWrites = write.catchError((Object _) {});
    try {
      await write;
    } catch (_) {
      if (mounted && language == _targetLanguage && trackId == _currentTrack.id) {
        await _loadKnownWords();
      }
    }
  }

  void _openWordActionSheet(
    String rawWord,
    String normalized, {
    String? sentence,
  }) {
    if (_knownWordsLoading || _lyricsLoading) return;
    final track = _currentTrack.id;
    final language = _targetLanguage;
    final isKnown = _knownWords.contains(normalized);
    WordActionSheet.show(
      context,
      rawWord: rawWord,
      normalized: normalized,
      sentence: sentence,
      isInitiallyKnown: isKnown,
      sourceLanguage: _targetLanguage,
      targetLanguage: _translationLanguage,
      onToggleWord: () async {
        if (!mounted ||
            track != _currentTrack.id ||
            language != _targetLanguage) {
          return;
        }
        await _toggleWord(rawWord, normalized);
      },
      onMarkSentenceKnown: (words) async {
        if (!mounted ||
            track != _currentTrack.id ||
            language != _targetLanguage) {
          return;
        }
        await _markSentenceWordsKnown(words);
      },
    );
  }

  Future<void> _onLanguagesUpdated(String native, String target) async {
    if (!mounted) return;
    setState(() {
      _manualTrackLanguage = target;
      _nativeLanguage = native;
      _targetLanguage = target;
      _knownWords = {};
      _knownUniqueInLyrics = 0;
      if (_lyricsResult != null) _buildUniqueWords(_lyricsResult!.lines);
    });
    await _loadKnownWords();
    await _languageService.setNativeLanguage(native);
    await _languageService.setTargetLanguage(target);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showSyncSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isLightStyle ? Colors.white : AppTheme.spotifyDarkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final textColor = _isLightStyle
                ? const Color(0xFF1C1C1E)
                : Colors.white;
            final subColor = _isLightStyle
                ? const Color(0xFF8E8E93)
                : AppTheme.spotifyLightGray;
            final btnBg = _isLightStyle
                ? const Color(0xFFF2F2F7)
                : AppTheme.spotifyMediumGray;

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: subColor.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr(context, "Calibrate Sync"),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      context,
                      "Adjust to advance (+) or delay (-) the lyrics timing.",
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subColor, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _syncButton(
                        '-200ms',
                        () {
                          setState(() => _syncOffsetMs -= 200);
                          setSheetState(() {});
                          _onPositionChanged();
                        },
                        btnBg,
                        textColor,
                      ),
                      const SizedBox(width: 8),
                      _syncButton(
                        '-100ms',
                        () {
                          setState(() => _syncOffsetMs -= 100);
                          setSheetState(() {});
                          _onPositionChanged();
                        },
                        btnBg,
                        textColor,
                      ),
                      const SizedBox(width: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _isLightStyle ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_syncOffsetMs >= 0 ? "+" : ""}${_syncOffsetMs}ms',
                          style: TextStyle(
                            color: _isLightStyle ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      _syncButton(
                        '+100ms',
                        () {
                          setState(() => _syncOffsetMs += 100);
                          setSheetState(() {});
                          _onPositionChanged();
                        },
                        btnBg,
                        textColor,
                      ),
                      const SizedBox(width: 8),
                      _syncButton(
                        '+200ms',
                        () {
                          setState(() => _syncOffsetMs += 200);
                          setSheetState(() {});
                          _onPositionChanged();
                        },
                        btnBg,
                        textColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() => _syncOffsetMs = 0);
                      setSheetState(() {});
                      _onPositionChanged();
                    },
                    child: Text(
                      tr(context, "Reset (0ms)"),
                      style: TextStyle(color: subColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _syncButton(String label, VoidCallback onTap, Color bg, Color text) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: text,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _changeTrack(int newIndex) async {
    if (newIndex < 0 || newIndex >= _playlist.length) return;
    setState(() {
      _currentIndex = newIndex;
      _currentTrack = _playlist[newIndex];
      _manualTrackLanguage = null;
      _detectedTrackLanguage = null;
      _targetLanguage = _resolveTargetLanguage();
      _knownWords = {};
      _lyricsLoading = true;
      _lyricsResult = null;
      _activeLineIndex = -1;
      _lineKeys.clear();
    });
    _loadLyrics();
    _loadAll();

    if (_isYouTubeTrack) {
      final videoId = YouTubeService.extractVideoId(_currentTrack.id) ??
          YouTubeService.extractVideoId(_currentTrack.previewAudioUrl ?? '');
      if (videoId != null && videoId.isNotEmpty) {
        _initYouTubeController(videoId);
      }
    } else {
      _ytController?.close();
      _ytController = null;
      _requestingTrack = true;
      await _audioService.play(
        _currentTrack.previewAudioUrl ?? '',
        track: _currentTrack,
      );
      _requestingTrack = false;
      if (mounted) _updateSpotifyTrack();
    }
  }

  Future<void> _skipRemote(String action) async {
    try {
      await SpotifySession.instance.command(action);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, "Could not change the Spotify track.")),
          ),
        );
      }
    }
  }

  void _onPrevious() {
    if (_isYouTubeTrack && _ytController != null) {
      final pos = _audioService.position.value;
      if (pos.inSeconds > 3 || _playlist.isEmpty) {
        _ytController!.seekTo(seconds: 0, allowSeekAhead: true);
        _audioService.position.value = Duration.zero;
      } else {
        final prevIndex = _currentIndex > 0
            ? _currentIndex - 1
            : _playlist.length - 1;
        _changeTrack(prevIndex);
      }
      return;
    }

    if (_audioService.isDirectAudio) {
      final pos = _audioService.position.value;
      if (pos.inSeconds > 3 || _playlist.isEmpty) {
        _audioService.seekTo(Duration.zero);
      } else {
        final prevIndex = _currentIndex > 0
            ? _currentIndex - 1
            : _playlist.length - 1;
        _changeTrack(prevIndex);
      }
      return;
    }

    if (SpotifySession.instance.remoteOnly) {
      _expectedUri = null;
      _skipRemote('previous');
      return;
    }
    final pos = _audioService.position.value;
    if (pos.inSeconds > 3) {
      _audioService.seekTo(Duration.zero);
      return;
    }
    if (_playlist.isNotEmpty) {
      final prevIndex = _currentIndex > 0
          ? _currentIndex - 1
          : _playlist.length - 1;
      _changeTrack(prevIndex);
    } else {
      _audioService.seekTo(Duration.zero);
    }
  }

  void _onNext() {
    if (_isYouTubeTrack || _audioService.isDirectAudio) {
      if (_playlist.isEmpty) return;
      if (_audioService.shuffleMode.value && _playlist.length > 1) {
        int nextIndex;
        do {
          nextIndex = (DateTime.now().millisecondsSinceEpoch % _playlist.length);
        } while (nextIndex == _currentIndex);
        _changeTrack(nextIndex);
      } else {
        final nextIndex = (_currentIndex + 1) % _playlist.length;
        _changeTrack(nextIndex);
      }
      return;
    }

    if (SpotifySession.instance.remoteOnly) {
      _expectedUri = null;
      _skipRemote('next');
      return;
    }
    if (_playlist.isEmpty) return;
    if (_audioService.shuffleMode.value && _playlist.length > 1) {
      int nextIndex;
      do {
        nextIndex = (DateTime.now().millisecondsSinceEpoch % _playlist.length);
      } while (nextIndex == _currentIndex);
      _changeTrack(nextIndex);
    } else {
      final nextIndex = (_currentIndex + 1) % _playlist.length;
      _changeTrack(nextIndex);
    }
  }

  @override
  void dispose() {
    AppThemeMode.instance.removeListener(_onThemeChanged);
    _audioService.position.removeListener(_onPositionChanged);
    _audioService.playerState.removeListener(_onPlayerStateChanged);
    SpotifySession.instance.playbackChanges.removeListener(
      _onSpotifyTrackChanged,
    );
    _stopYouTubeProgressTimer();
    _ytController?.close();
    _audioService.dispose();
    _lyricsScrollController.dispose();
    _fadeCtrl.dispose();
    if (AppRoutes.currentRoute.value == AppRoutes.player) {
      AppRoutes.currentRoute.value = AppRoutes.home;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _isLightStyle
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _canvasColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              if (_isYouTubeTrack && _ytController != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: _showVideo
                      ? const EdgeInsets.fromLTRB(16, 4, 16, 8)
                      : EdgeInsets.zero,
                  height: _showVideo ? 180 : 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Opacity(
                      opacity: _showVideo ? 1.0 : 0.01,
                      child: yt.YoutubePlayer(
                        controller: _ytController!,
                        aspectRatio: 16 / 9,
                      ),
                    ),
                  ),
                ),
              if (_knownWordsLoading)
                const LinearProgressIndicator(minHeight: 2),
              if (!widget.lyricsOnly) _buildModeSelector(),
              if (_totalUniqueWords > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 2,
                  ),
                  child: VocabularyProgressBar(
                    knownCount: _knownUniqueInLyrics,
                    totalCount: _totalUniqueWords,
                    isLightMode: _isLightStyle,
                  ),
                ),
              Expanded(child: _buildLyricsArea()),
              if (widget.lyricsOnly)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    AppLanguage.instance.isPortuguese
                        ? 'Leitura da letra • sem reprodução'
                        : 'Lyrics reading • no playback',
                    style: TextStyle(color: _secondaryInk),
                  ),
                )
              else
                _buildControls(media),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final lang = _languageService.findByCode(_targetLanguage);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 2),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () {
                if (AppRoutes.currentRoute.value == AppRoutes.player) {
                  AppRoutes.currentRoute.value = AppRoutes.home;
                }
                Navigator.of(context).pop();
              },
              icon: const Icon(CupertinoIcons.chevron_left, size: 28),
              color: _primaryInk,
              tooltip: tr(context, "Back"),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 52),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentTrack.title.isEmpty
                      ? (_isYouTubeTrack ? 'YouTube' : 'Spotify')
                      : _currentTrack.title,
                  style: TextStyle(
                    color: _primaryInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    decoration: TextDecoration.none,
                    decorationColor: _primaryInk,
                    decorationThickness: 1.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PlaybackSourceBadge(
                      isYouTube: _isYouTubeTrack,
                      isSpotify: !_isYouTubeTrack,
                      iconSize: 13,
                    ),
                    if (_currentTrack.artist.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _currentTrack.artist,
                          style: TextStyle(
                            color: _secondaryInk,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isYouTubeTrack) ...[
                  IconButton(
                    onPressed: () {
                      final videoId =
                          YouTubeService.extractVideoId(_currentTrack.id) ?? '';
                      if (videoId.isNotEmpty) {
                        launchUrl(
                          Uri.parse('https://www.youtube.com/watch?v=$videoId'),
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    icon: const Icon(
                      CupertinoIcons.play_rectangle_fill,
                      size: 20,
                      color: Colors.redAccent,
                    ),
                    tooltip: tr(context, "Open in YouTube App"),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _showVideo = !_showVideo),
                    icon: Icon(
                      _showVideo ? CupertinoIcons.film_fill : CupertinoIcons.film,
                      size: 19,
                      color: _showVideo ? Colors.redAccent : _primaryInk,
                    ),
                    tooltip: _showVideo
                        ? tr(context, "Hide video")
                        : tr(context, "Show video"),
                  ),
                ] else ...[
                  IconButton(
                    onPressed: () {
                      String? url = _currentTrack.spotifyUrl;
                      if (url == null || url.isEmpty) {
                        if (_currentTrack.id.startsWith('spotify:track:')) {
                          final id = _currentTrack.id.split(':').last;
                          url = 'https://open.spotify.com/track/$id';
                        } else if (_currentTrack.title.isNotEmpty) {
                          url =
                              'https://open.spotify.com/search/${Uri.encodeComponent("${_currentTrack.title} ${_currentTrack.artist}")}';
                        }
                      }
                      if (url != null && url.isNotEmpty) {
                        launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    icon: const SpotifyIcon(size: 20),
                    tooltip: tr(context, "Open in Spotify App"),
                  ),
                ],
                if (_lyricsMode == LyricsDisplayMode.synced &&
                    (_lyricsResult?.isSynced ?? false))
                  IconButton(
                    onPressed: () => _showSyncSheet(context),
                    icon: const Icon(
                      CupertinoIcons.slider_horizontal_3,
                      size: 18,
                    ),
                    color: _primaryInk,
                    tooltip: tr(context, "Adjust sync"),
                  ),
                IconButton(
                  onPressed: () =>
                      AppThemeMode.instance.setLight(!_isLightStyle),
                  icon: Icon(
                    _isLightStyle
                        ? CupertinoIcons.moon
                        : CupertinoIcons.sun_max,
                    size: 18,
                    color: _primaryInk,
                  ),
                  tooltip: _isLightStyle
                      ? tr(context, "Dark mode")
                      : tr(context, "Paper mode"),
                ),
                GestureDetector(
                  onTap: () => LanguageSelectorSheet.show(
                    context,
                    currentNativeLanguage: _nativeLanguage,
                    currentTargetLanguage: _targetLanguage,
                    languageService: _languageService,
                    onConfirm: _onLanguagesUpdated,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryInk.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.globe,
                          size: 13,
                          color: _primaryInk,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (lang?.code ?? _targetLanguage).toUpperCase(),
                          style: TextStyle(
                            color: _primaryInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsArea() {
    if (_lyricsLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: _isLightStyle ? Colors.black : AppTheme.spotifyGreen,
          strokeWidth: 2,
        ),
      );
    }

    if (_lyricsResult == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.doc_text,
                size: 52,
                color: _isLightStyle
                    ? const Color(0xFFC7C7CC)
                    : AppTheme.spotifyMediumGray,
              ),
              const SizedBox(height: 16),
              Text(
                tr(context, "Lyrics not available\nfor this track."),
                style: TextStyle(
                  color: _isLightStyle
                      ? const Color(0xFF8E8E93)
                      : AppTheme.spotifyLightGray,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final lines = _lyricsResult!.lines;

    return FadeTransition(
      opacity: _fadeAnim,
      // Letras têm tamanho limitado: montar as linhas permite saltar para
      // qualquer verso, inclusive depois de buscar uma posição distante.
      child: SingleChildScrollView(
        controller: _lyricsScrollController,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(lines.length, (i) {
            _lineKeys[i] ??= GlobalKey();
            return _buildLine(lines[i], i);
          }),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    if (_lyricsLoading || _lyricsResult == null) return const SizedBox.shrink();

    final isTrackSynced = _lyricsResult?.isSynced ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Container(
        height: 32,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: _primaryInk.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Modo Texto Livre
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_lyricsMode != LyricsDisplayMode.manual) {
                    setState(() => _lyricsMode = LyricsDisplayMode.manual);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: _lyricsMode == LyricsDisplayMode.manual
                        ? _primaryInk
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tr(context, "FREE TEXT"),
                    style: TextStyle(
                      color: _lyricsMode == LyricsDisplayMode.manual
                          ? _canvasColor
                          : _secondaryInk,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),

            // Modo Acompanhar
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!isTrackSynced) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr(context, "This track only has plain text lyrics."),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  if (_lyricsMode != LyricsDisplayMode.synced) {
                    setState(() => _lyricsMode = LyricsDisplayMode.synced);
                    if (_activeLineIndex >= 0) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToActive(_activeLineIndex);
                      });
                    }
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: _lyricsMode == LyricsDisplayMode.synced
                        ? _primaryInk
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tr(context, "FOLLOW"),
                    style: TextStyle(
                      color: _lyricsMode == LyricsDisplayMode.synced
                          ? _canvasColor
                          : _secondaryInk,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLine(LyricLine line, int index) {
    final isSyncedTrack = _lyricsResult!.isSynced;
    final isAutoSync = _lyricsMode == LyricsDisplayMode.synced && isSyncedTrack;
    final isActive = isAutoSync && index == _activeLineIndex;
    final isManual = _lyricsMode == LyricsDisplayMode.manual;

    if (line.isEmpty) return SizedBox(key: _lineKeys[index], height: 18);

    final hasTimestamp = isSyncedTrack || line.timestamp != Duration.zero;

    return InkWell(
      onTap: () {
        if (hasTimestamp) {
          final target = line.timestamp - Duration(milliseconds: _syncOffsetMs);
          final seekTarget = target.isNegative ? Duration.zero : target;
          if (_isYouTubeTrack && _ytController != null) {
            _ytController!.seekTo(
              seconds: seekTarget.inMilliseconds / 1000.0,
              allowSeekAhead: true,
            );
            _audioService.position.value = seekTarget;
          } else {
            _audioService.seekTo(seekTarget);
          }
        }
      },
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        key: _lineKeys[index],
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? (_isLightStyle
                  ? const Color(0xFFFFF176)
                  : const Color(0xFFFFD600))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border.all(
                  color: const Color(0xFFFFD600),
                  width: 0.8,
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Coluna de Timestamp alinhada e centralizada verticalmente
            SizedBox(
              width: 46,
              child: Text(
                hasTimestamp ? _fmt(line.timestamp) : '     ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive
                      ? (_isLightStyle ? Colors.black : Colors.white)
                      : _secondaryInk.withValues(alpha: 0.75),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Verso da música no modo Acompanhar
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: line.words.map((token) {
                  if (!token.isWord) {
                    return PunctuationSpan(
                      text: token.displayText,
                      isActiveLine: isActive,
                      isLightMode: _isLightStyle,
                      isManualMode: isManual,
                      customColor: isActive
                          ? (_isLightStyle ? Colors.black : Colors.white)
                          : null,
                    );
                  }
                  final isStudyWord = _isStudyWord(token);
                  if (!isStudyWord) {
                    return PunctuationSpan(
                      text: token.displayText,
                      isActiveLine: isActive,
                      isLightMode: _isLightStyle,
                      isManualMode: isManual,
                      customColor: isActive
                          ? (_isLightStyle ? Colors.black : Colors.white)
                          : null,
                    );
                  }
                  return InteractiveWord(
                    word: token.displayText,
                    isKnown: _knownWords.contains(token.normalizedWord),
                    isActiveLine: isActive,
                    isLightMode: _isLightStyle,
                    isManualMode: isManual,
                    customColor: isActive
                        ? (_isLightStyle ? Colors.black : Colors.white)
                        : null,
                    onToggle: () async {
                      try {
                        await _toggleWord(
                          token.displayText,
                          token.normalizedWord,
                        );
                      } catch (_) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              tr(
                                context,
                                "Could not save the word. Try again.",
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    onWordPressed: (w, details) => _openWordActionSheet(
                      token.displayText,
                      token.normalizedWord,
                      sentence: line.rawText,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(MediaQueryData media) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 6, 20, media.padding.bottom + 16),
      color: _canvasColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mensagem de erro se houver
          ValueListenableBuilder<String?>(
            valueListenable: _audioService.error,
            builder: (context, error, _) => error == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      error,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                      ),
                    ),
                  ),
          ),

          // 1. Barra de Progress com tempo na ESQUERDA e na DIREITA
          ValueListenableBuilder<Duration>(
            valueListenable: _audioService.position,
            builder: (context, position, _) {
              return ValueListenableBuilder<Duration>(
                valueListenable: _audioService.duration,
                builder: (context, duration, _) {
                  final totalDuration = duration.inMilliseconds > 0
                      ? duration
                      : (_currentTrack.duration != null
                            ? Duration(
                                milliseconds: (_currentTrack.duration! * 1000)
                                    .round(),
                              )
                            : Duration.zero);
                  final total = totalDuration.inMilliseconds.toDouble();
                  final current = position.inMilliseconds.toDouble();
                  final value = total > 0
                      ? (current / total).clamp(0.0, 1.0)
                      : 0.0;

                  return Row(
                    children: [
                      // Tempo decorrido (lado esquerdo)
                      SizedBox(
                        width: 44,
                        child: Text(
                          _fmt(position),
                          style: TextStyle(
                            color: _secondaryInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Slider no centro (expandido)
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3.0,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14,
                            ),
                            activeTrackColor: _primaryInk,
                            inactiveTrackColor: _primaryInk.withValues(
                              alpha: 0.20,
                            ),
                            thumbColor: _primaryInk,
                            overlayColor: _primaryInk.withValues(alpha: 0.15),
                          ),
                          child: Slider(
                            value: value,
                            onChanged: (v) {
                              if (total > 0) {
                                final targetMs = (v * total).round();
                                if (_isYouTubeTrack && _ytController != null) {
                                  _ytController!.seekTo(
                                    seconds: targetMs / 1000,
                                    allowSeekAhead: true,
                                  );
                                  _audioService.position.value =
                                      Duration(milliseconds: targetMs);
                                } else {
                                  _audioService.seekTo(
                                    Duration(milliseconds: targetMs),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Tempo total / restante (lado direito)
                      SizedBox(
                        width: 44,
                        child: Text(
                          _fmt(totalDuration),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: _secondaryInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 6),

          // 2. Os 5 botões oficiais do Spotify
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Shuffle (Aleatório)
              _buildShuffleButton(),

              // 2. Voltar (Previous)
              IconButton(
                onPressed: _onPrevious,
                icon: const Icon(CupertinoIcons.backward_end_fill, size: 34),
                color: _primaryInk,
                tooltip: tr(context, "Back"),
              ),

              // 3. Play / Pause central
              _buildPlayPauseButton(),

              // 4. Pular (Next)
              IconButton(
                onPressed: _onNext,
                icon: const Icon(CupertinoIcons.forward_end_fill, size: 34),
                color: _primaryInk,
                tooltip: tr(context, "Skip"),
              ),

              // 5. Loop / Repetir
              _buildLoopButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShuffleButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _audioService.shuffleMode,
      builder: (context, isShuffle, _) {
        return IconButton(
          onPressed: () => _audioService.toggleShuffleMode(),
          icon: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.shuffle,
                size: 22,
                color: isShuffle
                    ? _spotifyGreen
                    : _secondaryInk.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: isShuffle ? _spotifyGreen : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          tooltip: isShuffle
              ? tr(context, "Shuffle: On")
              : tr(context, "Shuffle: Off"),
        );
      },
    );
  }

  Widget _buildLoopButton() {
    return ValueListenableBuilder<LoopMode>(
      valueListenable: _audioService.loopMode,
      builder: (context, loopMode, _) {
        final isActive = loopMode != LoopMode.off;
        final isOne = loopMode == LoopMode.one;
        return IconButton(
          onPressed: () => _audioService.toggleLoopMode(),
          icon: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOne ? CupertinoIcons.repeat_1 : CupertinoIcons.repeat,
                size: 22,
                color: isActive
                    ? _spotifyGreen
                    : _secondaryInk.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: isActive ? _spotifyGreen : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          tooltip: isOne
              ? tr(context, "Repeat: One track")
              : (isActive
                    ? tr(context, "Repeat: All")
                    : tr(context, "Repeat: Off")),
        );
      },
    );
  }

  Widget _buildPlayPauseButton() {
    return ValueListenableBuilder<PlayerState>(
      valueListenable: _audioService.playerState,
      builder: (context, state, _) {
        final playing = state.playing;
        final loading =
            state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;

        return GestureDetector(
          onTap: () async {
            if (_isYouTubeTrack && _ytController != null) {
              if (playing) {
                await _ytController!.pauseVideo();
                _audioService.playerState.value = PlayerState(
                  false,
                  ProcessingState.ready,
                );
              } else {
                await _ytController!.playVideo();
                _audioService.playerState.value = PlayerState(
                  true,
                  ProcessingState.ready,
                );
              }
            } else {
              _audioService.togglePlayPause(
                _currentTrack.previewAudioUrl ?? '',
                track: _currentTrack,
              );
            }
          },
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _primaryInk,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryInk.withValues(alpha: 0.20),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: loading
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _canvasColor,
                    ),
                  )
                : Icon(
                    playing
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    color: _canvasColor,
                    size: 34,
                  ),
          ),
        );
      },
    );
  }
}
