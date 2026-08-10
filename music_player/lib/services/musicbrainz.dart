import 'dart:convert';
import 'package:dio/dio.dart';
import '../utils/transliterate.dart';
import '../services/audiodb.dart';
import '../services/itunes.dart';
import '../services/deezer.dart';

class MusicBrainzService {
  static const String _baseUrl = 'https://musicbrainz.org/ws/2';
  static Dio? _dioInstance;
  static final Map<String, String> _artistNameCache = {};

  static Dio _getDioClient() {
    _dioInstance = null;
    _dioInstance ??= Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: null, //const Duration(seconds: 10),
        // Explicitly forces correct header setups natively
        headers: {
          'User-Agent': 'MusicApp/1.0 ( contact@example.com )',
          'Accept': 'application/json',
        },
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    return _dioInstance!;
  }

  //---------------Handle artist search-----------------------------------------

  static Future<List<Map<String, dynamic>>> searchArtists(String query) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final dio = _getDioClient();

        final response = await dio.get(
          '/artist',
          queryParameters: {'query': query, 'fmt': 'json', 'limit': 5},
        );

        if (response.statusCode == 503) {
          print('===MYLOG=== searchArtists 503, retry $attempt');
          await Future.delayed(Duration(seconds: attempt + 1));
          continue;
        }

        if (response.statusCode != 200 || response.data == null) return [];
        //print("===MYLOG=== $response.body");

        // Dio automatically decodes JSON string into Map/List structures
        final data = response.data is String
            ? jsonDecode(response.data)
            : response.data;
        final artists = List<Map<String, dynamic>>.from(data['artists'] ?? []);

        final filtered = artists.where((artist) {
          // Filter by type
          final type = artist['type'] as String? ?? '';
          if (type != 'Person' && type != 'Group') return false;

          // Filter by score
          final score = artist['score'] as int? ?? 0;
          if (score < 80) return false;

          // Filter by blacklist
          final name = (artist['name'] as String? ?? '').toLowerCase();
          final blacklist = ['tribute', 'choir', 'cover', 'parody', 'karaoke'];
          if (blacklist.any((word) => name.contains(word))) return false;

          return true;
        }).toList();

        final results = <Map<String, dynamic>>[];
        await Future.wait(
          filtered.map((artist) async {
            final artistId = artist['id'];
            String? type = artist['type'];
            var lifeSpan = artist['life-span'];
            var area = artist['area'];
            List<String> genres = [];

            try {
              final detailResponse = await dio.get(
                '/artist/$artistId',
                queryParameters: {'inc': 'tags', 'fmt': 'json'},
              );
              if (detailResponse.statusCode == 200) {
                final tags = List<Map<String, dynamic>>.from(
                  detailResponse.data['tags'] ?? [],
                );
                genres = tags.map((t) => t['name'] as String).toList();
              }
            } catch (e) {
              print('===MYLOG=== Failed to fetch tags for $artistId: $e');
            }

            results.add({
              'id': artistId,
              'name': artist['name'],
              'type': type,
              'lifeSpan': lifeSpan,
              'area': area,
              'tags': genres,
              'image': '',
              'source': 'musicbrainz',
            });
          }),
        );

        // ---- Pass 1: AudioDB (by MBID) ----
        final audioDBFutures = results.map((artist) {
          return AudioDBService.getArtistCover(artist['id'] as String);
        }).toList();

        final audioDBCovers = await rateLimitedParallelFetching(
          audioDBFutures,
          //delay: const Duration(milliseconds: 150),
        );

        final missingIndices = <int>[];
        for (int i = 0; i < results.length; i++) {
          final cover = audioDBCovers[i];
          if (cover != null && cover.isNotEmpty) {
            results[i]['image'] = cover;
          } else {
            missingIndices.add(i);
          }
        }

        // ---- Pass 2: iTunes for missing ones ----
        if (missingIndices.isNotEmpty) {
          final itunesFutures = missingIndices.map((i) {
            final artistName = results[i]['name'] as String;
            final country =
                (results[i]['area'] as Map?)?['name'] as String? ?? '';
            final mbid = results[i]['id'] as String; // <-- add
            return iTunesService.getArtistCover(
              artistName,
              country: country,
              mbid: mbid,
            );
          }).toList();

          final itunesCovers = await rateLimitedParallelFetching(
            itunesFutures,
            // delay: const Duration(milliseconds: 150),
          );

          final stillMissing = <int>[];
          for (int j = 0; j < missingIndices.length; j++) {
            final cover = itunesCovers[j];
            if (cover != null && cover.isNotEmpty) {
              results[missingIndices[j]]['image'] = cover;
            } else {
              stillMissing.add(missingIndices[j]);
            }
          }
          missingIndices.clear();
          missingIndices.addAll(stillMissing);
        }

