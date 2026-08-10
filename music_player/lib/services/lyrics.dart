import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/player.dart';
import '../utils/transliterate.dart';

class LyricsService {
  static const String baseUrl = 'https://lrclib.net/api';
  final PlayerService playerService = PlayerService();

  static Future<Map<String, dynamic>?> getLyricsByTitle(
    String artist,
    String title,
    int? duration,
  ) async {
    try {
      print("===MYLOG=== LyricsService: fetching '$title' by '$artist'");

      // 1. Exact lookup via /get
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

      // 2. Search and pick best match
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
    // One must contain the other (handles "Kygo" vs "Kygo & Ellie Goulding")
    return r.contains(q) || q.contains(r);
  }

  static bool _titleMatches(dynamic returned, String query) {
    if (returned == null) return false;
    final r = (returned as String).toLowerCase().trim();
    final q = query.toLowerCase().trim();
    if (r == q) return true;
    // The longer must contain the shorter — prevents "Love" matching "I Love Rock and Roll"
    if (q.length < 4) return r == q; // very short titles must be exact
    return r.contains(q) || q.contains(r);
  }

  List<MapEntry<Duration, String>> parseSyncedLyrics(String lrc) {
    final lines = lrc.split('\n');
    final entries = <MapEntry<Duration, String>>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final firstClosedBracket = line.indexOf(']');
      if (firstClosedBracket == -1) continue;

      final timeStamp = line.substring(1, firstClosedBracket),
          text = line.substring(firstClosedBracket + 1).trim();
      if (text.isEmpty) continue;

      final parts = timeStamp.split(':');
      if (parts.length != 2) continue;

      final mins = int.tryParse(parts[0]) ?? 0, secsPart = parts[1].split('.');
      if (secsPart.length != 2) continue;

      final secs = int.tryParse(secsPart[0]) ?? 0,
          millis = int.tryParse(secsPart[1]) ?? 0;

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
  int _currentIndex = -1;
  final ScrollController _scrollController = ScrollController();
  Duration? _currentPos = Duration.zero;

  @override
  void initState() {
    super.initState();
    _checkLyricType();
    if (syncedLyrics) {
      widget.playerService.player.positionStream.listen((pos) {
        setState(() {
          _currentPos = pos;
          _currentIndex = _currentLineIndex(pos);
        });
        _scrollToCurrentLine();
      });
    }
  }

  @override
  void didUpdateWidget(LyricsDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics != widget.lyrics) {
      // Lyrics changed – re-parse
      _checkLyricType();
      // Reset position listener if needed
      if (syncedLyrics) {
        _currentPos = Duration.zero;
        _currentIndex = -1;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkLyricType() {
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

  int _currentLineIndex(Duration pos) {
    int idx = -1;
    for (int i = 0; i < _entries.length; i++) {
      if (_entries[i].key <= pos) idx = i;
    }
    return idx;
  }

  void _scrollToCurrentLine() {
    if (_currentIndex < 0 || _currentIndex >= _entries.length) return;
    final double lineHeight = 29;
    final double centeredOffset =
        (_currentIndex * lineHeight) -
        (_scrollController.position.viewportDimension / 2) +
        (lineHeight / 2);
    _scrollController.animateTo(
      centeredOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.isEmpty) {
      return Center(
        child: Text(
          'No lyrics found.',
          style: TextStyle(color: const Color.fromARGB(118, 250, 162, 253)),
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
        final entry = _entries[index],
            active = _currentPos! > entry.key && index == _currentIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            entry.value,
            style: TextStyle(
              color: active
                  ? Color.fromARGB(235, 210, 250, 247)
                  : Color.fromARGB(186, 205, 248, 241),
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
