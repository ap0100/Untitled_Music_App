import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/jinx_style.dart';

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
            clipper: MiniPlayerClipper(offset: 1.5),
            child: Container(
              height: 70,
              color: borderColor.withValues(alpha: 0.9),
            ),
          ),
          ClipPath(
            clipper: MiniPlayerClipper(),
            child: Transform.translate(
              offset: Offset(0, 5),
              child: Container(
                padding: EdgeInsets.only(right: 1.2),
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (JinxTheme.darkCold).withValues(
                        alpha: 0.95,
                      ), //Color.fromARGB(255, 15, 20, 20),
                      (JinxTheme.darkWarm).withValues(
                        alpha: 0.95,
                      ), //Color.fromARGB(255, 34, 28, 46),
                    ],
                    stops: [0, 1.5],
                  ),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        ClipPath(
                          clipper: MiniPlayerClipper(cover: true, offset: 0.9),
                          child: Container(
                            width: 106,
                            height: 60,
                            color: borderColor.withValues(alpha: 0.9),
                          ),
                        ),
                        ClipPath(
                          clipper: MiniPlayerClipper(cover: true),
                          child: SizedBox(
                            width: 106,
                            height: 60,
                            //margin: const EdgeInsets.only(left: 4, right: 10),
                            child: CachedNetworkImage(
                              imageUrl:
                                  video?.thumbnails.highResUrl ??
                                  video?.thumbnails.standardResUrl ??
                                  '',
                              fit: BoxFit.cover,
                              width: 90,
                              height: 100,
                              errorWidget: (context, url, error) => Image.asset(
                                'lib/graphics/no_thumbnail_found.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                            //),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 17),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: 60),
                        child: Text(
                          video!.title,
                          style: TextStyle(
                            color: JinxTheme
                                .violetBlue, // const Color.fromARGB(255, 205, 248, 241),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
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
                            size: 37,
                            color: borderColor,
                          );
                        },
                      ),
                      onPressed: () {
                        player.playing ? player.pause() : player.play();
                      },
                    ),
                    IconButton(
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
