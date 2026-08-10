import 'package:flutter/material.dart';
import 'package:music_player/main_widgets/mini_player.dart';
import '../services/musicbrainz.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/color_utils.dart';
import '../screens/now_playing_screen.dart';
import '../services/player.dart';
import '../services/search.dart';
import '../services/queue_manager.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class AlbumView extends StatefulWidget {
  final String albumCover;
  final String albumName;
  final String artistName;
  final String? mbReleaseGroupId; // set when opened from artist profile
  final String? primaryType;
  final List<dynamic> secondaryTypes;
  final String? disambiguation;
  final List<dynamic> tags;

  const AlbumView({
    super.key,
    required this.albumCover,
    required this.albumName,
    required this.artistName,
    required this.mbReleaseGroupId,
    required this.primaryType,
    required this.secondaryTypes,
    required this.disambiguation,
    required this.tags,
  });

  @override
  _AlbumViewState createState() => _AlbumViewState();
}

class _AlbumViewState extends State<AlbumView> {
  Future<List<Map<String, dynamic>>>? albumTracks;
  final PlayerService _playerService = PlayerService();
  final SearchService _searchService = SearchService();
  Video? video;
  String? currentVideoId;

  @override
  void initState() {
    super.initState();
    albumTracks = _loadTracks();
    _playerService.addListener(_onPlayerChanged);
  }

  @override
  void dispose() {
    _playerService.removeListener(_onPlayerChanged);
    super.dispose();
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  Future<List<Map<String, dynamic>>> _loadTracks() async {
    if (widget.mbReleaseGroupId != null) {
      final releaseId = await MusicBrainzService.getBestReleaseFromGroup(
        widget.mbReleaseGroupId!,
      );
      if (releaseId != null) {
        final tracks = await MusicBrainzService.getAlbumTracks(releaseId);
        if (tracks.isNotEmpty) return tracks;
      }
    }

    return [];
  }

  Future<void> _playTrack(Map<dynamic, dynamic> track) async {
    QueueManager().playingFromQueue = false;

    String title;
    String artist;

    if (track['source'] == 'musicbrainz') {
      // MusicBrainz track format
      title = track['title'] ?? '';
      artist = track['artist_name'] ?? widget.artistName;
    } else {
      // Deezer track format
      title = track['title'] ?? '';
      artist = track['artist']?['name'] ?? widget.artistName;
    }

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
    _playerService.setCurrentVideoPlayingFrom('album_view');
    _playerService.setPlayingDeezerTrackId(currentVideoId);
    _playerService.play(video!);
    _searchService.buildQueueInBackground(video!);
  }

  @override
  Widget build(BuildContext context) {
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
        title: SizedBox(
          width: 270,
          child: Text(
            'Viewing ${widget.artistName}\'s ${widget.albumName} album...',
            style: const TextStyle(
              color: Color.fromARGB(255, 169, 240, 234),
              fontSize: 15,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            color: const Color.fromARGB(255, 27, 17, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  //color: Color.fromARGB(255, 60, 138, 141),
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.fromARGB(255, 27, 17, 26),
                          Colors.transparent,
                        ],
                        stops: [0.35, 2],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: CachedNetworkImage(
                      imageUrl: widget.albumCover,
                      width: double.infinity,
                      height: MediaQuery.of(context).size.width * 0.55,
                      fit: BoxFit.fill,
                      alignment: Alignment.topCenter,
                      placeholder: (context, url) =>
                          const Icon(Icons.album, size: 50),
                      errorWidget: (context, url, error) =>
                          Image.asset('lib/graphics/no_thumbnail_found.jpg'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: MediaQuery.of(context).size.width,
                  decoration: const BoxDecoration(
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
                      Text(
                        widget.albumName,
                        style: TextStyle(
                          color: Color.fromARGB(255, 232, 145, 240),
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 15),
                    ],
                  ),
                ),
                SizedBox(height: 15),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.only(
                    left: 10,
                    right: 15,
                    bottom: 10,
                  ),
                  width: MediaQuery.of(context).size.width,
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
                      // Artist
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Artist: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 234, 169, 240),
                                fontSize: 15,
                              ),
                            ),
                            TextSpan(
                              text: widget.artistName,
                              style: const TextStyle(
                                color: Color.fromARGB(255, 186, 172, 187),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),

                      // Type (optional)
                      if (widget.primaryType != null &&
                          widget.primaryType!.isNotEmpty) ...[
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Type: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(255, 234, 169, 240),
                                  fontSize: 15,
                                ),
                              ),
                              TextSpan(
                                text: widget.primaryType!,
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 186, 172, 187),
                                  fontSize: 15,
                                ),
                              ),
                              if (widget.secondaryTypes.isNotEmpty) ...[
                                TextSpan(
                                  text: ' (',
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 186, 172, 187),
                                  ),
                                ),
                                TextSpan(
                                  text: widget.secondaryTypes.join(', '),
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 186, 172, 187),
                                  ),
                                ),
                                TextSpan(
                                  text: ')',
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 186, 172, 187),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                      ],

                      // Tags as chips
                      if (widget.tags.isNotEmpty) ...[
                        const Text(
                          'Tags',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 234, 169, 240),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: widget.tags.map<Widget>((tag) {
                            return Chip(
                              label: Text(
                                tag.toString(),
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 248, 217, 252),
                                  fontSize: 13,
                                ),
                              ),
                              backgroundColor: const Color.fromARGB(
                                80,
                                234,
                                169,
                                240,
                              ),
                              side: const BorderSide(
                                color: Color.fromARGB(100, 234, 169, 240),
                                width: 0.5,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 7),
                      ],

                      // Disambiguation (only if not empty)
                      if (widget.disambiguation != null &&
                          widget.disambiguation!.isNotEmpty) ...[
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Disambiguation: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(255, 234, 169, 240),
                                  fontSize: 15,
                                ),
                              ),
                              TextSpan(
                                text: widget.disambiguation,
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 186, 172, 187),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 7),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color.fromARGB(137, 234, 169, 240),
                        width: 2,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Tracks',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 234, 169, 240),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: albumTracks,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color.fromARGB(255, 234, 169, 240),
                            strokeWidth: 2,
                          ),
                        );
                      }
                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text(
                            'No tracks found.',
                            style: TextStyle(
                              color: Color.fromARGB(118, 250, 162, 253),
                            ),
                          ),
                        );
                      }

                      final tracks = snapshot.data!;
                      return ListView.builder(
                        itemCount: tracks.length,
                        itemBuilder: (context, index) {
                          final track = tracks[index];
                          final bool _isPlaying =
                              track['id'].toString() ==
                                  _playerService.playingDeezerTrackId &&
                              _playerService.currentVideoPlayingFrom ==
                                  'album_view';
                          return Container(
                            color: _isPlaying
                                ? Color.fromARGB(223, 54, 41, 56)
                                : const Color.fromARGB(255, 27, 17, 26),
                            child: ListTile(
                              leading: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Color.fromARGB(141, 248, 217, 252),
                                  fontSize: 15,
                                ),
                              ),
                              title: Text(
                                track['title'] ?? 'Unknown Track',
                                style: TextStyle(
                                  color: _isPlaying
                                      ? Color.fromARGB(224, 205, 162, 211)
                                      : Color.fromARGB(225, 245, 194, 252),
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                _playTrack(track);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

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
