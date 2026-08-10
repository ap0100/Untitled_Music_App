import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../utils/color_utils.dart';
import '../services/player.dart';
import '../services/search.dart';
import '../services/queue_manager.dart';
import '../main_widgets/mini_player.dart';
import '../screens/now_playing_screen.dart';
import '../screens/album_view.dart';
import '../services/musicbrainz.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ArtistProfile extends StatefulWidget {
  final String artistName;
  final String artistImage;
  final String? mbArtistId;
  final String? type;
  final List<dynamic> genre;
  final Map<String?, dynamic> span, area;

  const ArtistProfile({
    super.key,
    required this.artistName,
    required this.artistImage,
    required this.mbArtistId,
    required this.type,
    required this.genre,
    required this.span,
    required this.area,
  });

  @override
  _ArtistProfileState createState() => _ArtistProfileState();
}

class _ArtistProfileState extends State<ArtistProfile> {
  ValueNotifier<List<Map<String, dynamic>>> topTracksNotifier = ValueNotifier(
    [],
  );
  bool _topTracksLoading = true;
  //String get _country => widget.area['name'] as String? ?? '';

  ValueNotifier<List<Map<String, dynamic>>> albumsNotifier = ValueNotifier([]);
  bool _albumsLoading = true;

  final PlayerService _playerService = PlayerService();
  final SearchService _searchService = SearchService();
  Video? video;
  String? currentVideoId;

  @override
  @override
  void initState() {
    super.initState();
    _albumsLoading = true;
    _loadAlbums().then((_) => _loadSomeTracks());
    _playerService.addListener(_onPlayerChanged);
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _playerService.removeListener(_onPlayerChanged);
    super.dispose();
  }

  Future<void> _loadAlbums() async {
    _albumsLoading = true;
    if (mounted) setState(() {});
    // Step 1: get albums without covers (fast)
    final albumsList = await MusicBrainzService.getArtistAlbums(
      widget.mbArtistId,
      widget.artistName,
      fetchCovers: false,
    );
    if (albumsList == null || albumsList.isEmpty) {
      albumsNotifier.value = [];
      return;
    }

    // Show the list immediately
    albumsNotifier.value = List.from(albumsList);

    // Step 2: fetch covers one by one
    for (int i = 0; i < albumsList.length; i++) {
      final album = albumsList[i];
      final cover = await MusicBrainzService.fetchAlbumCover(
        album['id'] as String,
        widget.artistName,
        album['title'] as String,
      );
      albumsList[i]['coverArt'] = cover;
      // Trigger rebuild of the albums section
      albumsNotifier.value = List.from(albumsList);
    }

    _albumsLoading = false;
    if (mounted) setState(() {});
  }

  Future<void> _loadSomeTracks() async {
    _topTracksLoading = true;
    if (mounted) setState(() {});
    topTracksNotifier.value = [];

    try {
      final albums = albumsNotifier.value;
      if (albums.isEmpty) {
        print('===MYLOG=== No albums available for picking some tracks');
        topTracksNotifier.value = [];
        _topTracksLoading = false;
        if (mounted) setState(() {});
        return;
      }

      // For each album, fetch a release ID and then its tracks
      final allTracks = <Map<String, dynamic>>[];
      final seenTitles = <String>{};

      // Take up to 5 albums to avoid too many requests
      final selectedAlbums = albums.take(5).toList();

      for (final album in selectedAlbums) {
        final albumId = album['id'] as String?;
        if (albumId == null) continue;

        // Get a release ID for this album
        final releaseId = await MusicBrainzService.getBestReleaseFromGroup(
          albumId,
        );
        if (releaseId == null) continue;

        // Fetch tracks for this release
        final tracks = await MusicBrainzService.getAlbumTracks(releaseId);
        for (final track in tracks) {
          final title = track['title'] as String? ?? '';
          if (title.isEmpty) continue;
          // Deduplicate by normalized title (lowercase, stripped of punctuation)
          final normalized = title
              .toLowerCase()
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .trim();
          if (seenTitles.contains(normalized)) continue;
          seenTitles.add(normalized);
          allTracks.add({
            ...track,
            'artist_name': widget.artistName,
            'album_title': album['title'] ?? '',
            'source': 'musicbrainz',
            'id': 'mb_${track['id'] ?? DateTime.now().millisecondsSinceEpoch}',
          });
        }
      }

      // Shuffle and take 7
      allTracks.shuffle();
      final selectedTracks = allTracks.take(7).toList();

      print('===MYLOG=== Loaded ${selectedTracks.length} tracks from albums');
      topTracksNotifier.value = selectedTracks;
    } catch (e) {
      print('===MYLOG=== Album tracks error: $e');
      topTracksNotifier.value = [];
    } finally {
      _topTracksLoading = false;
      if (mounted) setState(() {});
    }
  }

