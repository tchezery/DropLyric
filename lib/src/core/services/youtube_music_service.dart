import 'package:url_launcher/url_launcher.dart';

import '../models/track_model.dart';

class YouTubeMusicService {
  static Future<bool> openTrack(TrackModel track) async {
    final query = Uri.encodeComponent('${track.title} ${track.artist}');
    final appUrl = Uri.parse('youtubemusic://search?q=$query');
    final webUrl = Uri.parse('https://music.youtube.com/search?q=$query');

    if (await launchUrl(appUrl, mode: LaunchMode.externalApplication)) {
      return true;
    }
    return launchUrl(webUrl, mode: LaunchMode.externalApplication);
  }
}
