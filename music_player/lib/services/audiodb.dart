import 'package:dio/dio.dart';
//import '../utils/translate.dart';

class AudioDBService {
  static const String _baseUrl = 'https://www.theaudiodb.com/api/v1/json/123';
  static final Map<String, String> _cache = {};
  static final Dio _dio = Dio();

  static Future<String?> getArtistCover(String? mbID) async {
    if (mbID == null) return null;

    final cacheKey = 'artist-$mbID';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final encodedId = Uri.encodeComponent(mbID);
      final response = await _dio.get(
        '$_baseUrl/artist-mb.php',
        queryParameters: {'i': encodedId},
      );

      if (response.statusCode != 200) return null;

      final data = response.data;
      final url =
          (data['artists'] as List?)?.firstOrNull?['strArtistThumb'] as String?;
      if (url != null) _cache[cacheKey] = url;
      print('===MYLOG=== audioDb, artist cover url: $url');
      return url;
    } catch (e) {
      print('===MYLOG=== audioDB, artist cover: error: $e');
      return null;
    }
  }

  static Future<String?> getAlbumCover(String? mbID) async {
    if (mbID == null) return null;

    final cacheKey = 'album-$mbID';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final encodedId = Uri.encodeComponent(mbID);
      final response = await _dio.get(
        '$_baseUrl/album-mb.php',
        queryParameters: {'i': encodedId},
      );

      if (response.statusCode != 200) return null;

      final data = response.data;
      final url =
          (data['album'] as List?)?.firstOrNull?['strAlbumThumb'] as String?;
      if (url != null) _cache[cacheKey] = url;
      return url;
    } catch (e) {
      print('===MYLOG=== audioDB, album cover: error: $e');
      return null;
    }
  }
}
