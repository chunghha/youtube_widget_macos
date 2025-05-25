// lib/utils/youtube_url_parser.dart
class YouTubeUrlParser {
  static String? extractVideoId(String url) {
    RegExp regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:embed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    );
    Match? match = regExp.firstMatch(url);
    return match?.group(1);
  }
}
