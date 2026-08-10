import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(right: 1),
        height: 65,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: searchFocused
                  ? const Color.fromARGB(255, 216, 71, 221)
                  : artistProfileFocused
                  ? Color.fromARGB(255, 124, 78, 120)
                  : const Color.fromARGB(255, 40, 163, 163),
              width: 1,
            ),
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(5),
            topRight: Radius.circular(5),
          ),
          gradient: LinearGradient(
            begin: const Alignment(0.0, 0.2),
            end: const Alignment(0.0, 1.6),
            colors: const [
              Color.fromARGB(255, 15, 20, 20),
              Color.fromARGB(255, 34, 28, 46),
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              margin: EdgeInsets.only(top: 0, bottom: 0, left: 1, right: 0),
              width: 90,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(5)),
                border: Border(
                  right: BorderSide(
                    color: searchFocused
                        ? const Color.fromARGB(255, 216, 71, 221)
                        : artistProfileFocused
                        ? Color.fromARGB(255, 124, 78, 120)
                        : const Color.fromARGB(255, 40, 163, 163),
                    width: 1,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(5),
                  bottomLeft: Radius.circular(5),
                ),
                child: CachedNetworkImage(
                  imageUrl: video?.thumbnails.standardResUrl ?? '',
                  fit: BoxFit.cover,
                  width: 90,
                  height: 100,
                  errorWidget: (context, url, error) => Image.asset(
                    'lib/graphics/no_thumbnail_found.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            SizedBox(width: 17),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: 60),
                child: Text(
                  video!.title,
                  style: TextStyle(
                    color: Color.fromARGB(
                      255,
                      229,
                      185,
                      235,
                    ), // const Color.fromARGB(255, 205, 248, 241),
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
                    color: searchFocused
                        ? const Color.fromARGB(255, 216, 71, 221)
                        : artistProfileFocused
                        ? Color.fromARGB(255, 124, 78, 120)
                        : const Color.fromARGB(255, 40, 163, 163),
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
                color: Color.fromARGB(255, 227, 156, 236),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
