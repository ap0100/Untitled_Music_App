import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player/services/player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/jinx_style.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

class MiniPlayer extends StatelessWidget {
  final Video? video;
  final AudioPlayer player;
  final VoidCallback onTap;
  final Color? darkened;
  final bool searchFocused;
  final bool artistProfileFocused;
  final PlayerService playerService = PlayerService();

  MiniPlayer({
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
        ? JinxTheme.deepCerise
        : artistProfileFocused
        ? JinxTheme
              .tyrianPurple //Color.fromARGB(255, 124, 78, 120)
        : JinxTheme.brightTurquoise;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ClipPath(
            clipper: MiniPlayerClipper(offset: 1.3),
            child: Container(
              height: 85,
              color: borderColor.withValues(alpha: 0.9),
            ),
          ),
          ClipPath(
            clipper: MiniPlayerClipper(),
            child: Transform.translate(
              offset: Offset(0, 5),
              child: Container(
                padding: EdgeInsets.only(right: 1.5),
                height: 85,
                color: JinxTheme.dark.withValues(alpha: 1),
                /*decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      //Color.fromARGB(255, 15, 20, 20),
                      (JinxTheme.darkWarm).withValues(alpha: 0.95),
                      (JinxTheme.darkCold).withValues(
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
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(height: 30),
                          Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Text(
                              video!.title,
                              style: TextStyle(
                                color: JinxTheme
                                    .violetBlue, // const Color.fromARGB(255, 205, 248, 241),
                                fontSize: 12.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(height: 9),
                          StreamBuilder<Duration>(
                            stream: playerService.player.positionStream,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              return StreamBuilder<Duration?>(
                                stream: playerService.player.durationStream,
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
                                      barHeight: 1.5,
                                      progress: position,
                                      total: duration,
                                      onSeek: (pos) =>
                                          playerService.player.seek(pos),
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
                                      timeLabelLocation:
                                          TimeLabelLocation.sides,
                                      timeLabelTextStyle: const TextStyle(
                                        color: Color.fromARGB(
                                          255,
                                          245,
                                          205,
                                          248,
                                        ),
                                        fontSize: 10,
                                      ),
                                      thumbRadius: 3,
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
                        color: JinxTheme
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
