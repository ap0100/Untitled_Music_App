import 'package:dio/dio.dart';
import '../utils/transliterate.dart';
import 'dart:convert';

class iTunesService {
  static final Dio dio = Dio();
  static final Map<String, String> _cache = {};

  static Future<String?> getArtistCover(
    String artist, {
    String? country,
    String? mbid,
  }) async {
    final cacheKey =
        'artistcover:$artist${country != null ? '-$country' : ''}${mbid != null ? '-$mbid' : ''}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      // Build query with artist + country (if any)
      String query = transliterate(artist);
      if (country != null && country.isNotEmpty) {
        query += ' $country';
      }
      final encoded = Uri.encodeComponent(query);
      final url =
          'https://itunes.apple.com/search?term=$encoded&entity=musicArtist&limit=5';
      print('===MYLOG=== iTunes artist cover URL: $url');
      final response = await dio.get(url);
      print('===MYLOG=== iTunes artist cover status: ${response.statusCode}');

      // Ensure response is a Map
      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (e) {
          print('===MYLOG=== iTunes artist cover: failed to decode JSON: $e');
          return null;
        }
      }
      if (data is! Map) {
        print(
          '===MYLOG=== iTunes artist cover: unexpected data type: ${data.runtimeType}',
        );
        return null;
      }

      final results = data['results'] as List?;
      if (results == null || results.isEmpty) {
        print('===MYLOG=== iTunes artist cover: no results for "$artist"');
        return null;
      }

      // Iterate over results (each is a Map)
      for (final r in results) {
        if (r is! Map) continue;
        final artistName = (r['artistName'] as String?)?.toLowerCase().trim();
        if (artistName == artist.toLowerCase().trim()) {
          final url = r['artworkUrl100'] as String?;
          if (url != null && url.isNotEmpty) {
            _cache[cacheKey] = url;
            print('===MYLOG=== iTunes artist cover found: $url');
            return url;
          }
        }
      }
      return null;
    } catch (e, stack) {
      print('===MYLOG=== iTunes artist cover error: $e\n$stack');
      return null;
    }
  }

  static Future<String?> getAlbumCover(String artist, String album) async {
    final cacheKey = 'albumcover:$artist-$album';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final query = Uri.encodeComponent(
        '${transliterate(artist)} ${transliterate(album)}',
      );
      final baseurl =
          'https://itunes.apple.com/search?term=$query&entity=album&limit=1';
      print('===MYLOG=== iTunes album cover URL: $baseurl');
      final response = await dio.get(baseurl);
      print('===MYLOG=== iTunes album cover status: ${response.statusCode}');

      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (e) {
          print('===MYLOG=== iTunes album cover: failed to decode JSON: $e');
          return null;
        }
      }
      if (data is! Map) {
        print(
          '===MYLOG=== iTunes album cover: unexpected data type: ${data.runtimeType}',
        );
        return null;
      }

      final results = data['results'] as List?;
      if (results == null || results.isEmpty) {
        print(
          '===MYLOG=== iTunes album cover: no results for "$artist - $album"',
        );
        return null;
      }

      final firstResult = results.first as Map?;
      if (firstResult == null) return null;

      final url = firstResult['artworkUrl100'] as String?;
      if (url != null && url.isNotEmpty) {
        _cache[cacheKey] = url;
        print('===MYLOG=== iTunes album cover found: $url');
        return url;
      }
      return null;
    } catch (e, stack) {
      print('===MYLOG=== iTunes album cover error: $e\n$stack');
      return null;
    }
  }
}
