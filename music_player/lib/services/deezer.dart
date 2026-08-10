import 'package:dio/dio.dart';
import '../utils/youtube_cleaner.dart';
import '../services/musicbrainz.dart';

class DeezerService {
  static const String _baseUrl = 'https://api.deezer.com';
  static Map<String, int> deezerIds = {};
  static Map<String, Map<String, String>> deezerMeta = {};

  static Dio? _dioInstance;

  static Dio _getDioClient() {
    _dioInstance ??= Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: null,
        headers: {'User-Agent': 'MusicApp/1.0', 'Accept': 'application/json'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    return _dioInstance!;
  }

  static void refresh() {
    deezerIds.clear();
    deezerMeta.clear();
  }

  //--------------------Track searching and loading for queue-----------------------------

  static Future<Map<String, dynamic>?> searchTrack(
    String title,
    String artist,
  ) async {
    // Use YouTubeCleaner to extract candidates from the raw YT title/author
    final candidates = YouTubeCleaner.parseCandidates(title, artist);

    // Build a deduplicated list of (cleanedTitle, cleanedArtist) queries to try
    final queries = <(String, String)>[];
    for (final c in candidates) {
      queries.add((c.$2.trim(), c.$1.trim())); // (title, artist)
    }
    // Always also try raw cleaned title + raw author as a fallback
    String cleanedTitle = YouTubeCleaner.cleanTitle(title);
    if (cleanedTitle.length > 30) cleanedTitle = cleanedTitle.substring(0, 30);
    queries.add((cleanedTitle, artist));

    print(
      '===MYLOG=== DeezerService.searchTrack candidates: ${queries.length} for "$title" / "$artist"',
    );

    final dio = _getDioClient();
    final tried = <String>{};

    for (final q in queries) {
      final queryStr = '${q.$1} ${q.$2}'.trim();
      if (queryStr.isEmpty || !tried.add(queryStr.toLowerCase())) continue;

      try {
        final response = await dio.get(
          '/search',
          queryParameters: {'q': queryStr},
        );
        if (response.statusCode == 200) {
          final data = response.data;
          final results = data['data'] as List? ?? [];
          if (results.isNotEmpty) {
            print(
              '===MYLOG=== Deezer found via "$queryStr": ${results[0]['title']} by ${results[0]['artist']['name']}',
            );
            return Map<String, dynamic>.from(results[0] as Map);
          }
        }
      } catch (e) {
        print('===MYLOG=== Deezer searchTrack error for "$queryStr": $e');
      }
    }

    print(
      '===MYLOG=== Deezer searchTrack: no match found for "$title" / "$artist"',
    );
    return null;
  }

  //------------------For track results in search screen------------------------

  static Future<Map<String, dynamic>> searchTracks(String query) async {
    final encoded = Uri.encodeQueryComponent(query);
    try {
      final dio = _getDioClient();
      final response = await dio.get(
        '/search/track',
        queryParameters: {'q': encoded, 'limit': 20},
      );

      final trackData = response.statusCode == 200 ? response.data : {};
      final rawTracks = List.from(trackData['data'] ?? []);
      final tracks = rawTracks
          .map((t) => Map<String, dynamic>.from(t as Map))
          .toList();

      return {'tracks': tracks, 'nextTrackUrl': trackData['next']};
    } catch (e) {
      print('===MYLOG=== searchTracks error: $e');
      return {'tracks': [], 'nextTrackUrl': null};
    }
  }

  static Future<Map<String, dynamic>> searchAllTracks(String query) async {
    final encoded = Uri.encodeQueryComponent(query);
    try {
      final dio = _getDioClient();
      final response = await dio.get(
        '/search/track',
        queryParameters: {'q': encoded, 'limit': 20},
      );

      if (response.statusCode != 200) {
        return {'tracks': [], 'nextTrackUrl': null};
      }

      final data = response.data;
      return {
        'tracks': List<Map<String, dynamic>>.from(data['data'] ?? []),
        'nextTrackUrl': data['next'],
      };
    } catch (e) {
      print('===MYLOG=== searchAllTracks error: $e');
      return {'tracks': [], 'nextTrackUrl': null};
    }
  }

  static Future<Map<String, dynamic>> loadMoreTracks(String nextUrl) async {
    try {
      final dio = _getDioClient();
      final response = await dio.get(nextUrl);

      if (response.statusCode != 200) {
        return {'tracks': [], 'nextTrackUrl': null};
      }

      final data = response.data;
      return {
        'tracks': List<Map<String, dynamic>>.from(data['data'] ?? []),
        'nextTrackUrl': data['next'],
      };
    } catch (e) {
      print('===MYLOG=== loadMoreTracks error: $e');
      return {'tracks': [], 'nextTrackUrl': null};
    }
  }

  //---------------Top tracks handling------------------------------------------

  static Future<List<Map<String, dynamic>>> getDeezerTopTracks(
    String artistName, {
    String? country,
    String? mbArtistId,
  }) async {
    print('===MYLOG=== getDeezerTopTracks called for "$artistName"');
    final artistId = await resolveDeezerArtistId(
      artistName: artistName,
      country: country,
      mbArtistId: mbArtistId,
    );
    if (artistId != null) {
      return getArtistTopTracks(artistId, limit: 7);
    }
    print('===MYLOG=== getDeezerTopTracks: artistId is null');
    return [];
  }

  static Future<List<Map<String, dynamic>>> getArtistTopTracks(
    int artistId, {
    int limit = 10,
  }) async {
    try {
      final dio = _getDioClient();
      final response = await dio.get(
        '/artist/$artistId/top',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode != 200) return [];

      final data = response.data;
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      print('===MYLOG=== getArtistTopTracks ERROR: $e');
      return [];
    }
  }

  //--------------related artists-----------------------------------------------

  static Future<List<Map<String, dynamic>>> getRelatedArtists(
    int artistId,
  ) async {
    try {
      final dio = _getDioClient();
      final response = await dio.get('/artist/$artistId/related');

      if (response.statusCode != 200) return [];

      final data = response.data;
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      print('===MYLOG=== getRelatedArtists error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getRelatedArtistsTracks(
    int seedArtistId, {
    int artistLimit = 5,
    int tracksPerArtist = 5,
  }) async {
    final related = await getRelatedArtists(seedArtistId);
    if (related.isEmpty) return [];
    final picked = related.take(artistLimit).toList();
    final results = await Future.wait(
      picked.map((a) => getArtistTopTracks(a['id'], limit: tracksPerArtist)),
    );
    final seen = <int>{};
    final tracks = <Map<String, dynamic>>[];
    for (final batch in results) {
      for (final t in batch) {
        final id = t['id'] as int?;
        if (id != null && seen.add(id)) tracks.add(t);
      }
    }
    return tracks;
  }

  //============================================================================

  static Future<int?> resolveDeezerArtistId({
    required String artistName,
    String? country,
    required String? mbArtistId,
  }) async {
    if (mbArtistId == null || mbArtistId.isEmpty) {
      // Fallback to old method
      return artistNameToIdAndResults(artistName, country: country);
    }

    // 1. Get MusicBrainz album titles (fast, no covers)
    final mbAlbums = await MusicBrainzService.getArtistAlbums(
      mbArtistId,
      artistName,
      fetchCovers: false,
    );
    if (mbAlbums == null || mbAlbums.isEmpty) {
      // If no albums, fallback to old method
      return artistNameToIdAndResults(artistName, country: country);
    }
    final mbTitles = mbAlbums
        .map((a) => (a['title'] as String).toLowerCase().trim())
        .toSet();

    // 2. Search Deezer for artists with this name
    final dio = _getDioClient();
    final response = await dio.get(
      '/search/artist',
      queryParameters: {'q': artistName, 'limit': 10},
    );

    if (response.statusCode != 200) return null;
    final candidates = response.data['data'] as List? ?? [];
    if (candidates.isEmpty) return null;

    // If only one candidate, return it immediately
    if (candidates.length == 1) {
      return candidates.first['id'] as int;
    }

    // 3. For each candidate, fetch up to 10 albums and compare titles
    int bestScore = -1;
    int? bestId;
    for (final c in candidates) {
      final cId = c['id'] as int;
      final cCountry = (c['country'] as String? ?? '').toLowerCase().trim();

      // Score: album overlap + country bonus
      int score = 0;
      try {
        final albumResponse = await dio.get(
          '/artist/$cId/albums',
          queryParameters: {'limit': 10},
        );

        if (albumResponse.statusCode == 200) {
          final albums = albumResponse.data['data'] as List? ?? [];
          final deezerTitles = albums
              .map((a) => (a['title'] as String).toLowerCase().trim())
              .toSet();
          // Count overlapping titles
          for (final title in mbTitles) {
            if (deezerTitles.contains(title)) {
              score++;
            }
          }
        }
      } catch (_) {}

      // Country bonus: exact match
      if (country != null &&
          country.isNotEmpty &&
          cCountry == country.toLowerCase().trim()) {
        score += 10;
      }

      if (score > bestScore) {
        bestScore = score;
        bestId = cId;
      }
    }

    print(
      '===MYLOG=== resolveDeezerArtistId: bestScore: $bestScore, bestId: $bestId',
    );
    return bestId;
  }

  static Future<int?> artistNameToIdAndResults(
    String artistName, {
    String? country,
  }) async {
    try {
      final dio = _getDioClient();
      final response = await dio.get(
        '/search/artist',
        queryParameters: {'q': artistName, 'limit': 10},
      );
      if (response.statusCode == 200) {
        final artists = List.from(response.data['data'] ?? []);
        if (artists.isEmpty) return null;

        final nameLower = artistName.toLowerCase().trim();
        final countryLower = country?.toLowerCase().trim();

        // Try exact name match with country match (if provided)
        if (countryLower != null && countryLower.isNotEmpty) {
          for (final a in artists) {
            final aName = (a['name'] as String).toLowerCase().trim();
            final aCountry = (a['country'] as String? ?? '')
                .toLowerCase()
                .trim();
            if (aName == nameLower && aCountry == countryLower) {
              return a['id'] as int;
            }
          }
        }

        // Fallback: exact name match (ignore country)
        for (final a in artists) {
          if ((a['name'] as String).toLowerCase().trim() == nameLower) {
            return a['id'] as int;
          }
        }

        // Last resort: first result
        print(
          '===MYLOG=== No exact match, using first result: ${artists[0]['name']} id=${artists[0]['id']}',
        );
        return artists[0]['id'] as int;
      }
    } catch (e) {
      print('===MYLOG=== artist search error: $e');
    }
    return null;
  }

  static Future<String?> getArtistCover(
    String artistName, {
    String? country,
    String? mbid, // new
  }) async {
    // If we have an MBID, use the resolver to get the correct artist ID
    if (mbid != null && mbid.isNotEmpty) {
      final resolvedId = await resolveDeezerArtistId(
        artistName: artistName,
        country: country,
        mbArtistId: mbid,
      );
      if (resolvedId != null) {
        final dio = _getDioClient();
        final response = await dio.get('/artist/$resolvedId');
        if (response.statusCode == 200) {
          return response.data['picture_medium'] as String?;
        }
      }
      // If resolver fails, fall through to the original search
    }

    // Fallback: original search (without mbid)
    try {
      final dio = _getDioClient();
      final response = await dio.get(
        '/search/artist',
        queryParameters: {'q': artistName, 'limit': 5},
      );
      if (response.statusCode != 200) return null;
      final artists = response.data['data'] as List?;
      if (artists == null || artists.isEmpty) return null;

      final nameLower = artistName.toLowerCase().trim();
      final countryLower = country?.toLowerCase().trim();

      if (countryLower != null && countryLower.isNotEmpty) {
        for (final a in artists) {
          final aName = (a['name'] as String).toLowerCase().trim();
          final aCountry = (a['country'] as String? ?? '').toLowerCase().trim();
          if (aName == nameLower && aCountry == countryLower) {
            return a['picture_medium'] as String?;
          }
        }
      }
      for (final a in artists) {
        if ((a['name'] as String).toLowerCase().trim() == nameLower) {
          return a['picture_medium'] as String?;
        }
      }
      return null;
    } catch (e) {
      print('===MYLOG=== getArtistCover error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> findDeezerAlbum(
    String artistName,
    String albumTitle,
  ) async {
    try {
      final dio = _getDioClient();
      final response = await dio.get(
        '/search/album',
        queryParameters: {'q': '$artistName $albumTitle'},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final albums = List.from(data['data'] ?? []);
        if (albums.isNotEmpty) {
          return Map<String, dynamic>.from(albums[0] ?? {});
        }
      }

      return null;
    } catch (e) {
      print('_findDeezerAlbum error: $e');
      return null;
    }
  }
}
