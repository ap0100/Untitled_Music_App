import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/player.dart';
import '../utils/transliterate.dart';
import 'dart:async';

class LyricsService {
  static const String baseUrl = 'https://lrclib.net/api';

  static Future<Map<String, dynamic>?> getLyricsByTitle(
    String artist,
    String title,
    int? duration,
  ) async {
    try {
      print("===MYLOG=== LyricsService: fetching '$title' by '$artist'");

      final getUri = Uri.parse(
        '$baseUrl/get?artist_name=${Uri.encodeComponent(transliterate(artist))}&track_name=${Uri.encodeComponent(transliterate(title))}',
      );
      final getResp = await http
          .get(getUri)
          .timeout(const Duration(seconds: 5));
      if (getResp.statusCode == 200) {
        final data = jsonDecode(getResp.body) as Map<String, dynamic>;
        if (!data.containsKey('statusCode') &&
            _artistMatches(data['artistName'], artist) &&
            _titleMatches(data['trackName'], title)) {
          print("===MYLOG=== Lyrics: /get matched");
          return data;
        }
      }

      final searchUri = Uri.parse(
        '$baseUrl/search?artist_name=${Uri.encodeComponent(transliterate(artist))}&track_name=${Uri.encodeComponent(transliterate(title))}',
      );
      final searchResp = await http
          .get(searchUri)
          .timeout(const Duration(seconds: 5));
      if (searchResp.statusCode == 200) {
        final results = jsonDecode(searchResp.body) as List;
        for (final r in results) {
          final map = r as Map<String, dynamic>;
          if (_artistMatches(map['artistName'], transliterate(artist)) &&
              _titleMatches(map['trackName'], transliterate(title))) {
            print("===MYLOG=== Lyrics: search matched");
            return map;
          }
        }
      }

      print("===MYLOG=== Lyrics: no match found");
      return null;
    } catch (e) {
      print('===MYLOG=== Lyrics fetch error: $e');
      return null;
    }
  }

  static bool _artistMatches(dynamic returned, String query) {
    if (returned == null) return false;
    final r = (returned as String).toLowerCase().trim();
    final q = query.toLowerCase().trim();
    if (r == q) return true;
    return r.contains(q) || q.contains(r);
  }

  static bool _titleMatches(dynamic returned, String query) {
    if (returned == null) return false;
    final r = (returned as String).toLowerCase().trim();
    final q = query.toLowerCase().trim();
    if (r == q) return true;
    if (q.length < 4) return r == q;
    return r.contains(q) || q.contains(r);
  }

  List<MapEntry<Duration, String>> parseSyncedLyrics(String lrc) {
    final lines = lrc.split('\n');
    final entries = <MapEntry<Duration, String>>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final firstClosedBracket = line.indexOf(']');
      if (firstClosedBracket == -1) continue;
      final timeStamp = line.substring(1, firstClosedBracket);
      final text = line.substring(firstClosedBracket + 1).trim();
      if (text.isEmpty) continue;
      final parts = timeStamp.split(':');
      if (parts.length != 2) continue;
      final mins = int.tryParse(parts[0]) ?? 0;
      final secsPart = parts[1].split('.');
      if (secsPart.length != 2) continue;
      final secs = int.tryParse(secsPart[0]) ?? 0;
      final millis = int.tryParse(secsPart[1]) ?? 0;
      final time = Duration(minutes: mins, seconds: secs, milliseconds: millis);
      entries.add(MapEntry(time, text));
    }

    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }
}

class LyricsDisplay extends StatefulWidget {
  final String lyrics;
  final PlayerService playerService;

  const LyricsDisplay({
    super.key,
    required this.lyrics,
    required this.playerService,
  });

  @override
  State<LyricsDisplay> createState() => _LyricsDisplayState();
}

class _LyricsDisplayState extends State<LyricsDisplay> {
  bool syncedLyrics = false;
  List<MapEntry<Duration, String>> _entries = [];
  Duration _currentPos = Duration.zero;
  int _currentIndex = -1;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Duration>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _parseLyrics();

    // Set initial position immediately
    _currentPos = widget.playerService.player.position;
    _updateIndex();

    // Listen to position changes
    _positionSubscription = widget.playerService.player.positionStream.listen((
      pos,
    ) {
      if (!mounted) return;
      setState(() {
        _currentPos = pos;
        _updateIndex();
      });
      // Defer scroll until after the rebuild so controller is attached
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToCurrentLine();
      });
    });

    // Force a scroll after the first frame (controller will be attached)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToCurrentLine();
      }
    });
  }

  @override
  void didUpdateWidget(LyricsDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics != widget.lyrics) {
      _parseLyrics();
      _currentPos = widget.playerService.player.position;
      _updateIndex();
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToCurrentLine();
        }
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _parseLyrics() {
    final hasTimestamps = RegExp(
      r'\[\d{2}:\d{2}\.\d{2,3}\]',
    ).hasMatch(widget.lyrics);
    if (hasTimestamps) {
      syncedLyrics = true;
      _entries = LyricsService().parseSyncedLyrics(widget.lyrics);
    } else {
      syncedLyrics = false;
    }
  }

  void _updateIndex() {
    int idx = -1;
    for (int i = 0; i < _entries.length; i++) {
      if (_entries[i].key <= _currentPos) idx = i;
    }
    _currentIndex = idx;
  }

  void _scrollToCurrentLine() {
    if (_currentIndex < 0 || _currentIndex >= _entries.length) return;
    if (!_scrollController.hasClients) {
      // Controller not attached yet – retry after a short delay
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _scrollToCurrentLine();
        }
      });
      return;
    }
    final double lineHeight = 29;
    final double viewport = _scrollController.position.viewportDimension;
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double target =
        (_currentIndex * lineHeight) - (viewport / 2) + (lineHeight / 2);
    _scrollController.animateTo(
      target.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.isEmpty) {
      return const Center(
        child: Text(
          'No lyrics found.',
          style: TextStyle(color: Color.fromARGB(118, 250, 162, 253)),
        ),
      );
    }

    if (!syncedLyrics) {
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: widget.lyrics.split('\n').length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              widget.lyrics.split('\n')[index],
              style: const TextStyle(
                color: Color.fromARGB(255, 229, 205, 248),
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          );
        },
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final active = _currentPos >= entry.key && index == _currentIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            entry.value,
            style: TextStyle(
              color: active
                  ? const Color.fromARGB(235, 210, 250, 247)
                  : const Color.fromARGB(186, 205, 248, 241),
              fontSize: 15,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
