/*import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() => runApp(MusicApp());

class MusicApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player',
      theme: ThemeData.light().copyWith(
        primaryColor: const Color.fromARGB(255, 133, 44, 38),
        scaffoldBackgroundColor: const Color.fromARGB(255, 39, 36, 34),
        appBarTheme: AppBarTheme(backgroundColor: Colors.black, elevation: 0),
      ),
      home: SearchScreen(),
    );
  }
}

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();

  List<Video> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  final AudioPlayer _player = AudioPlayer();
  Video? _currentVideo;
  bool _isPlaying = false;
  bool _isBuffering = false;

  String? _loadingVideoId; // store video ID as string

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    try {
      var results = await _yt.search.getVideos(query);
      setState(() {
        _searchResults = results.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    }
  }

  Future<void> _playVideo(Video video) async {
    String videoId = video.id.toString(); // convert to string
    setState(() {
      _loadingVideoId = videoId;
      _currentVideo = video;
      _isBuffering = true;
      _isPlaying = false;
    });

    await _player.stop();

    try {
      var manifest = await _yt.videos.streamsClient.getManifest(video.id);
      var stream = manifest.muxed.firstWhere(
        (s) => s.bitrate != null,
        orElse: () => manifest.muxed.first,
      );
      var audioUrl = stream.url.toString();

      await _player.setUrl(audioUrl);
      await _player.play();

      setState(() {
        _isBuffering = false;
        _isPlaying = true;
        _loadingVideoId = null;
      });
    } catch (e) {
      setState(() {
        _isBuffering = false;
        _isPlaying = false;
        _loadingVideoId = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Playback error: $e')));
    }
  }

  void _pause() async {
    await _player.pause();
    setState(() => _isPlaying = false);
  }

  void _resume() async {
    await _player.play();
    setState(() => _isPlaying = true);
  }

  void _stop() async {
    await _player.stop();
    setState(() {
      _isPlaying = false;
      _currentVideo = null;
      _isBuffering = false;
      _loadingVideoId = null;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('music_app'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      color: const Color.fromARGB(255, 253, 237, 237),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search songs, artists...',
                      hintStyle: TextStyle(
                        color: const Color.fromARGB(255, 146, 112, 112),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      fillColor: const Color.fromARGB(255, 71, 64, 64),
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: _search,
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.search,
                    color: const Color.fromARGB(255, 255, 77, 77),
                  ),
                  onPressed: () => _search(_searchController.text),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildResults()),
          if (_currentVideo != null) _buildMiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (!_hasSearched) {
      return Center(
        child: Text(
          '🔍 Search for your favourite music',
          style: TextStyle(color: Colors.grey[500], fontSize: 16),
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 80),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        var video = _searchResults[index];
        String author = video.author ?? 'Unknown artist';
        String videoId = video.id.toString();
        bool isLoadingThis = _loadingVideoId == videoId;
        bool isCurrent = _currentVideo?.id.toString() == videoId;

        return ListTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 29, 28, 28),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.music_note,
              color: const Color.fromARGB(255, 119, 83, 83),
            ),
          ),
          title: Text(
            video.title,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent
                  ? const Color.fromARGB(255, 255, 77, 77)
                  : const Color.fromARGB(255, 248, 220, 220),
            ),
          ),
          subtitle: Text(author),
          trailing: isLoadingThis
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  isCurrent ? Icons.equalizer : Icons.play_arrow,
                  color: isCurrent
                      ? const Color.fromARGB(255, 255, 83, 77)
                      : null,
                ),
          onTap: () => _playVideo(video),
        );
      },
    );
  }

  Widget _buildMiniPlayer() {
    String author = _currentVideo!.author ?? 'Unknown artist';

    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 29, 28, 28),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 29, 28, 28),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.music_note,
              color: const Color.fromARGB(255, 119, 83, 83),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentVideo!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color.fromARGB(255, 206, 203, 203),
                  ),
                ),
              ],
            ),
          ),
          if (_isBuffering)
            Container(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Row(
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _isPlaying ? _pause : _resume,
                  color: const Color.fromARGB(255, 255, 77, 77),
                ),
                IconButton(
                  icon: Icon(Icons.stop),
                  onPressed: _stop,
                  color: const Color.fromARGB(255, 119, 83, 83),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
*/
