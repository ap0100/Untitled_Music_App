import 'package:music_player/services/musicbrainz.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/material.dart';
import '../services/deezer.dart';
import '../services/queue_manager.dart';
import '../utils/youtube_cleaner.dart';

enum SearchResultType { artist, album, track }

class SearchResultItem {
  final SearchResultType type;
  final Map<String, dynamic> data;
  Video? video; // null until tapped, then cached

  SearchResultItem({required this.type, required this.data, this.video});
}

class SearchService extends ChangeNotifier {
  final YoutubeExplode _yt = YoutubeExplode();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasSearched = false;
  String? _nextTrackUrl;
  String _lastQuery = '';

  bool _isBuildingQueue = false;
  bool get isBuildingQueue => _isBuildingQueue;

  // Two separate IDs so queue generation and search never cancel each other
  // ignore: unused_field
  int _searchId = 0;
  int _queueId = 0;

  List<SearchResultItem> _searchResults = [];
  List<SearchResultItem> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get hasSearched => _hasSearched;

  // ── YouTube ─────────────────────────────────────────────────────────────────

  Future<Video?> _ytSearch(String title, String artist) async {
    // Clean the Deezer title for display (removes feat., remaster notes etc.)
    final cleanTitle = YouTubeCleaner.cleanTitle(title);
    final queries = <String>[
      '$cleanTitle $artist', // primary: clean title + artist
      '$artist $cleanTitle', // swapped
      '$title $artist', // raw title + artist (fallback)
      cleanTitle, // title only (last resort)
    ];
    final tried = <String>{};
    for (final q in queries) {
      final trimmed = q.trim();
      if (trimmed.isEmpty || !tried.add(trimmed.toLowerCase())) continue;
      try {
        final results = await _yt.search.search(trimmed);
        if (results.isNotEmpty) return results.first;
      } catch (_) {}
    }
    return null;
  }

  /// Public: search YouTube and return the top results as a list of Videos.
  Future<List<Video>> searchYouTube(String query) async {
    try {
      final results = await _yt.search.search(query);
      return results.toList();
    } catch (_) {
      return [];
    }
  }

  // ── Queue generation ────────────────────────────────────────────────────────

  void buildQueueInBackground(Video currentVideo) {
    _isBuildingQueue = true;
    notifyListeners();
    final int myId = ++_queueId;
    if (!QueueManager().playingFromQueue) {
      QueueManager().updateQueue([currentVideo]);
    }
    _buildProgressively(currentVideo, myId);
  }

  Future<void> _buildProgressively(Video currentVideo, int myId) async {
    try {
      final track = await DeezerService.searchTrack(
        currentVideo.title,
        currentVideo.author,
      );
      if (track == null || _queueId != myId) return;

      DeezerService.deezerIds.putIfAbsent(
        currentVideo.id.value,
        () => track['id'],
      );
      DeezerService.deezerMeta.putIfAbsent(
        currentVideo.id.value,
        () => {
          'title': track['title'] as String? ?? currentVideo.title,
          'artist': track['artist']?['name'] as String? ?? currentVideo.author,
        },
      );

      print('===MYLOG=== Building queue');
      final artistId = track['artist']['id'] as int;
      final bool extending = QueueManager().playingFromQueue;

      final fetchResults = await Future.wait([
        DeezerService.getArtistTopTracks(artistId, limit: extending ? 7 : 20),
        DeezerService.getRelatedArtistsTracks(
          artistId,
          artistLimit: extending ? 6 : 13,
          tracksPerArtist: extending ? 4 : 8,
        ),
      ]);
      if (_queueId != myId) return;

      final seenDeezerIds = <int>{};
      final recommended = <Map<String, dynamic>>[];
      for (final t in [...fetchResults[0], ...fetchResults[1]]) {
        final id = t['id'] as int?;
        if (id != null && seenDeezerIds.add(id)) recommended.add(t);
      }
      if (recommended.isEmpty || _queueId != myId) return;

      // Seed dedup set from existing queue
      final seenVideoIds = QueueManager().queueNotifier.value
          .map((v) => v.id.value)
          .toSet();

      int next = 0;
      Future<void> worker() async {
        while (true) {
          if (_queueId != myId) return;
          final i = next++;
          if (i >= recommended.length) return;

          final t = recommended[i];
          final deezerTitle = t['title'] as String? ?? '';
          final deezerArtist = t['artist']?['name'] as String? ?? '';
          final video = await _ytSearch(deezerTitle, deezerArtist);
          if (_queueId != myId) return;
          if (video == null) continue;

          // Deduplicate only by video ID – title dedup removed to get more tracks
          if (!seenVideoIds.add(video.id.value)) continue;

          QueueManager().addToQueue(video);
          DeezerService.deezerIds[video.id.value] = t['id'];
          DeezerService.deezerMeta[video.id.value] = {
            'title': deezerTitle,
            'artist': deezerArtist,
          };
          notifyListeners();
          print(
            '===MYLOG=== Queue +1 → ${QueueManager().queueNotifier.value.length} "$deezerTitle"',
          );
        }
      }

      // 8 workers, each fetching up to the end of the list
      await Future.wait(List.generate(8, (_) => worker()));
    } catch (e, stack) {
      print('===MYLOG=== _buildProgressively ERROR: $e\n$stack');
    } finally {
      _isBuildingQueue = false;
      notifyListeners();
    }
  }

