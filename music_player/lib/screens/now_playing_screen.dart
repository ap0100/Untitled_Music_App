import 'package:flutter/material.dart' hide RepeatMode;
import '../services/player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../utils/youtube_cleaner.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/repeat_mode.dart';
import '../services/search.dart';
import '../services/queue_manager.dart';
import '../services/lyrics.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NowPlayingScreen extends StatefulWidget {
  final PlayerService playerService;
  final ValueNotifier<List<Video>> queueNotifier;
  final SearchService searchService;

  const NowPlayingScreen({
    super.key,
    required this.playerService,
    required this.queueNotifier,
    required this.searchService,
  });

  @override
  _NowPlayingScreenState createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  int _currentIndex = 0;
  String _currentLyrics = '';
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    widget.queueNotifier.addListener(_onQueueChanged);
    widget.playerService.addListener(_onVideoChanged);
    _syncIndex();

    widget.playerService.player.processingStateStream.listen((state) {
      if (!mounted) return;
      if (state == ProcessingState.completed &&
          widget.playerService.repeatMode == RepeatMode.none) {
        _playNext();
      }
    });
  }

  @override
  void dispose() {
    widget.queueNotifier.removeListener(_onQueueChanged);
    widget.playerService.removeListener(_onVideoChanged);
    super.dispose();
  }

  void _onQueueChanged() {
    if (!mounted) return;
    setState(() => _syncIndex());
  }

  // Called whenever the playing video changes — refreshes lyrics if panel is open
  void _onVideoChanged() {
    if (!mounted) return;
    if (_showLyrics) _fetchLyrics();
    setState(() {});
  }

  void _syncIndex() {
    final currentVideo = widget.playerService.currentVideo;
    if (currentVideo == null) return;
    final idx = widget.queueNotifier.value.indexWhere(
      (v) => v.id == currentVideo.id,
    );
    _currentIndex = idx == -1 ? 0 : idx;
  }

  void _playNext() {
    final queue = widget.queueNotifier.value;
    if (_currentIndex + 1 < queue.length) {
      QueueManager().playingFromQueue = true;
      _currentIndex++;
      widget.playerService.setCurrentVideoPlayingFrom('queue');
      widget.playerService.setPlayingDeezerTrackId(
        queue[_currentIndex].id.toString(),
      );
      widget.playerService.play(queue[_currentIndex]);
      widget.searchService.buildQueueInBackground(queue[_currentIndex]);
      if (mounted) setState(() {});
    }
  }

  void _playPrevious() {
    final queue = widget.queueNotifier.value;
    if (_currentIndex - 1 >= 0) {
      QueueManager().playingFromQueue = true;
      _currentIndex--;
      widget.playerService.setCurrentVideoPlayingFrom('queue');
      widget.playerService.setPlayingDeezerTrackId(
        queue[_currentIndex].id.toString(),
      );
      widget.playerService.play(queue[_currentIndex]);
      widget.searchService.buildQueueInBackground(queue[_currentIndex]);
      if (mounted) setState(() {});
    }
  }

  Future<void> _fetchLyrics() async {
    final current = widget.playerService.currentVideo;
    if (current == null) return;

    final candidates = YouTubeCleaner.parseCandidates(
      current.title,
      current.author,
    );
    print('===MYLOG=== Trying ${candidates.length} candidates for lyrics');

    for (final (artist, title) in candidates) {
      print('===MYLOG=== Trying: "$title" by "$artist"');
      final lyrics = await LyricsService.getLyricsByTitle(
        artist,
        title,
        current.duration?.inSeconds,
      );
      if (lyrics != null && mounted) {
        print('===MYLOG=== Lyrics found for: "$title" by "$artist"');
        setState(() {
          _currentLyrics =
              lyrics['syncedLyrics'] ?? lyrics['plainLyrics'] ?? '';
        });
        return;
      }
    }

    if (mounted) {
      setState(() => _currentLyrics = '');
      print('===MYLOG=== No lyrics found for any candidate');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentVideo = widget.playerService.currentVideo;
    final queueList = widget.queueNotifier.value;
    // Queue is still loading if there's only the seed video and generation is ongoing
    final bool queueLoading =
        widget.searchService.isBuildingQueue || queueList.length <= 1;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 27, 17, 26),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
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
        title: const Text(
          'Now Playing...',
          style: TextStyle(
            color: Color.fromARGB(255, 169, 240, 234),
            fontSize: 15,
          ),
        ),
      ),
      body: Column(
        children: [
          // Artwork + controls
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(left: 10, right: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: const Border(
                bottom: BorderSide(
                  color: Color.fromARGB(186, 205, 248, 241),
                  width: 1.5,
                ),
                top: BorderSide(
                  color: Color.fromARGB(186, 205, 248, 241),
                  width: 0.5,
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 400,
                child: Stack(
                  children: [
                    // ---- Background image ----
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.fromARGB(255, 27, 17, 26),
                            Colors.transparent,
                          ],
                          stops: [0, 2],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: Transform.scale(
                        scaleY: 1.8,
                        scaleX: 1.2,
                        //offset: const Offset(0, -50),
                        child: Opacity(
                          opacity: 0.5,
                          child: CachedNetworkImage(
                            imageUrl:
                                currentVideo?.thumbnails.highResUrl ??
                                currentVideo?.thumbnails.standardResUrl ??
                                '',
                            fit: BoxFit.fill,
                            height: double.infinity,
                            errorWidget: (context, url, error) => Container(
                              color: const Color.fromARGB(255, 27, 17, 26),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ---- Gradient overlay (darkens bottom) ----
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color.fromARGB(
                              220,
                              27,
                              17,
                              26,
                            ), // solid dark at bottom
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                    // ---- Content on top ----
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 25),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Color.fromARGB(255, 161, 209, 211),
                            ),
                          ),
                          child: ClipOval(
                            child: Transform.scale(
                              scale: 1.35,
                              child: CachedNetworkImage(
                                height: 180,
                                width: 180,
                                imageUrl:
                                    currentVideo?.thumbnails.highResUrl ??
                                    currentVideo?.thumbnails.standardResUrl ??
                                    '',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Padding(
                          padding: const EdgeInsets.only(left: 20, right: 20),
                          child: Text(
                            currentVideo?.title ?? 'Unknown title',
                            style: const TextStyle(
                              color: Color.fromARGB(255, 205, 248, 241),
                              fontSize: 17,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          currentVideo?.author ?? 'Unknown artist',
                          style: const TextStyle(
                            color: Color.fromARGB(255, 186, 172, 187),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // ---- Progress bar ----
                        StreamBuilder<Duration>(
                          stream: widget.playerService.player.positionStream,
                          builder: (context, snapshot) {
                            final position = snapshot.data ?? Duration.zero;
                            return StreamBuilder<Duration?>(
                              stream:
                                  widget.playerService.player.durationStream,
                              builder: (context, snapDuration) {
                                final duration =
                                    snapDuration.data ?? Duration.zero;
                                return SizedBox(
                                  width: 320,
                                  child: ProgressBar(
                                    thumbGlowColor: const Color.fromARGB(
                                      202,
                                      181,
                                      169,
                                      182,
                                    ).withValues(alpha: 0.5),
                                    barHeight: 3,
                                    progress: position,
                                    total: duration,
                                    onSeek: (pos) =>
                                        widget.playerService.player.seek(pos),
                                    progressBarColor: const Color.fromARGB(
                                      255,
                                      156,
                                      236,
                                      232,
                                    ),
                                    baseBarColor: const Color.fromARGB(
                                      202,
                                      181,
                                      169,
                                      182,
                                    ),
                                    thumbColor: const Color.fromARGB(
                                      255,
                                      156,
                                      236,
                                      232,
                                    ),
                                    timeLabelLocation: TimeLabelLocation.sides,
                                    timeLabelTextStyle: const TextStyle(
                                      color: Color.fromARGB(255, 245, 205, 248),
                                      fontSize: 12,
                                    ),
                                    thumbRadius: 4.5,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        // ---- Controls ----
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () {},
                              padding: const EdgeInsets.only(top: 1),
                              icon: const Icon(
                                Icons.thumb_up_alt_outlined,
                                size: 25,
                                color: Color.fromARGB(255, 236, 156, 226),
                              ),
                            ),
                            IconButton(
                              padding: const EdgeInsets.only(top: 4),
                              icon: Icon(
                                _showLyrics
                                    ? Icons.lyrics_sharp
                                    : Icons.lyrics_outlined,
                                size: 25,
                                color: const Color.fromARGB(255, 236, 156, 226),
                              ),
                              onPressed: () async {
                                if (_showLyrics) {
                                  setState(() => _showLyrics = false);
                                } else {
                                  _fetchLyrics();
                                  setState(() => _showLyrics = true);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.skip_previous,
                                size: 30,
                                color: Color.fromARGB(255, 236, 156, 226),
                              ),
                              onPressed: _playPrevious,
                            ),
                            IconButton(
                              icon: StreamBuilder<bool>(
                                stream: widget
                                    .playerService
                                    .player
                                    .playerStateStream
                                    .map((s) => s.playing),
                                initialData: false,
                                builder: (context, snapshot) {
                                  return Icon(
                                    (snapshot.data ?? false)
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    size: 38,
                                    color: const Color.fromARGB(
                                      255,
                                      236,
                                      156,
                                      226,
                                    ),
                                  );
                                },
                              ),
                              onPressed: () {
                                widget.playerService.player.playing
                                    ? widget.playerService.player.pause()
                                    : widget.playerService.player.play();
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.skip_next,
                                size: 30,
                                color: Color.fromARGB(255, 236, 156, 226),
                              ),
                              onPressed: _playNext,
                            ),
                            IconButton(
                              icon: Icon(
                                widget.playerService.repeatMode ==
                                        RepeatMode.one
                                    ? Icons.repeat_one
                                    : Icons.repeat,
                                color: const Color.fromARGB(255, 236, 156, 226),
                                size: 25,
                              ),
                              onPressed: () {
                                setState(() {
                                  widget.playerService.repeatMode =
                                      widget.playerService.repeatMode ==
                                          RepeatMode.none
                                      ? RepeatMode.one
                                      : RepeatMode.none;
                                  if (widget.playerService.repeatMode ==
                                          RepeatMode.none &&
                                      _showLyrics) {
                                    _fetchLyrics();
                                  }
                                  widget.playerService.player.setLoopMode(
                                    widget.playerService.repeatMode ==
                                            RepeatMode.one
                                        ? LoopMode.one
                                        : LoopMode.off,
                                  );
                                });
                              },
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(
                                Icons.playlist_add_outlined,
                                size: 30,
                                color: Color.fromARGB(255, 236, 156, 226),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),
          // Queue header with live count + loading indicator
          Container(
            width: MediaQuery.of(context).size.width,
            padding: const EdgeInsets.only(bottom: 7, left: 13, right: 13),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color.fromARGB(137, 153, 245, 230),
                  width: 3.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Queue  (${queueList.length})',
                  style: const TextStyle(
                    color: Color.fromARGB(255, 156, 236, 229),
                    fontSize: 17,
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.69),
                if (queueLoading)
                  const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color.fromARGB(180, 156, 236, 229),
                    ),
                  ),
              ],
            ),
          ),
          // Queue list — always shows, grows as results come in
          Expanded(
            flex: 2,
            child: _showLyrics
                ? LyricsDisplay(
                    lyrics: _currentLyrics,
                    playerService: widget.playerService,
                  )
                : AnimatedList(
                    key: ValueKey(queueList.length), // cheap rebuild trigger
                    initialItemCount: queueList.length,
                    itemBuilder: (context, index, animation) {
                      if (index >= queueList.length) {
                        return const SizedBox.shrink();
                      }
                      final video = queueList[index];
                      final bool isCurrent = index == _currentIndex;
                      return SizeTransition(
                        sizeFactor: animation,
                        child: QueueItem(
                          video: video,
                          isCurrent: isCurrent,
                          onTap: () {
                            setState(() => _currentIndex = index);
                            widget.playerService.setCurrentVideoPlayingFrom(
                              'queue',
                            );
                            widget.playerService.setPlayingDeezerTrackId(
                              video.id.toString(),
                            );
                            QueueManager().playingFromQueue = true;
                            widget.searchService.buildQueueInBackground(video);
                            widget.playerService.play(video);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
