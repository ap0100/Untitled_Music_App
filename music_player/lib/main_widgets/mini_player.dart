import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/cyberpunk.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

class MiniPlayer extends StatelessWidget {
  final Video? video;
  final AudioPlayer player;
  final VoidCallback onTap;
  final Color? darkened;
  final bool searchFocused;
  final bool artistProfileFocused;

  const MiniPlayer({
    super.key,
    required this.player,
    required this.video,
    required this.onTap,
    required this.darkened,
    required this.searchFocused,
    required this.artistProfileFocused,
  });

  @override
  Widget build(BuildContext context) {
    if (video == null) return SizedBox.shrink();

    var borderColor = searchFocused
        ? CyberpunkTheme.deepCerise
        : artistProfileFocused
        ? CyberpunkTheme
              .tyrianPurple //Color.fromARGB(255, 124, 78, 120)
        : CyberpunkTheme.brightTurquoise;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ClipPath(
            clipper: MiniPlayerClipper(offset: 1.3),
            child: Container(
              height: 85,
              color: borderColor.withValues(alpha: 0.8),
            ),
          ),
          ClipPath(
            clipper: MiniPlayerClipper(),
            child: Transform.translate(
              offset: Offset(0, 5),
              child: Container(
                padding: EdgeInsets.only(right: 1.5),
                height: 85,
                color: CyberpunkTheme.dark.withValues(alpha: 0.95),
                /*decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      //Color.fromARGB(255, 15, 20, 20),
                      (CyberpunkTheme.darkWarm).withValues(alpha: 0.95),
                      (CyberpunkTheme.darkCold).withValues(
                        alpha: 0.9,
                      ), //Color.fromARGB(255, 34, 28, 46),
                    ],
                    stops: [0.3, 1.5],
                  ),
                ),*/
                child: Row(
                  spacing: 0,
                  children: [
                    Stack(
                      children: [
                        ClipPath(
                          clipper: MiniPlayerClipper(cover: true, offset: 1.3),
                          child: Container(
                            width: 106,
                            height: 80,
                            color: borderColor.withValues(alpha: 0.95),
                          ),
                        ),
                        ClipPath(
                          clipper: MiniPlayerClipper(cover: true),
                          //margin: const EdgeInsets.only(left: 4, right: 10),
                          child: CachedNetworkImage(
                            imageUrl:
                                video?.thumbnails.highResUrl ??
                                video?.thumbnails.standardResUrl ??
                                '',
                            width: 106,
                            height: 80,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Image.asset(
                              'lib/graphics/no_thumbnail_found.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(height: 29),
                          SizedBox(
                            child: Text(
                              video!.title,
                              style: TextStyle(
                                color: CyberpunkTheme.shimmerPink.withValues(
                                  alpha: 1,
                                ), // const Color.fromARGB(255, 205, 248, 241),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(height: 10),
                          StreamBuilder<Duration>(
                            stream: player.positionStream,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              return StreamBuilder<Duration?>(
                                stream: player.durationStream,
                                builder: (context, snapDuration) {
                                  final duration =
                                      snapDuration.data ?? Duration.zero;
                                  return SizedBox(
                                    width: 320,
                                    child: ProgressBar(
                                      thumbGlowColor: CyberpunkTheme
                                          .turquoiseGreen
                                          .withValues(alpha: 0.5),
                                      barHeight: 1.5,
                                      progress: position,
                                      total: duration,
                                      onSeek: (pos) => player.seek(pos),
                                      progressBarColor: CyberpunkTheme
                                          .brightTurquoise
                                          .withValues(alpha: 1),
                                      baseBarColor: CyberpunkTheme.tyrianPurple
                                          .withValues(alpha: 1),
                                      thumbColor: CyberpunkTheme.brightTurquoise
                                          .withValues(alpha: 1),
                                      timeLabelLocation:
                                          TimeLabelLocation.sides,
                                      timeLabelTextStyle: const TextStyle(
                                        color: CyberpunkTheme.mainFontColor,
                                        fontSize: 10,
                                      ),
                                      thumbRadius: 3,
                                      thumbGlowRadius: 12,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10),
                    IconButton(
                      padding: EdgeInsets.only(left: 20, top: 10),
                      icon: StreamBuilder<bool>(
                        stream: player.playerStateStream
                            .map((state) => state.playing)
                            .distinct(),
                        initialData: player.playing,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data ?? false;
                          return Icon(
                            isPlaying
                                ? Icons.pause_circle_filled_sharp
                                : Icons.play_circle_outline_sharp,
                            size: 28,
                            color: borderColor,
                          );
                        },
                      ),
                      onPressed: () {
                        player.playing ? player.pause() : player.play();
                      },
                    ),
                    IconButton(
                      padding: EdgeInsets.only(top: 10),
                      onPressed: onTap,
                      icon: Icon(
                        Icons.arrow_upward,
                        color: CyberpunkTheme
                            .violetBlue, //Color.fromARGB(255, 227, 156, 236),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