  // ── Search ──────────────────────────────────────────────────────────────────

  Future<void> search(String query) async {
    if (query.isEmpty) return;
    ++_searchId;
    _isLoading = true;
    _hasSearched = true;
    _searchResults = [];
    _nextTrackUrl = null;
    _lastQuery = query;
    notifyListeners();

    try {
      final results = await Future.wait([
        MusicBrainzService.searchArtists(query),
        MusicBrainzService.searchAlbums(query),
        DeezerService.searchTracks(query),
        _yt.search
            .search(query)
            .then((r) => r.toList())
            .catchError((_) => <Video>[]),
      ]);

      final deezerData = Map<String, dynamic>.from(results[2] as Map? ?? {}),
          musicbrainzArtists = List<Map<String, dynamic>>.from(
            results[0] as List? ?? [],
          ),
          musicbrainzAlbums = List<Map<String, dynamic>>.from(
            results[1] as List? ?? [],
          ),
          youtubeData = List<Video>.from(results[3] as List? ?? []);

      // ---------- ARTISTS (now using embedded 'image' from MusicBrainz) ----------
      for (final artist in musicbrainzArtists) {
        try {
          final cover =
              artist['image'] as String? ??
              'lib/graphics/no_thumbnail_found.jpg';
          _searchResults.add(
            SearchResultItem(
              type: SearchResultType.artist,
              data: {
                'id': artist['id'],
                'name': artist['name'],
                'picture_medium': cover,
                'source': 'musicbrainz',
                'type': artist['type'] ?? '',
                'lifeSpan': Map<String, dynamic>.from(artist['lifeSpan'] ?? {}),
                'area': Map<String, dynamic>.from(artist['area'] ?? {}),
                'tags': List<String>.from(artist['tags'] as List? ?? []),
              },
            ),
          );
        } catch (e) {
          print('===MYLOG=== search: artist result error: $e');
        }
      }

      // ---------- ALBUMS (now using embedded 'coverArt' from MusicBrainz) ----------
      // Keep Deezer only for deezer_id (playback)
      final albumFutures = musicbrainzAlbums.map((album) async {
        final albumId = album['id'] as String? ?? '';
        final albumTitle = album['title'] as String? ?? '';
        final artistName =
            await MusicBrainzService.getArtistNameFromReleaseGroup(albumId);
        // Still need Deezer ID for tracks
        final deezerAlbum = artistName != null
            ? await DeezerService.findDeezerAlbum(artistName, albumTitle)
            : null;
        return {
          'album': album,
          'artistName': artistName ?? '',
          'deezerAlbum': deezerAlbum,
        };
      }).toList();

      final albumResults = await Future.wait(albumFutures);

      for (final result in albumResults) {
        try {
          final album = result['album'] as Map<String, dynamic>?;
          if (album == null) continue;
          final artistName = result['artistName'] as String? ?? '';
          final deezerAlbum = result['deezerAlbum'] != null
              ? Map<String, dynamic>.from(result['deezerAlbum'] as Map)
              : null;

          // --- Use coverArt from MusicBrainz, not from Deezer ---
          final cover =
              album['coverArt'] as String? ??
              '../graphics/no_thumbnail_found.jpg';

          _searchResults.add(
            SearchResultItem(
              type: SearchResultType.album,
              data: {
                'id': album['id'] ?? '',
                'title': album['title'] ?? '',
                'artist': {'name': artistName},
                'cover_medium': cover,
                'cover_big': cover,
                'cover_small': cover,
                'deezer_id': deezerAlbum?['id'], // only for playback
                'date': album['date'] ?? '',
                'secondaryTypes': List<String>.from(
                  album['secondaryTypes'] as List? ?? [],
                ),
                'primaryType': album['primaryType'] ?? 'Album',
                'disambiguation': album['disambiguation'] ?? '',
                'tags': List<String>.from(album['tags'] as List? ?? []),
                'source': 'musicbrainz',
              },
            ),
          );
        } catch (e) {
          print('===MYLOG=== search: album result error: $e');
        }
      }

      // ---------- Tracks from Deezer (unchanged) ----------
      try {
        for (final t in List<Map<String, dynamic>>.from(
          deezerData['tracks'] as List? ?? [],
        )) {
          _searchResults.add(
            SearchResultItem(type: SearchResultType.track, data: t),
          );
        }
      } catch (e) {
        print('===MYLOG=== search: deezer tracks error: $e');
      }

      _nextTrackUrl = deezerData['nextTrackUrl'] as String?;

      // ---------- YouTube cross‑match (unchanged) ----------
      // ... (same as before)
      final deezerTracks = _searchResults
          .where((i) => i.type == SearchResultType.track)
          .toList();

      for (final video in youtubeData) {
        final vtLower = video.title.toLowerCase();
        SearchResultItem? matched;
        for (final item in deezerTracks) {
          if (item.video != null) continue;
          final dtLower = (item.data['title'] as String? ?? '').toLowerCase();
          if (vtLower.contains(dtLower) || dtLower.contains(vtLower)) {
            matched = item;
            break;
          }
        }
        if (matched != null) {
          matched.video = video;
        } else {
          _searchResults.add(
            SearchResultItem(
              type: SearchResultType.track,
              data: {
                'title': video.title,
                'artist': {'name': video.author},
                'album': {'cover_medium': video.thumbnails.highResUrl},
                'id': video.id.value,
              },
              video: video,
            ),
          );
        }
      }
    } catch (e) {
      print('===MYLOG=== search error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Load more ───────────────────────────────────────────────────────────────

  Future<void> loadMore() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    try {
      Map<String, dynamic> data;
      if (_nextTrackUrl != null) {
        data = await DeezerService.loadMoreTracks(_nextTrackUrl!);
      } else if (_lastQuery.isNotEmpty) {
        // Exhausted pages — loop back to page 1 for infinite scrolling
        data = await DeezerService.searchAllTracks(_lastQuery);
      } else {
        return;
      }
      final tracks = List<Map<String, dynamic>>.from(data['tracks'] ?? []);
      if (tracks.isNotEmpty) {
        for (final t in tracks) {
          _searchResults.add(
            SearchResultItem(type: SearchResultType.track, data: t),
          );
        }
        _nextTrackUrl = data['nextTrackUrl'] as String?;
        notifyListeners();
      }
    } catch (e) {
      print('===MYLOG=== loadMore error: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  // ── Lazy YouTube resolve on tap ─────────────────────────────────────────────

  Future<Video?> resolveVideo(SearchResultItem item) async {
    if (item.video != null) return item.video;
    final artist = item.data['artist'];
    final artistName = (artist is Map)
        ? (artist['name'] ?? '')
        : (artist ?? '');
    final video = await _ytSearch(
      item.data['title'],
      artistName,
    ).timeout(const Duration(seconds: 8), onTimeout: () => null);
    item.video = video;
    return video;
  }

  //─────── Deezer track to yt video ───────────────────────────────────────────
  Future<Video?> convertDeezerTrackToVideo(Map<String, dynamic> track) async {
    final title = track['title'] as String? ?? '';
    final artist = track['artist']?['name'] as String? ?? '';
    return await _ytSearch(title, artist);
  }

  void clear() {
    _searchResults = [];
    _isLoading = false;
    _hasSearched = false;
    _isLoadingMore = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }
}