        //---- Pass 3: Deezer for missing covers -------------------------------
        if (missingIndices.isNotEmpty) {
          final deezerFutures = missingIndices.map((i) {
            final artistName = results[i]['name'] as String;
            final country =
                (results[i]['area'] as Map?)?['name'] as String? ?? '';
            final mbid = results[i]['id'] as String; // <-- add
            return DeezerService.getArtistCover(
              transliterate(artistName),
              country: country,
              mbid: mbid,
            );
          }).toList();

          final deezerCovers = await rateLimitedParallelFetching(
            deezerFutures,
            //delay: const Duration(milliseconds: 150),
          );

          for (int k = 0; k < missingIndices.length; k++) {
            final cover = deezerCovers[k];
            if (cover != null && cover.isNotEmpty) {
              results[missingIndices[k]]['image'] = cover;
            }
          }
        }

        return results;
      } catch (e) {
        print('===MYLOG=== MusicBrainz searchArtists error: $e');
        if (attempt < 2) await Future.delayed(Duration(seconds: attempt + 1));
      }
    }
    return [];
  }

  //-----------Artist's album search, main logic--------------------------------

  static Future<String?> fetchAlbumCover(
    String albumId,
    String artistName,
    String albumTitle,
  ) async {
    // 1. AudioDB
    String? cover = await AudioDBService.getAlbumCover(albumId);
    if (cover == null || cover.isEmpty) {
      final releaseId = await getBestReleaseFromGroup(albumId);
      if (releaseId != null) {
        cover = await AudioDBService.getAlbumCover(releaseId);
      }
    }
    // 2. iTunes
    if (cover == null || cover.isEmpty) {
      cover = await iTunesService.getAlbumCover(artistName, albumTitle);
    }
    // 3. Deezer
    if (cover == null || cover.isEmpty) {
      final deezerAlbum = await DeezerService.findDeezerAlbum(
        transliterate(artistName),
        transliterate(albumTitle),
      );
      cover = deezerAlbum?['cover_medium'] as String?;
    }
    return cover ?? '';
  }

  static Future<List<Map<String, dynamic>>?> getArtistAlbums(
    String? mbid,
    String? artistName, {
    bool fetchCovers = true,
  }) async {
    //final mbid = await getArtistId(artistName);
    if (mbid == null) return [];

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final dio = _getDioClient();
        final response = await dio.get(
          '/release-group',
          queryParameters: {'artist': mbid, 'fmt': 'json', 'limit': '100'},
        );

        if (response.statusCode != 200) {
          print(
            "===MYLOG=== MusicBrainz attempt $attempt: ${response.statusCode}",
          );
          if (response.statusCode == 503) {
            await Future.delayed(Duration(seconds: (attempt + 1)));
            continue;
          }
          return [];
        }

        print(
          '===MYLOG=== getArtistAlbums response status: ${response.statusCode}',
        );

        final data = response.data;
        final releaseGroups = List<Map<String, dynamic>>.from(
          data['release-groups'] ?? [],
        );

        // Keep only primary-type Album with no unwanted secondary types
        final excluded = {
          'Compilation',
          'Live',
          'Remix',
          'Soundtrack',
          'Interview',
          'Demo',
          'EP',
        };
        final albumsOnly = releaseGroups.where((rg) {
          if (rg['primary-type'] != 'Album') return false;
          final secondary = List<String>.from(rg['secondary-types'] ?? []);
          return secondary.every((t) => !excluded.contains(t));
        }).toList();

        // Sort newest first
        albumsOnly.sort((a, b) {
          final da = a['first-release-date'] as String? ?? '';
          final db = b['first-release-date'] as String? ?? '';
          return da.compareTo(db);
        });

        // Deduplicate by BASE title only (strip version/edition suffixes for comparison)
        final seen = <String>{};
        final albums = <Map<String, dynamic>>[];
        for (final rg in albumsOnly) {
          final fullTitle = rg['title'] as String;
          // Strip only known suffix patterns for dedup key, keep full title for display
          var key = fullTitle.toLowerCase().trim();
          key = key.replaceAll(RegExp(r"\(taylor's version\)"), '').trim();
          key = key.replaceAll(RegExp(r'\(deluxe.*?\)'), '').trim();
          key = key.replaceAll(RegExp(r'\(platinum.*?\)'), '').trim();
          key = key.replaceAll(RegExp(r'\s+'), ' ').trim();

          if (!seen.add(key)) continue;

          albums.add({
            'id': rg['id'],
            'title': fullTitle,
            'date': rg['first-release-date'] ?? '',
            'primaryType': rg['primary-type'] ?? '',
            'secondaryTypes': rg['secondary-types'] ?? [],
            'disambiguation': rg['disambiguation'] ?? '',
            'coverArt': '',
            'source': 'musicbrainz',
          });
        }

        return albums;
      } catch (e) {
        print(
          '===MYLOG=== musicbrainz: getArtistAlbums: attemp $attempt, error: $e',
        );
        return [];
      }
    }
    // If all attempts fail or no value was returned, return empty list
    return [];
  }

  //-----------Search albums for search results---------------------------------

  static Future<List<Map<String, dynamic>>> searchAlbums(String query) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final dio = _getDioClient();
        final response = await dio.get(
          '/release-group',
          queryParameters: {
            'query': query,
            'fmt': 'json',
            'limit': 20,
            'type': 'album',
            'inc': 'tags', // we keep tags but don't use them
          },
        );

        if (response.statusCode == 503) {
          print("===MYLOG=== searchAlbums 503, retry $attempt");
          await Future.delayed(Duration(seconds: 1 * (attempt + 1)));
          continue;
        }

        if (response.statusCode != 200) return [];

        final data = response.data;
        final releaseGroups = List<Map<String, dynamic>>.from(
          data['release-groups'] ?? [],
        );

        final blacklist = ['anal', 'orgasm', 'tribute', 'karaoke'];
        final filtered = releaseGroups.where((rg) {
          final title = (rg['title'] as String? ?? '').toLowerCase();
          return !blacklist.any((word) => title.contains(word));
        }).toList();

        // Categorize correctly
        final Map<String, List<Map<String, dynamic>>> categorized = {};
        for (final rg in filtered) {
          final primaryType = rg['primary-type'] as String?;
          if (primaryType != 'Album') continue;

          final secondaryTypes = List<String>.from(rg['secondary-types'] ?? []);
          String category;
          if (secondaryTypes.contains('Compilation')) {
            category = 'Compilation';
          } else if (secondaryTypes.isNotEmpty) {
            category = secondaryTypes.first;
          } else {
            category = 'Studio';
          }

          categorized.putIfAbsent(category, () => []).add({
            'id': rg['id'],
            'title': rg['title'],
            'date': rg['first-release-date'] ?? '',
            'secondaryTypes': secondaryTypes,
            'primaryType': rg['primary-type'] ?? '',
            'disambiguation': rg['disambiguation'] ?? '',
            'tags': [],
          });
        }

        // Sort each category by date (newest first)
        for (final list in categorized.values) {
          list.sort((a, b) => b['date'].compareTo(a['date']));
        }

        // Build result: first take up to 2 compilations
        final result = <Map<String, dynamic>>[];
        final compAlbums = categorized['Compilation'] ?? [];
        result.addAll(compAlbums.take(2));

        // Then take up to 2 from each other category (excluding Compilation)
        for (final entry in categorized.entries) {
          if (entry.key == 'Compilation') continue;
          result.addAll(entry.value.take(2));
        }

        // ---- Pass: Deezer (by artist name + album title) ----
        final coverFutures = result.map((album) async {
          final rgId = album['id'] as String;
          final artistName = await getArtistNameFromReleaseGroup(rgId);
          if (artistName == null || artistName.isEmpty) return null;

          final deezerAlbum = await DeezerService.findDeezerAlbum(
            transliterate(artistName),
            album['title'] as String,
          );

          return deezerAlbum?['cover_medium'] as String?;
        }).toList();

        final covers = await rateLimitedParallelFetching(
          coverFutures,
          //delay: const Duration(milliseconds: 150),
        );

        for (int i = 0; i < result.length; i++) {
          final cover = covers[i];
          result[i]['coverArt'] = (cover != null && cover.isNotEmpty)
              ? cover
              : 'lib/graphics/no_thumbnail_found.jpg';
        }

        return result;
      } catch (e) {
        print("===MYLOG=== musicbrainz.dart: searchAlbums: $e");
        return [];
      }
    }
    return [];
  }

  //-----------Album tracks, main logic-----------------------------------------

  static Future<List<Map<String, dynamic>>> getAlbumTracks(
    String? releaseId,
  ) async {
    if (releaseId == null) return [];
    print('===MYLOG=== getAlbumTracks: releaseId=$releaseId');

    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        final dio = _getDioClient();
        final response = await dio.get(
          '/release/${Uri.encodeComponent(releaseId)}',
          queryParameters: {'inc': 'recordings', 'fmt': 'json'},
        );

        if (response.statusCode != 200) {
          print(
            "===MYLOG=== getAlbumTracks attempt $attempt: ${response.statusCode}",
          );
          if (response.statusCode == 503) {
            await Future.delayed(Duration(seconds: (attempt + 1)));
            continue;
          }
          return [];
        }

        final data = response.data;
        final tracks = <Map<String, dynamic>>[];

        for (final medium in data['media'] ?? []) {
          final discNumber = medium['position'] ?? 1;
          for (final track in medium['tracks'] ?? []) {
            tracks.add({
              'title': track['title'] ?? 'Unknown Track',
              'number': track['number'] ?? 0,
              'disc': discNumber,
              'length': track['length'] ?? 0,
              'id': track['id'] ?? '',
            });
          }
        }

        print('===MYLOG=== getAlbumTracks: found ${tracks.length} tracks');
        return tracks;
      } catch (e) {
        print("===MYLOG=== getAlbumTracks attempt $attempt, error: $e");
        if (attempt < 2) await Future.delayed(const Duration(seconds: 1));
      }
    }
    return [];
  }

  //============================================================================
  //Helper functions

  static Future<List<T>> rateLimitedParallelFetching<T>(
    List<Future<T>> futures, {
    int batchSize = 5,
    Duration delay = const Duration(milliseconds: 1100),
  }) async {
    final results = <T>[];

    for (var i = 0; i < futures.length; i += batchSize) {
      final batch = futures.skip(i).take(batchSize);
      final batchResults = await Future.wait(batch);

      results.addAll(batchResults);

      if (i + batchSize < futures.length) {
        await Future.delayed(delay);
      }
    }

    return results;
  }

  static Future<String?> getArtistNameFromReleaseGroup(String rgId) async {
    if (_artistNameCache.containsKey(rgId)) return _artistNameCache[rgId];

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final dio = _getDioClient();
        final response = await dio.get(
          '/release-group/$rgId',
          queryParameters: {'inc': 'artists', 'fmt': 'json'},
        );

        if (response.statusCode == 503) {
          print(
            "===MYLOG=== getArtistNameFromReleaseGroup 503, retry $attempt",
          );
          await Future.delayed(Duration(seconds: (attempt + 1)));
          continue;
        }

        if (response.statusCode != 200) return null;

        final data = response.data;
        final artistCredit = List<Map<String, dynamic>>.from(
          data['artist-credit'] ?? [],
        );
        if (artistCredit.isNotEmpty) {
          final name = artistCredit[0]['name'] as String?;
          if (name != null) _artistNameCache[rgId] = name;
          return name;
        }
      } catch (e) {
        print(
          "===MYLOG=== getArtistNameFromReleaseGroup attempt $attempt error: $e",
        );
        if (attempt < 2) await Future.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  /// Given a release-group ID, get the best release ID to use for track listing.
  static Future<String?> getBestReleaseFromGroup(String releaseGroupId) async {
    try {
      final dio = _getDioClient();
      final response = await dio.get(
        '/release',
        queryParameters: {
          'release-group': releaseGroupId,
          'fmt': 'json',
          'limit': '10',
        },
      );

      if (response.statusCode != 200) return null;

      final releases = List<Map<String, dynamic>>.from(
        response.data['releases'] ?? [],
      );
      if (releases.isEmpty) return null;
      // Prefer official releases
      final official = releases
          .where(
            (r) => (r['status'] as String? ?? '').toLowerCase() == 'official',
          )
          .toList();

      final best = official.isNotEmpty ? official.first : releases.first;
      return best['id'] as String?;
    } catch (e) {
      print('===MYLOG=== getBestReleaseFromGroup error: $e');
      return null;
    }
  }
}