  String status() {
    if (widget.span['ended'] == true) {
      return widget.type == 'Group'
          ? 'Disbanded: ${widget.span['begin']} - ${widget.span['end']}'
          : 'No longer active: ${widget.span['begin']} - ${widget.span['end']}';
    } else {
      return 'Active: since ${widget.span['begin']}';
    }
  }

  void _navigateToAlbumView(
    BuildContext context,
    Map<String, dynamic> album,
    String? cover,
    String? title,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumView(
          albumCover: cover ?? 'lib/graphics/no_thumbnail_found.jpg',
          albumName: title ?? 'Unknown title',
          artistName: widget.artistName,
          mbReleaseGroupId: album['id'] as String?,
          primaryType: album['primaryType'] as String?,
          secondaryTypes: album['secondaryTypes'] ?? [],
          disambiguation: album['disambiguation'] as String?,
          tags: album['tags'] ?? [],
        ),
      ),
    );
  }

  Future<void> _playTrack(Map<String, dynamic> track) async {
    QueueManager().playingFromQueue = false;

    String title;
    String artist;

    title = track['title'] ?? '';
    artist = track['artist_name'] ?? widget.artistName;

    /*if (track['source'] == 'musicbrainz' || track['source'] == 'listenbrainz') {
      // Music/ListenBrainz track format
      title = track['title'] ?? '';
      artist = track['artist_name'] ?? widget.artistName;
    } else {
      // Deezer track format
      title = track['title'] ?? '';
      artist = track['artist']?['name'] ?? widget.artistName;
    }*/

    final resolvedVideo = await _searchService
        .searchYouTube('$title $artist')
        .then((videos) => videos.isNotEmpty ? videos.first : null);

    if (!mounted) return;
    if (resolvedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video not found for this track.')),
      );
      return;
    }

    video = resolvedVideo;
    currentVideoId = track['id'].toString();
    print('===MYLOG===: currentVideoId: $currentVideoId');
    _playerService.setCurrentVideoPlayingFrom('artist_profile');
    _playerService.setPlayingDeezerTrackId(currentVideoId);
    _playerService.play(video!);
    _searchService.buildQueueInBackground(video!);
  }

  @override
  Widget build(BuildContext context) {
    final bool miniPlayerVisible = _playerService.currentVideo != null;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Color.fromARGB(137, 234, 169, 240),
                width: 2,
              ),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromARGB(206, 0, 0, 0),
                Color.fromARGB(255, 27, 17, 26),
              ],
            ),
          ),
        ),
        elevation: 0,
        leading: IconButton(
          padding: EdgeInsets.only(left: 17),
          icon: const Icon(
            Icons.arrow_downward,
            color: Color.fromARGB(255, 227, 156, 236),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Viewing ${widget.artistName}\'s profile...',
          style: const TextStyle(
            color: Color.fromARGB(255, 169, 240, 234),
            fontSize: 15,
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            color: const Color.fromARGB(255, 27, 17, 26),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: miniPlayerVisible ? 80.0 : 0.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    //height: 290,
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.fromARGB(255, 27, 17, 26),
                            Colors.transparent,
                          ],
                          stops: [0.15, 2],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: Transform.translate(
                        offset: const Offset(0, -20),
                        child: CachedNetworkImage(
                          imageUrl: widget.artistImage,
                          width: double.infinity,
                          height: MediaQuery.of(context).size.width * 0.8,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          placeholder: (context, url) =>
                              const Icon(Icons.album, size: 50),
                          errorWidget: (context, url, error) => Image.asset(
                            'lib/graphics/no_thumbnail_found.jpg',
                          ),
                        ),
                      ),
                    ),
                  ),

                  Transform.translate(
                    offset: Offset(0, -47),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          margin: EdgeInsets.only(left: 10, right: 10),
                          width: MediaQuery.of(context).size.width,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            border: Border(
                              bottom: BorderSide(
                                color: const Color.fromARGB(197, 234, 169, 240),
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: Text(
                            widget.artistName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 234, 169, 240),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: MediaQuery.of(context).size.width,
                          padding: const EdgeInsets.only(
                            left: 10,
                            right: 15,
                            bottom: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Color.fromARGB(137, 234, 169, 240),
                                width: 2,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Type – only if not null/empty
                              if (widget.type != null &&
                                  widget.type!.isNotEmpty) ...[
                                Text(
                                  widget.type!,
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 234, 169, 240),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 7),
                              ],

                              // Genres – only if the list is not empty
                              if (widget.genre.isNotEmpty) ...[
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: 'Genre tags: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color.fromARGB(
                                            255,
                                            234,
                                            169,
                                            240,
                                          ),
                                          fontSize: 15,
                                        ),
                                      ),
                                      TextSpan(
                                        text: widget.genre.join(", "),
                                        style: const TextStyle(
                                          color: Color.fromARGB(
                                            255,
                                            186,
                                            172,
                                            187,
                                          ),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 7),
                              ],

                              // From (area) – only if the name exists and is not empty
                              if (widget.area['name'] != null &&
                                  widget.area['name']
                                      .toString()
                                      .isNotEmpty) ...[
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: 'From: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color.fromARGB(
                                            255,
                                            234,
                                            169,
                                            240,
                                          ),
                                          fontSize: 15,
                                        ),
                                      ),
                                      TextSpan(
                                        text: widget.area['name'].toString(),
                                        style: const TextStyle(
                                          color: Color.fromARGB(
                                            255,
                                            186,
                                            172,
                                            187,
                                          ),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 7),
                              ],

                              // Formed (year) – only if the begin date exists and is not empty
                              if (widget.span['begin'] != null &&
                                  widget.span['begin']
                                      .toString()
                                      .isNotEmpty) ...[
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: 'Status: ', // corrected typo
                                        style: TextStyle(
                                          color: Color.fromARGB(
                                            255,
                                            234,
                                            169,
                                            240,
                                          ),
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(
                                        text: status(),
                                        style: const TextStyle(
                                          color: Color.fromARGB(
                                            255,
                                            186,
                                            172,
                                            187,
                                          ),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          margin: EdgeInsets.only(left: 10, right: 10),
                          //width: 160,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Color.fromARGB(197, 234, 169, 240),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Text(
                            'Some of ${widget.artistName}\'s tracks',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 234, 169, 240),
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),
                        SizedBox(
                          height: 45,
                          child: SizedBox(
                            height: 45,
                            child: _topTracksLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Color.fromARGB(255, 234, 169, 240),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : topTracksNotifier.value.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No tracks found.',
                                      style: TextStyle(
                                        color: Color.fromARGB(
                                          118,
                                          250,
                                          162,
                                          253,
                                        ),
                                      ),
                                    ),
                                  )
                                : ValueListenableBuilder<
                                    List<Map<String, dynamic>>
                                  >(
                                    valueListenable: topTracksNotifier,
                                    builder: (context, tracks, _) {
                                      return ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        itemCount: tracks.length,
                                        itemBuilder: (context, index) {
                                          final track = tracks[index];
                                          final coverUrl =
                                              (track['album']
                                                      as Map?)?['cover_medium']
                                                  as String? ??
                                              widget.artistImage;
                                          final bool _isPlaying =
                                              track['id'].toString() ==
                                                  _playerService
                                                      .playingDeezerTrackId &&
                                              _playerService
                                                      .currentVideoPlayingFrom ==
                                                  'artist_profile';
                                          return FutureBuilder<Color?>(
                                            future: coverUrl.isNotEmpty
                                                ? ColorUtils.getPrimaryColor(
                                                    coverUrl,
                                                  )
                                                : Future.value(null),
                                            builder: (context, colorSnapshot) {
                                              final color =
                                                  colorSnapshot.data ??
                                                  (coverUrl.isNotEmpty
                                                      ? ColorUtils.getCachedColor(
                                                          coverUrl,
                                                        )
                                                      : null);
                                              final darkened = ColorUtils()
                                                  .darken(
                                                    color ?? Colors.grey,
                                                    0.5,
                                                  );
                                              return GestureDetector(
                                                onTap: () => _playTrack(track),
                                                child: Container(
                                                  width: 230,
                                                  margin: const EdgeInsets.only(
                                                    right: 10,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color.fromARGB(
                                                      255,
                                                      73,
                                                      46,
                                                      70,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    border: Border(
                                                      bottom: BorderSide(
                                                        color: _isPlaying
                                                            ? Color.fromARGB(
                                                                197,
                                                                169,
                                                                240,
                                                                228,
                                                              )
                                                            : const Color.fromARGB(
                                                                197,
                                                                234,
                                                                169,
                                                                240,
                                                              ),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    gradient: LinearGradient(
                                                      begin:
                                                          Alignment.topCenter,
                                                      end: Alignment
                                                          .bottomCenter,
                                                      colors: _isPlaying
                                                          ? [
                                                              Color.fromARGB(
                                                                73,
                                                                240,
                                                                169,
                                                                230,
                                                              ),
                                                              Color.fromARGB(
                                                                255,
                                                                73,
                                                                46,
                                                                70,
                                                              ),
                                                            ]
                                                          : [
                                                              darkened?.withValues(
                                                                    alpha: 0.65,
                                                                  ) ??
                                                                  const Color.fromARGB(
                                                                    80,
                                                                    234,
                                                                    169,
                                                                    240,
                                                                  ),
                                                              Colors
                                                                  .transparent,
                                                            ],
                                                      stops: const [0.0, 1.5],
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              right: 10,
                                                            ),
                                                        width: 50,
                                                        height: 50,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape
                                                              .rectangle,
                                                          borderRadius:
                                                              const BorderRadius.only(
                                                                topLeft:
                                                                    Radius.circular(
                                                                      4,
                                                                    ),
                                                                bottomLeft:
                                                                    Radius.circular(
                                                                      4,
                                                                    ),
                                                              ),
                                                        ),
                                                        child: ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.only(
                                                                topLeft:
                                                                    Radius.circular(
                                                                      4,
                                                                    ),
                                                                bottomLeft:
                                                                    Radius.circular(
                                                                      4,
                                                                    ),
                                                              ),
                                                          child: CachedNetworkImage(
                                                            imageUrl: coverUrl,
                                                            fit:
                                                                BoxFit.fitWidth,
                                                            errorWidget:
                                                                (
                                                                  context,
                                                                  url,
                                                                  error,
                                                                ) => Image.asset(
                                                                  'lib/graphics/no_thumbnail_found.jpg',
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        width: 120,
                                                        padding:
                                                            EdgeInsets.only(
                                                              bottom: 3,
                                                            ),
                                                        child: Text(
                                                          track['title'],
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                            fontSize: 13.5,
                                                            color:
                                                                Color.fromARGB(
                                                                  255,
                                                                  248,
                                                                  217,
                                                                  252,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 11),
                                                      Expanded(
                                                        child: IconButton(
                                                          icon: Icon(
                                                            Icons.menu_sharp,
                                                            color:
                                                                Color.fromARGB(
                                                                  188,
                                                                  248,
                                                                  205,
                                                                  246,
                                                                ),
                                                          ),
                                                          iconSize: 18,
                                                          onPressed: () {},
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: EdgeInsets.only(left: 10, right: 10),
                              width: 57,
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Color.fromARGB(197, 234, 169, 240),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Albums',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(255, 234, 169, 240),
                                ),
                              ),
                            ),
                            SizedBox(height: 15),
                            SizedBox(
                              height: /*!miniPlayerVisible
                                  ? MediaQuery.of(context).size.height * 0.35
                                  : MediaQuery.of(context).size.height * 0.29,*/
                                  MediaQuery.of(context).size.height * 0.4,
                              child: _albumsLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: Color.fromARGB(
                                          255,
                                          234,
                                          169,
                                          240,
                                        ),
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : ValueListenableBuilder<
                                      List<Map<String, dynamic>>
                                    >(
                                      valueListenable: albumsNotifier,
                                      builder: (context, albumList, _) {
                                        if (albumList.isEmpty) {
                                          return const Center(
                                            heightFactor: 2.5,
                                            child: Text(
                                              'No albums found.',
                                              style: TextStyle(
                                                color: Color.fromARGB(
                                                  118,
                                                  250,
                                                  162,
                                                  253,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return ListView.builder(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          itemCount: albumList.length,
                                          itemBuilder: (context, index) {
                                            final album = albumList[index];
                                            final title =
                                                album['title'] as String? ??
                                                'Unknown';
                                            final cover =
                                                album['coverArt'] as String? ??
                                                '';
                                            return GestureDetector(
                                              onTap: () => _navigateToAlbumView(
                                                context,
                                                album,
                                                cover,
                                                title,
                                              ),
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                  bottom: 10,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      const Color.fromARGB(
                                                        47,
                                                        209,
                                                        114,
                                                        218,
                                                      ),
                                                      Colors.transparent,
                                                    ],
                                                    stops: [-0.1, 1.5],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.only(
                                                        topLeft:
                                                            Radius.circular(3),
                                                        bottomLeft:
                                                            Radius.circular(3),
                                                      ),
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color:
                                                          const Color.fromARGB(
                                                            255,
                                                            133,
                                                            77,
                                                            125,
                                                          ),
                                                      width: 1,
                                                    ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 50,
                                                      height: 45,
                                                      decoration: BoxDecoration(
                                                        shape:
                                                            BoxShape.rectangle,
                                                        borderRadius:
                                                            const BorderRadius.only(
                                                              topLeft:
                                                                  Radius.circular(
                                                                    3,
                                                                  ),
                                                              bottomLeft:
                                                                  Radius.circular(
                                                                    3,
                                                                  ),
                                                            ),
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            const BorderRadius.only(
                                                              topLeft:
                                                                  Radius.circular(
                                                                    3,
                                                                  ),
                                                              bottomLeft:
                                                                  Radius.circular(
                                                                    3,
                                                                  ),
                                                            ),
                                                        child: CachedNetworkImage(
                                                          imageUrl: cover,
                                                          fit: BoxFit.cover,
                                                          placeholder:
                                                              (context, url) =>
                                                                  const Icon(
                                                                    Icons.album,
                                                                  ),
                                                          errorWidget:
                                                              (
                                                                context,
                                                                url,
                                                                error,
                                                              ) => Image.asset(
                                                                'lib/graphics/no_thumbnail_found.jpg',
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 15),
                                                    Expanded(
                                                      child: Container(
                                                        width: 50,
                                                        padding:
                                                            EdgeInsets.only(
                                                              bottom: 0.5,
                                                            ),
                                                        child: Text(
                                                          title,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                            color:
                                                                Color.fromARGB(
                                                                  255,
                                                                  248,
                                                                  217,
                                                                  252,
                                                                ),
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      onPressed: () {
                                                        _navigateToAlbumView(
                                                          context,
                                                          album,
                                                          cover,
                                                          title,
                                                        );
                                                      },
                                                      icon: Icon(
                                                        Icons
                                                            .arrow_forward_ios_sharp,
                                                        color: Color.fromARGB(
                                                          255,
                                                          133,
                                                          77,
                                                          125,
                                                        ),
                                                      ),
                                                      iconSize: 15,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                              /*FutureBuilder<List<Map<String, dynamic>>?>(
                                future: albums,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Color.fromARGB(
                                          255,
                                          234,
                                          169,
                                          240,
                                        ),
                                        strokeWidth: 2,
                                      ),
                                    );
                                  }
                                  if (snapshot.hasError ||
                                      !snapshot.hasData ||
                                      snapshot.data!.isEmpty) {
                                    return const Center(
                                      heightFactor: 2.5,
                                      child: Text(
                                        'No albums found.',
                                        style: TextStyle(
                                          color: Color.fromARGB(
                                            118,
                                            250,
                                            162,
                                            253,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final albumList = snapshot.data!;
                                  return ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    itemCount: albumList.length,
                                    itemBuilder: (context, index) {
                                      final album = albumList[index];
                                      final title =
                                          album['title'] as String? ??
                                          'Unknown';
                                      final cover = album['coverArt'] as String;
                                      
                                    },
                                  );
                                },
                              ),*/
                            ),
                          ],
                        ), // spacer to push content up
                      ],
                    ),
                  ),
                  //SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // MiniPlayer overlay
          if (_playerService.currentVideo != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: MiniPlayer(
                artistProfileFocused: true,
                searchFocused: false,
                player: _playerService.player,
                video: _playerService.currentVideo,
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, animation, __) => NowPlayingScreen(
                        playerService: _playerService,
                        queueNotifier: QueueManager().queueNotifier,
                        searchService: _searchService,
                      ),
                      transitionsBuilder: (_, animation, __, child) {
                        const begin = Offset(0.0, 1.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;
                        return SlideTransition(
                          position: animation.drive(
                            Tween(
                              begin: begin,
                              end: end,
                            ).chain(CurveTween(curve: curve)),
                          ),
                          child: child,
                        );
                      },
                    ),
                  );
                },
                darkened: ColorUtils().darken(
                  ColorUtils.getCachedColor(
                    _playerService.currentVideo!.thumbnails.highResUrl,
                  ),
                  0.05,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
