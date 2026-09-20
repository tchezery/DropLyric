import 'package:droplyric/src/core/services/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('YouTubeService cleanTitleAndArtist cleans junk suffixes and handles dashes', () {
    final (title, artist) = YouTubeService.cleanTitleAndArtist(
      'Coldplay - Yellow (Official Video)',
      'Coldplay',
    );
    expect(title, 'Yellow');
    expect(artist, 'Coldplay');

    final (title2, artist2) = YouTubeService.cleanTitleAndArtist(
      'Adele – Easy On Me [Lyrics]',
      'Adele - Topic',
    );
    expect(title2, 'Easy On Me');
    expect(artist2, 'Adele');
  });

  test('YouTubeService extractVideoId extracts ID correctly', () {
    expect(
      YouTubeService.extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
    expect(
      YouTubeService.extractVideoId('https://youtu.be/dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
    expect(
      YouTubeService.extractVideoId('youtube:dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
  });
}
