import 'package:flutter/material.dart' hide RepeatMode;
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../utils/repeat_mode.dart';
import '../services/queue_manager.dart';
import '../services/search.dart';

class PlayerService extends ChangeNotifier {
  static final PlayerService _instance = PlayerService._internal();
  factory PlayerService() => _instance;
  PlayerService._internal() {
    _initAutoplay();
  }

  final AudioPlayer _player = AudioPlayer();
  final YoutubeExplode _yt = YoutubeExplode();

  RepeatMode repeatMode = RepeatMode.none;

  Video? _currentVideo;
  bool _isPlaying = false;
  bool _isBuffering = false;
  String? _playingDeezerTrackId;
  String _currentVideoPlayingFrom = '';

  String get currentVideoPlayingFrom => _currentVideoPlayingFrom;
  String? get playingDeezerTrackId => _playingDeezerTrackId;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  Video? get currentVideo => _currentVideo;
  AudioPlayer get player => _player;

  void setPlayingDeezerTrackId(String? id) {
    _playingDeezerTrackId = id;
    notifyListeners();
  }

  void setCurrentVideoPlayingFrom(String fileName) {
    _currentVideoPlayingFrom = fileName;
    notifyListeners();
  }

  void _initAutoplay() {
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        print('===MYLOG=== Player completed, autoplaying next');
        _handleTrackEnd();
      }
    });
  }

  void _handleTrackEnd() {
    if (repeatMode == RepeatMode.one) return;

    final queue = QueueManager().queueNotifier.value;
    if (queue.isEmpty) return;

    int currentIndex = queue.indexWhere((v) => v.id == _currentVideo?.id);
    if (currentIndex == -1) currentIndex = 0;

    int nextIndex = currentIndex + 1;
    if (nextIndex >= queue.length) {
      // If queue ends, refill with more tracks
      print('===MYLOG=== Queue empty, refilling');
      SearchService().buildQueueInBackground(_currentVideo!);
      // Try again after a short delay (queue might be extended)
      Future.delayed(Duration(seconds: 1), () {
        final newQueue = QueueManager().queueNotifier.value;
        if (newQueue.length > 1) {
          final next = newQueue[1];
          _playQueuedTrack(next);
        }
      });
      return;
    }

    final nextVideo = queue[nextIndex];
    _playQueuedTrack(nextVideo);
  }

  Future<void> _playQueuedTrack(Video video) async {
    try {
      print('===MYLOG=== Playing queued track: ${video.title}');
      _currentVideo = video;
      _isBuffering = true;
      _isPlaying = false;
      _currentVideoPlayingFrom = 'queue';
      QueueManager().playingFromQueue = true;
      _playingDeezerTrackId = video.id.toString();
      notifyListeners();

      SearchService().buildQueueInBackground(video);

      final audioUrl = await fetchAudioUrl(video);
      await _player.setUrl(audioUrl);
      await _player.play();
      _isBuffering = false;
      _isPlaying = true;
      print('===MYLOG=== Autoplay started: ${video.title}');
    } catch (e, stack) {
      print('===MYLOG=== Autoplay error: $e, $stack');
      _isBuffering = false;
      _isPlaying = false;
    } finally {
      notifyListeners();
    }
  }

  Future<String> fetchAudioUrl(Video video) async {
    var manifest = await _yt.videos.streamsClient.getManifest(video.id);
    var stream = manifest.muxed.first;
    return stream.url.toString();
  }

  Future<void> play(Video video) async {
    _currentVideo = video;
    _isBuffering = true;
    _isPlaying = false;
    //_playingDeezerTrackId = video.id.toString();
    notifyListeners();

    await _player.stop();

    try {
      var audioUrl = await fetchAudioUrl(video);
      await _player.setUrl(audioUrl);
      await _player.play();
      _isBuffering = false;
      _isPlaying = true;
    } catch (e) {
      _isBuffering = false;
      _isPlaying = false;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    await _player.play();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    _currentVideo = null;
    _isBuffering = false;
    _playingDeezerTrackId = null;
    notifyListeners();
  }

  void setLoopMode(LoopMode mode) {
    _player.setLoopMode(mode);
  }

  @override
  void dispose() {
    _player.dispose();
    _yt.close();
    super.dispose();
  }
}
