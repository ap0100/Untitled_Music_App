import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:cached_network_image/cached_network_image.dart';

class QueueManager {
  bool playingFromQueue = false;
  static final QueueManager _instance = QueueManager._internal();
  factory QueueManager() => _instance;
  QueueManager._internal();

  final ValueNotifier<List<Video>> queueNotifier = ValueNotifier([]);

  void updateQueue(List<Video> newQueue) {
    queueNotifier.value = List.unmodifiable(newQueue);
  }

  void addToQueue(Video video) {
    queueNotifier.value = List.unmodifiable([...queueNotifier.value, video]);
  }

  void refresh() {
    playingFromQueue = false;
    queueNotifier.value = [];
  }

  void dispose() {
    queueNotifier.dispose();
  }
}

class QueueItem extends StatelessWidget {
  final Video? video;
  final bool isCurrent;
  final VoidCallback onTap;

  const QueueItem({
    super.key,
    required this.video,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(left: 10),
        height: 55,
        decoration: BoxDecoration(
          border: const Border(
            bottom: BorderSide(
              color: Color.fromARGB(184, 129, 109, 131),
              width: 2,
            ),
          ),
          color: isCurrent
              ? const Color.fromARGB(255, 108, 77, 109)
              : Colors.transparent,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color.fromARGB(144, 243, 205, 248),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(4)),
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
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 250,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video?.title ?? 'Unknown Title',
                    style: TextStyle(
                      color: isCurrent
                          ? const Color.fromARGB(255, 191, 245, 240)
                          : const Color.fromARGB(255, 180, 148, 180),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    video?.author ?? 'Unknown Author',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 194, 126, 194),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 30),
            IconButton(
              icon: Icon(
                Icons.menu_sharp,
                color: Color.fromARGB(188, 248, 205, 246),
              ),
              iconSize: 20,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
