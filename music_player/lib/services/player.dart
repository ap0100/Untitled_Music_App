import 'package:flutter/material.dart' hide RepeatMode;
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../utils/repeat_mode.dart';

class PlayerService extends ChangeNotifier {
  // Singleton
  static final PlayerService _instance = PlayerService._internal();
  factory PlayerService() => _instance;
  PlayerService._internal();

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

  Future<String> fetchAudioUrl(Video video) async {
    var manifest = await _yt.videos.streamsClient.getManifest(video.id);
    var stream = manifest.muxed.first;
    return stream.url.toString();
  }

  Future<void> play(Video video) async {
    _currentVideo = video;
    _isBuffering = true;
    _isPlaying = false;
    notifyListeners(); // <-- immediately notify so mini player appears

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
