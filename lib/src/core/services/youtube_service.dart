import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/track_model.dart';

class YouTubeService {
  static final YouTubeService instance = YouTubeService._();
  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, _CachedStream> _streamCache = {};

  YouTubeService._();

  static String? extractVideoId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('youtube:')) {
      return trimmed.replaceFirst('youtube:', '').trim();
    }

    try {
      final videoId = VideoId(trimmed);
      return videoId.value;
    } catch (_) {
      final regExp = RegExp(
        r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/|music\.youtube\.com\/watch\?v=))([\w-]{11})',
        caseSensitive: false,
      );
      final match = regExp.firstMatch(trimmed);
      return match?.group(1);
    }
  }

  static (String title, String artist) cleanTitleAndArtist(
    String rawTitle,
    String channelTitle,
  ) {
    var title = rawTitle.trim();
    var artist = channelTitle
        .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*Official\s*(Channel|Page)?$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*VEVO$', caseSensitive: false), '')
        .trim();

    // Clean common YouTube junk tags in parentheses or brackets
    final junkTags = RegExp(
      r'[\(\[\{][^\)\]\}]*(official|video|audio|lyrics?|visualizer|clip|remaster|live|performance|explicit|4k|hd|hq|letra|clipe|faixa)[^\)\]\}]*[\)\]\}]',
      caseSensitive: false,
    );
    title = title.replaceAll(junkTags, '').trim();

    // Remove any trailing "| ..." (e.g. "Song Name | Live in London")
    if (title.contains('|')) {
      title = title.split('|')[0].trim();
    }

    // Handle dashes: standard "-", en-dash "–", em-dash "—"
    final dashRegExp = RegExp(r'\s+[-–—]\s+');
    if (dashRegExp.hasMatch(title)) {
      final parts = title.split(dashRegExp);
      if (parts.length >= 2) {
        final possibleArtist = parts[0].trim();
        final possibleTitle = parts.sublist(1).join(' - ').trim();
        if (possibleArtist.isNotEmpty && possibleTitle.isNotEmpty) {
          artist = possibleArtist;
          title = possibleTitle;
        }
      }
    }

    // Strip remaining dangling brackets/parentheses and quotes
    title = title
        .replaceAll(RegExp(r'^["\x27\s]+|["\x27\s]+$'), '')
        .replaceAll(RegExp(r'\s*[\(\[\{]\s*[\)\]\}]$'), '')
        .trim();
    artist = artist
        .replaceAll(RegExp(r'^["\x27\s]+|["\x27\s]+$'), '')
        .replaceAll(RegExp(r'\s*[\(\[\{]\s*[\)\]\}]$'), '')
        .trim();

    return (title.isNotEmpty ? title : rawTitle, artist.isNotEmpty ? artist : channelTitle);
  }

  Future<List<TrackModel>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      // Check if the query is a direct video ID or YouTube URL
      final directId = extractVideoId(cleanQuery);
      if (directId != null && directId.length == 11) {
        final video = await _yt.videos.get(directId);
        final (title, artist) = cleanTitleAndArtist(video.title, video.author);
        return [
          TrackModel(
            id: 'youtube:${video.id.value}',
            title: title,
            artist: artist,
            album: '',
            albumArtUrl: video.thumbnails.highResUrl,
            previewAudioUrl: 'youtube:${video.id.value}',
            spotifyUrl: 'https://youtube.com/watch?v=${video.id.value}',
            duration: video.duration?.inMilliseconds != null
                ? video.duration!.inMilliseconds / 1000
                : null,
          ),
        ];
      }

      final searchResults = await _yt.search.search(cleanQuery);
      final tracks = <TrackModel>[];

      for (final item in searchResults.take(25)) {
        final (title, artist) = cleanTitleAndArtist(item.title, item.author);
        tracks.add(
          TrackModel(
            id: 'youtube:${item.id.value}',
            title: title,
            artist: artist,
            album: '',
            albumArtUrl: item.thumbnails.highResUrl,
            previewAudioUrl: 'youtube:${item.id.value}',
            spotifyUrl: 'https://youtube.com/watch?v=${item.id.value}',
            duration: item.duration?.inMilliseconds != null
                ? item.duration!.inMilliseconds / 1000
                : null,
          ),
        );
      }

      return tracks;
    } catch (e) {
      debugPrint('YouTubeService search error: $e');
      return [];
    }
  }

  Future<String?> resolveAudioStreamUrl(String videoIdOrUrl) async {
    final videoIdStr = extractVideoId(videoIdOrUrl) ?? videoIdOrUrl;
    if (videoIdStr.isEmpty) return null;

    final cached = _streamCache[videoIdStr];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    try {
      final videoId = VideoId(videoIdStr);
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly;
      
      StreamInfo? selectedStream;

      if (audioStreams.isNotEmpty) {
        final mp4Audio = audioStreams.where(
          (s) =>
              s.container.name.toLowerCase() == 'mp4' ||
              s.codec.mimeType.contains('mp4') ||
              s.codec.mimeType.contains('m4a') ||
              s.audioCodec.toLowerCase().contains('mp4a') ||
              s.audioCodec.toLowerCase().contains('aac'),
        );
        if (mp4Audio.isNotEmpty) {
          selectedStream = mp4Audio.withHighestBitrate();
        }
      }

      // If no audio-only MP4/AAC stream was found, check for muxed MP4
      if (selectedStream == null && manifest.muxed.isNotEmpty) {
        final mp4Muxed = manifest.muxed.where(
          (s) => s.container.name.toLowerCase() == 'mp4',
        );
        if (mp4Muxed.isNotEmpty) {
          selectedStream = mp4Muxed.withHighestBitrate();
        }
      }

      // If still null, fallback to highest bitrate audio stream
      if (selectedStream == null && audioStreams.isNotEmpty) {
        selectedStream = audioStreams.withHighestBitrate();
      }

      // Last resort fallback to any muxed stream
      if (selectedStream == null && manifest.muxed.isNotEmpty) {
        selectedStream = manifest.muxed.withHighestBitrate();
      }

      if (selectedStream == null) return null;

      final url = selectedStream.url.toString();

      _streamCache[videoIdStr] = _CachedStream(
        url: url,
        expiresAt: DateTime.now().add(const Duration(minutes: 45)),
      );

      return url;
    } catch (e) {
      debugPrint('YouTubeService resolveAudioStreamUrl error for $videoIdStr: $e');
      return null;
    }
  }

  Future<File?> getOrDownloadAudioFile(String videoIdOrUrl) async {
    final videoIdStr = extractVideoId(videoIdOrUrl) ?? videoIdOrUrl;
    if (videoIdStr.isEmpty) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/droplyric_audio');
      if (!cacheDir.existsSync()) {
        await cacheDir.create(recursive: true);
      }
      final targetFile = File('${cacheDir.path}/$videoIdStr.m4a');
      if (targetFile.existsSync() && targetFile.lengthSync() > 100000) {
        return targetFile;
      }

      final videoId = VideoId(videoIdStr);
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly;

      StreamInfo? selectedStream;

      if (audioStreams.isNotEmpty) {
        final mp4Audio = audioStreams.where(
          (s) =>
              s.container.name.toLowerCase() == 'mp4' ||
              s.codec.mimeType.contains('mp4') ||
              s.codec.mimeType.contains('m4a') ||
              s.audioCodec.toLowerCase().contains('mp4a') ||
              s.audioCodec.toLowerCase().contains('aac'),
        );
        if (mp4Audio.isNotEmpty) {
          selectedStream = mp4Audio.withHighestBitrate();
        }
      }

      if (selectedStream == null && manifest.muxed.isNotEmpty) {
        final mp4Muxed = manifest.muxed.where(
          (s) => s.container.name.toLowerCase() == 'mp4',
        );
        if (mp4Muxed.isNotEmpty) {
          selectedStream = mp4Muxed.withHighestBitrate();
        }
      }

      if (selectedStream == null && audioStreams.isNotEmpty) {
        selectedStream = audioStreams.withHighestBitrate();
      }

      if (selectedStream == null && manifest.muxed.isNotEmpty) {
        selectedStream = manifest.muxed.withHighestBitrate();
      }

      if (selectedStream == null) return null;

      final partFile = File('${cacheDir.path}/$videoIdStr.part');
      if (partFile.existsSync()) {
        await partFile.delete();
      }

      final output = partFile.openWrite();
      final stream = _yt.videos.streamsClient.get(selectedStream);
      await stream.pipe(output);
      await output.flush();
      await output.close();

      if (await partFile.length() > 50000) {
        if (targetFile.existsSync()) {
          await targetFile.delete();
        }
        await partFile.rename(targetFile.path);
        return targetFile;
      }
      return null;
    } catch (e) {
      debugPrint('YouTubeService getOrDownloadAudioFile error for $videoIdStr: $e');
      return null;
    }
  }

  void dispose() {
    _yt.close();
  }
}

class _CachedStream {
  final String url;
  final DateTime expiresAt;

  _CachedStream({required this.url, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
