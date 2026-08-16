import 'package:flutter/material.dart';
import 'package:music_player/screens/album_view.dart';
import '../theme/jinx_style.dart';
import '../services/player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../screens/artist_profile.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ArtistDisplay extends StatelessWidget {
  final String? name;
  final String coverUrl;
  final String? artistId;
  final String? type;
  final List<dynamic> genre;
  final Map<String?, dynamic> span, area;

  const ArtistDisplay({
    super.key,
    required this.name,
    required this.coverUrl,
    required this.artistId,
    required this.type,
    required this.genre,
    required this.span,
    required this.area,
  });

  void _navigateToArtistProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtistProfile(
          artistName: name ?? 'Unknown Artist',
          artistImage: coverUrl,
          mbArtistId: artistId,
          genre: genre,
          type: type,
          span: span,
          area: area,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = coverUrl;
    return GestureDetector(
      onTap: () {
        _navigateToArtistProfile(context); // Replace 1 with actual artist ID
      },
      child: Container(
        padding: EdgeInsets.only(left: 10, right: 10, top: 5),
        child: Stack(
          children: [
            ClipPath(
              clipper: ArtistDisplayClipper(offset: 10),
              child: Transform.translate(
                offset: Offset(13, -1),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.92,
                  height: MediaQuery.of(context).size.height * 0.062,
                  color: JinxTheme.yellowish,
                ),
              ),
            ),
            ClipPath(
              clipper: ArtistDisplayClipper(offset: 1),
              child: Transform.translate(
                offset: Offset(0, 2),
                child: Container(
                  height: 55,
                  color: JinxTheme.yellowish,
                  margin: EdgeInsets.only(bottom: 5),
                ),
              ),
            ),
            ClipPath(
              clipper: ArtistDisplayClipper(),
              child: Container(
                height: 55,
                //padding: EdgeInsets.only(top: 5, bottom: 5, left: 7, right: 10),
                //margin: EdgeInsets.only(top: 5, bottom: 5, left: 7, right: 10),
                decoration: BoxDecoration(
                  //color: const Color.fromARGB(255, 23, 19, 31),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      JinxTheme.dark.withValues(alpha: 0.815),
                      JinxTheme.midnightExpress.withValues(alpha: 0.85),
                    ],
                    stops: [0, 1.5],
                  ),
                ),
                child: Row(
                  spacing: 10,
                  children: [
                    Stack(
                      children: [
                        ClipPath(
                          clipper: ArtistDisplayClipper(
                            cover: true,
                            offset: 1.5,
                          ),
                          child: Container(
                            height: 55,
                            width: 70,
                            color: JinxTheme.yellowish,
                          ),
                        ),
                        ClipPath(
                          clipper: ArtistDisplayClipper(cover: true),
                          child: SizedBox(
                            height: 55,
                            width: 70,
                            child: CachedNetworkImage(
                              imageUrl: thumbnail,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Image.asset(
                                'lib/graphics/no_thumbnail_found.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.53,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name ?? 'Unknown Artist',
                            style: const TextStyle(
                              color: JinxTheme.mainFontColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Artist',
                            style: const TextStyle(
                              color: JinxTheme.yellowish,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.only(left: 25),
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                      ),
                      color: JinxTheme.yellowish,
                      onPressed: () {
                        _navigateToArtistProfile(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlbumDisplay extends StatelessWidget {
  final title;
  final artistName;
  final coverUrl;
  final String? releaseGroupId;
  final String? primaryType;
  final List<dynamic> secondaryTypes;
  final String? disambiguation;
  final List<dynamic> tags;

  const AlbumDisplay({
    required this.title,
    required this.artistName,
    required this.coverUrl,
    required this.releaseGroupId,
    required this.primaryType,
    required this.secondaryTypes,
    required this.disambiguation,
    required this.tags,
  });

  void _navigateToAlbumProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumView(
          artistName: artistName ?? 'Unknown Artist',
          albumCover: coverUrl,
          albumName: title ?? 'Unknown Album',
          mbReleaseGroupId: releaseGroupId,
          primaryType: primaryType,
          secondaryTypes: secondaryTypes,
          disambiguation: disambiguation,
          tags: tags,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _navigateToAlbumProfile(context);
      },
      child: Container(
        padding: EdgeInsets.only(left: 10, right: 10, top: 5),
        child: Stack(
          children: [
            ClipPath(
              clipper: AlbumDisplayClipper(offset: 10),
              child: Transform.translate(
                offset: Offset(13, -1),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.92,
                  height: MediaQuery.of(context).size.height * 0.062,
                  color: JinxTheme.turquoiseGreen,
                ),
              ),
            ),
            ClipPath(
              clipper: AlbumDisplayClipper(offset: 1),
              child: Transform.translate(
                offset: Offset(0, 2),
                child: Container(
                  height: 55,
                  color: JinxTheme.turquoiseGreen,
                  margin: EdgeInsets.only(bottom: 5),
                ),
              ),
            ),
            ClipPath(
              clipper: AlbumDisplayClipper(),
              child: Container(
                height: 55,
                //margin: EdgeInsets.only(top: 1, bottom: 5, left: 5, right: 5),
                decoration: BoxDecoration(
                  //color: const Color.fromARGB(255, 23, 19, 31),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      JinxTheme.midnightExpressOpposite.withValues(
                        alpha: 0.815,
                      ),
                      JinxTheme.midnightExpress.withValues(alpha: 0.85),
                    ],
                    stops: [0.2, 1.5],
                  ),
                ),
                child: Row(
                  spacing: 10,
                  children: [
                    Stack(
                      children: [
                        Transform.translate(
                          offset: Offset(0.8, 0),
                          child: ClipPath(
                            clipper: AlbumDisplayClipper(
                              cover: true,
                              offset: 1,
                            ),
                            child: Container(
                              height: 55,
                              width: 70,
                              color: JinxTheme.turquoiseGreen,
                            ),
                          ),
                        ),
                        ClipPath(
                          clipper: AlbumDisplayClipper(cover: true),
                          child: SizedBox(
                            height: 55,
                            width: 70,
                            child: CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Image.asset(
                                'lib/graphics/no_thumbnail_found.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.55,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title ?? 'Unknown Album',
                            style: const TextStyle(
                              color: JinxTheme.mainFontColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Album',
                            style: const TextStyle(
                              color: JinxTheme.turquoiseGreen,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.only(left: 2.2),
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                      ),
                      color: JinxTheme.turquoiseGreen,
                      onPressed: () {
                        _navigateToAlbumProfile(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrackDisplay extends StatelessWidget {
  final Video? video;
  final String? deezerCoverUrl;
  final String? deezerTitle;
  final String? deezerArtist;
  final String? deezerTrackId; // Deezer track ID for correct isPlaying check
  final PlayerService playerService;
  final Color? bgColor;
  final Color? darkened;
  final VoidCallback? onPlay;

  const TrackDisplay({
    super.key,
    this.video,
    this.deezerCoverUrl,
    this.deezerTitle,
    this.deezerArtist,
    this.deezerTrackId,
    required this.playerService,
    required this.bgColor,
    required this.darkened,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    // Compare against Deezer ID (set on play) — YouTube video ID is unrelated
    final bool isPlaying =
        deezerTrackId != null &&
        playerService.playingDeezerTrackId == deezerTrackId &&
        playerService.currentVideoPlayingFrom == 'search_screen';
    final String thumbUrl =
        video?.thumbnails.highResUrl ??
        video?.thumbnails.standardResUrl ??
        deezerCoverUrl ??
        '../graphics/no_thumbnail_found.jpg';
    final String title = video?.title ?? deezerTitle ?? '';
    final String author = video?.author ?? deezerArtist ?? '';

    return GestureDetector(
      onTap: () => onPlay?.call(),
      child: Container(
        //height: 65,
        padding: EdgeInsets.only(top: 5, bottom: 5, left: 10, right: 10),
        child: Stack(
          children: [
            Transform.translate(
              offset: Offset(0, 5),
              child: ClipPath(
                clipper: TrackDisplayClipper(offset: 1),
                child: Container(
                  height: 51,
                  color: isPlaying
                      ? JinxTheme.violetBlue.withValues(alpha: 0.75)
                      : JinxTheme.brightTurquoise.withValues(
                          alpha: 0.7,
                        ) /* isPlaying
                    ? Color.fromARGB(255, 159, 135, 161)
                    : Color.fromARGB(184, 129, 109, 131)*/,
                ),
              ),
            ),
            ClipPath(
              clipper: TrackDisplayClipper(offset: 10),
              child: Transform.translate(
                offset: Offset(12.5, -1),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.927,
                  height: MediaQuery.of(context).size.height * 0.062,
                  color: isPlaying
                      ? JinxTheme.shimmerPink.withValues(alpha: 0.9)
                      : JinxTheme.brightTurquoise.withValues(alpha: 0.75),
                ),
              ),
            ),
            ClipPath(
              clipper: TrackDisplayClipper(),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.065,
                padding: EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: !isPlaying
                        ? [
                            JinxTheme.midnightExpressOpposite.withValues(
                              alpha: 0.85,
                            ),
                            JinxTheme.midnightExpress.withValues(alpha: 0.8),
                            //darkened!.withValues(alpha: 0.5), //0.35),
                            //Colors.transparent,
                          ]
                        : [
                            const Color.fromARGB(146, 5, 216, 219).withValues(
                              alpha: 0.6,
                            ), //const Color.fromARGB(118, 250, 162, 253),
                            JinxTheme.brightTurquoise.withValues(
                              alpha: 0.35,
                            ), //const Color.fromARGB(134, 162, 253, 248),
                          ],
                    stops: [0, 1.5],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        Transform.translate(
                          offset: Offset(4.5, 0.2),
                          child: ClipPath(
                            clipper: TrackDisplayClipper(
                              cover: true,
                              offset: 2,
                            ),
                            child: Container(
                              width: 90,
                              height: 65,
                              color: isPlaying
                                  ? JinxTheme.shimmerPink.withValues(
                                      alpha: 0.78,
                                    )
                                  : JinxTheme.brightTurquoise.withValues(
                                      alpha: 0.7,
                                    ),
                            ),
                          ),
                        ),
                        ClipPath(
                          clipper: TrackDisplayClipper(cover: true),
                          child: Container(
                            margin: EdgeInsets.only(right: 10),
                            width: 85,
                            height: 60,
                            child: CachedNetworkImage(
                              imageUrl: thumbUrl,
                              fit: BoxFit.cover,
                              errorWidget: ((context, url, error) =>
                                  Image.asset(
                                    'lib/graphics/no_thumbnail_found.jpg',
                                  )),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 9),
                          Text(
                            title,
                            style: TextStyle(
                              color: isPlaying
                                  ? JinxTheme.tyrianPurple.withValues(
                                      alpha: 0.8,
                                    )
                                  : JinxTheme.mainFontColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            author,
                            style: TextStyle(
                              color: isPlaying
                                  ? const Color.fromARGB(
                                      255,
                                      145,
                                      30,
                                      116,
                                    ).withValues(alpha: 0.95)
                                  : JinxTheme.brightTurquoise.withValues(
                                      alpha: 1,
                                    ),
                              fontSize: 11,
                              /*fontWeight: isPlaying
                                  ? FontWeight.bold
                                  : FontWeight.normal,*/
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10),
                    IconButton(
                      icon: Icon(
                        Icons.menu_sharp,
                        color: isPlaying
                            ? JinxTheme.tyrianPurple.withValues(alpha: 0.6)
                            : JinxTheme.shimmerPink.withValues(alpha: 0.7),
                      ),
                      iconSize: 20,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
