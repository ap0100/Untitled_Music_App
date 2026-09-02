import 'package:flutter/material.dart';
import 'package:music_player/theme/cyberpunk_vibrant.dart';
import '../main_widgets/mini_player.dart';
import '../services/player.dart';
import '../services/search.dart';
import '../utils/color_utils.dart';
import '../main_widgets/search_bar.dart';
import 'now_playing_screen.dart';
import '../services/queue_manager.dart';
import '../main_widgets/results_display.dart';
import '../services/deezer.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Singletons — same instance across rebuilds
  final PlayerService _playerService = PlayerService();
  final SearchService _searchService = SearchService();

  final ScrollController _scrollController = ScrollController();
  bool _isSearchFocused = false;
  SearchResultItem? _loadingItem; // tracks which item is currently resolving

  bool _showArtists = true;
  bool _showAlbums = true;
  bool _showTracks = true;

  @override
  void initState() {
    super.initState();

    // Rebuild whenever player state changes (currentVideo, isBuffering, etc.)
    _playerService.addListener(_onPlayerChanged);
    _searchService.addListener(_onSearchChanged);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _searchService.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _playerService.removeListener(_onPlayerChanged);
    _searchService.removeListener(_onSearchChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleArtists() {
    setState(() {
      _showArtists = !_showArtists;
    });
  }

  void _toggleAlbums() {
    setState(() {
      _showAlbums = !_showAlbums;
    });
  }

  void _toggleTracks() {
    setState(() {
      _showTracks = !_showTracks;
    });
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _playTrack(SearchResultItem item) async {
    if (_loadingItem == item) return; // already loading this one
    setState(() => _loadingItem = item);
    final video = await _searchService.resolveVideo(item);
    if (!mounted) return;
    if (video == null) {
      setState(() => _loadingItem = null);
      return;
    }
    _playerService.setCurrentVideoPlayingFrom('search_screen');
    _playerService.setPlayingDeezerTrackId(item.data['id'].toString());
    QueueManager().refresh();
    DeezerService.refresh();
    _searchService.buildQueueInBackground(video);
    await _playerService.play(video);
    if (mounted) setState(() => _loadingItem = null);
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    await _searchService.search(query);
  }

  Widget _buildArtistTile(Map<String, dynamic> artist) {
    return ArtistDisplay(
      name: artist['name'],
      coverUrl: artist['picture_medium'],
      artistId: artist['id'],
      genre: (artist['tags'] as List? ?? []).map((e) => e.toString()).toList(),
      type: artist['type'],
      span:
          (artist['lifeSpan'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
      area:
          (artist['area'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
    );
  }

  Widget _buildAlbumTile(Map<String, dynamic> album) {
    return AlbumDisplay(
      title: album['title'],
      artistName: album['artist']?['name'] ?? '',
      coverUrl: album['cover_medium'] ?? album['cover-medium'],
      releaseGroupId: album['id'],
      primaryType: album['primaryType'],
      secondaryTypes: (album['secondaryTypes'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      disambiguation: album['disambiguation'],
      tags: (album['tags'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }

  Widget _buildTrackTile(SearchResultItem item) {
    return _TrackTile(
      key: ValueKey(item.data['id']),
      item: item,
      playerService: _playerService,
      isLoading: _loadingItem == item,
      onPlay: () => _playTrack(item),
    );
  }

  Widget _buildResults() {
    final allResults = _searchService.searchResults;

    final bool artistsLoading =
        _searchService.isLoading &&
        !allResults.any((item) => item.type == SearchResultType.artist);
    final bool albumsLoading =
        _searchService.isLoading &&
        !allResults.any((item) => item.type == SearchResultType.album);

    if (_searchService.isLoading && allResults.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color.fromARGB(255, 169, 240, 234),
        ),
      );
    }

    if (!_searchService.hasSearched) {
      return const Center(
        child: Text(
          'Search for a song, artist profile, album, playlist,...',
          style: TextStyle(color: Color.fromARGB(255, 232, 176, 243)),
        ),
      );
    }

    if (allResults.isEmpty) {
      return const Center(
        child: Text(
          'No results found.',
          style: TextStyle(color: Color.fromARGB(118, 250, 162, 253)),
        ),
      );
    }

    final filteredResults = allResults.where((item) {
      switch (item.type) {
        case SearchResultType.artist:
          return _showArtists;
        case SearchResultType.album:
          return _showAlbums;
        case SearchResultType.track:
          return _showTracks;
      }
    }).toList();
    if (filteredResults.isEmpty) {
      if (_showTracks == false && (artistsLoading || albumsLoading == true)) {
        return const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color.fromARGB(255, 169, 240, 234),
          ),
        );
      }
      return const Center(
        child: Text(
          'No results match your filters.',
          style: TextStyle(color: Color.fromARGB(118, 250, 162, 253)),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: filteredResults.length,
      itemBuilder: (context, index) {
        final item = filteredResults[index];
        switch (item.type) {
          case SearchResultType.artist:
            return _buildArtistTile(item.data);
          case SearchResultType.album:
            return _buildAlbumTile(item.data);
          case SearchResultType.track:
            return _buildTrackTile(item); // ?? const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildFilterButton({
    required String label,
    required bool isActive,
    required bool isLoading,
    required VoidCallback onTap,
    required Color color,
    required String type,
    double h = 50,
    double w = 65,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Stack(
        children: [
          ClipPath(
            clipper: filterButtonClipper(type: type, offset: 1),
            child: Container(
              height: h,
              width: w,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: isActive
                      ? [
                          CyberpunkTheme.tyrianPurple.withValues(alpha: 0.4),
                          CyberpunkTheme.shimmerPink.withValues(alpha: 0.8),
                        ]
                      : [
                          CyberpunkTheme.darkWarm.withValues(alpha: 0.6),
                          CyberpunkTheme.tyrianPurple.withValues(alpha: 0.8),
                        ],
                ),
              ),
            ),
          ),
          ClipPath(
            clipper: filterButtonClipper(type: type),
            child: Container(
              height: h,
              width: w,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? color
                    : CyberpunkTheme.regalBlue.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(2.5),
                border: const Border(
                  bottom: BorderSide(
                    color: Color.fromARGB(255, 40, 163, 163),
                    width: 0.7,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: isLoading && isActive
                        ? Container(
                            margin: EdgeInsets.only(left: 10),
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: CyberpunkTheme.tyrianPurple,
                            ),
                          )
                        : Text(
                            label,
                            style: TextStyle(
                              color: isActive
                                  ? CyberpunkTheme.tyrianPurple.withValues(
                                      alpha: 0.75,
                                    )
                                  : CyberpunkTheme.shimmerPink.withValues(
                                      alpha: 0.8,
                                    ),
                              fontSize: 13,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allResults = _searchService.searchResults;
    final bool artistsLoading =
        _searchService.isLoading &&
        !allResults.any((item) => item.type == SearchResultType.artist);
    final bool albumsLoading =
        _searchService.isLoading &&
        !allResults.any((item) => item.type == SearchResultType.album);
    final bool tracksLoading =
        _searchService.isLoading &&
        !allResults.any((item) => item.type == SearchResultType.track);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(0.0, 0.0),
            end: const Alignment(0.0, 1.6),
            colors: const [
              CyberpunkTheme.dark, //Color.fromARGB(255, 23, 19, 31),
              CyberpunkTheme.darkCold, // Color.fromARGB(255, 103, 89, 136),
            ],
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                SearchBarWidget(
                  onFocusChange: (hasFocus) {
                    setState(() => _isSearchFocused = hasFocus);
                  },
                  controller: TextEditingController(),
                  onSearch: _search,
                  onSubmitted: _search,
                ),
                Stack(
                  children: [
                    Container(
                      color: _isSearchFocused
                          ? CyberpunkTheme.tyrianPurple.withValues(alpha: 0.95)
                          : CyberpunkTheme.brightTurquoise.withValues(
                              alpha: 0.7,
                            ),
                      height: 50,
                    ),
                    Container(
                      padding: EdgeInsets.only(left: 8),
                      color: CyberpunkTheme.dark.withValues(alpha: 0.95),
                      height: 50,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Row(
                          children: [
                            _buildFilterButton(
                              label: "Artists",
                              isActive: _showArtists,
                              isLoading: artistsLoading,
                              onTap: _toggleArtists,
                              color: CyberpunkTheme.yellowish,
                              type: 'artists_btn',
                            ),
                            SizedBox(width: 10),
                            _buildFilterButton(
                              label: "Albums",
                              isActive: _showAlbums,
                              isLoading: albumsLoading,
                              onTap: _toggleAlbums,
                              w: 68,
                              color: CyberpunkTheme.turquoiseGreen,
                              type: 'albums_btn',
                            ),
                            SizedBox(width: 10),
                            _buildFilterButton(
                              label: "Tracks",
                              isActive: _showTracks,
                              isLoading: tracksLoading,
                              onTap: _toggleTracks,
                              color: const Color.fromARGB(
                                147,
                                31,
                                211,
                                214,
                              ).withValues(alpha: 0.66),
                              type: 'tracks_btn',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => FocusScope.of(context).unfocus(),
                        child: _buildResults(),
                      ),
                      // Decorative clipped overlay — floats over the top of results,
                      // takes zero layout space, scrolls nothing
                      Transform.translate(
                        offset: Offset(0, -8),
                        child: IgnorePointer(
                          child: Stack(
                            children: [
                              ClipPath(
                                clipper: filterSectionClipper(),
                                child: Container(
                                  height: 30,
                                  color: _isSearchFocused
                                      ? CyberpunkTheme.tyrianPurple.withValues(
                                          alpha: 0.95,
                                        )
                                      : CyberpunkTheme.brightTurquoise
                                            .withValues(alpha: 0.7),
                                ),
                              ),
                              ClipPath(
                                clipper: filterSectionClipper(offset: 3),
                                child: Container(
                                  height: 30,
                                  color: CyberpunkTheme.dark.withValues(
                                    alpha: 0.95,
                                  ),
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
            if (_playerService.currentVideo != null)
              Positioned(
                bottom: 0,
                right: 0,
                left: 0,
                child: MiniPlayer(
                  artistProfileFocused: false,
                  searchFocused: _isSearchFocused,
                  player: _playerService.player,
                  video: _playerService.currentVideo,
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            NowPlayingScreen(
                              playerService: _playerService,
                              queueNotifier: QueueManager().queueNotifier,
                              searchService: _searchService,
                            ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              const begin = Offset(0.0, 1.0);
                              const end = Offset.zero;
                              const curve = Curves.easeInOut;
                              var tween = Tween(
                                begin: begin,
                                end: end,
                              ).chain(CurveTween(curve: curve));
                              return SlideTransition(
                                position: animation.drive(tween),
                                child: child,
                              );
                            },
                      ),
                    );
                  },
                  darkened: ColorUtils().darken(
                    ColorUtils.getCachedColor(
                      _playerService.currentVideo?.thumbnails.highResUrl ??
                          _playerService
                              .currentVideo
                              ?.thumbnails
                              .standardResUrl ??
                          'lib/graphics/no_thumbnail_found.jpg',
                    ),
                    0.05,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Stable per-tile widget so parent rebuilds don't re-fire color futures ──
class _TrackTile extends StatefulWidget {
  final SearchResultItem item;
  final PlayerService playerService;
  final bool isLoading;
  final VoidCallback onPlay;

  const _TrackTile({
    super.key,
    required this.item,
    required this.playerService,
    required this.isLoading,
    required this.onPlay,
  });

  @override
  State<_TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends State<_TrackTile> {
  static const Color _fallback = Color.fromARGB(255, 27, 17, 26);
  late Future<Color?> _colorFuture;
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _coverUrl = widget.item.data['album']?['cover_medium'] as String? ?? '';
    _colorFuture = _coverUrl!.isNotEmpty
        ? ColorUtils.getPrimaryColor(_coverUrl!)
        : Future.value(null);
  }

  @override
  Widget build(BuildContext context) {
    //final bool isLoading = widget.isLoading;
    return FutureBuilder<Color?>(
      future: _colorFuture,
      builder: (context, snapshot) {
        final bgColor =
            snapshot.data ??
            (_coverUrl!.isNotEmpty
                ? ColorUtils.getCachedColor(_coverUrl!)
                : null);
        final darkened = ColorUtils().darken(bgColor ?? _fallback, 0.05);
        return Stack(
          children: [
            TrackDisplay(
              video: widget.item.video,
              deezerCoverUrl: _coverUrl,
              deezerTitle: widget.item.data['title'] as String? ?? '',
              deezerArtist:
                  widget.item.data['artist']?['name'] as String? ?? '',
              deezerTrackId: widget.item.data['id']?.toString(),
              playerService: widget.playerService,
              bgColor: bgColor,
              darkened: darkened,
              onPlay: widget.onPlay,
            ),
            /*if (isLoading)
              Positioned.fill(
                child: Container(
                  color: const Color.fromARGB(80, 0, 0, 0),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color.fromARGB(255, 141, 228, 221),
                      ),
                    ),
                  ),
                ),
              ),*/
          ],
        );
      },
    );
  }
}
