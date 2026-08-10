class YouTubeCleaner {
  /// Remove common video‑related tags from a title.
  static String cleanTitle(String title) {
    String t = title;
    t = t.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    t = t.replaceAll(RegExp(r'\[.*?\]'), '').trim();
    t = t.replaceAll(RegExp(r'- Topic$'), '').trim();
    t = t
        .replaceAll(
          RegExp(
            r'(Official|Music|Video|Audio|HD|4K|Lyrics|Cover|Remix|Live|Acoustic|Studio|Version|Clip|MV|VEVO)',
          ),
          '',
        )
        .trim();
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  /// Generate a search query for YouTube, optionally including country for disambiguation.
  static String generateSearchQuery(String artist, {String? country}) {
    var query = artist.trim();
    if (country != null && country.isNotEmpty) {
      query += ' $country';
    }
    return query;
  }

  /// Parse a YouTube video's title and author into a list of (artist, title) candidates.
  /// This is useful for lyrics lookups or when trying to identify the actual artist/title.
  static List<(String artist, String title)> parseCandidates(
    String rawTitle,
    String rawAuthor,
  ) {
    final candidates = <(String, String)>[];
    final cleanedRawAuthor = cleanTitle(rawAuthor);
    final cleanedRawTitle = cleanTitle(rawTitle);

    // ---- Strategy: Remove author from title if present ----
    if (rawTitle.toLowerCase().contains(rawAuthor.toLowerCase())) {
      String withoutAuthor = rawTitle
          .replaceAll(RegExp(rawAuthor, caseSensitive: false), '')
          .trim();
      withoutAuthor = withoutAuthor
          .replaceFirst(RegExp(r'^[-–]\s*'), '')
          .trim();
      if (withoutAuthor.isNotEmpty) {
        candidates.add((rawAuthor, withoutAuthor));
        final cleanedWithout = cleanTitle(withoutAuthor);
        if (cleanedWithout != withoutAuthor && cleanedWithout.isNotEmpty) {
          candidates.add((rawAuthor, cleanedWithout));
        }
      }
    }

    // ---- Strategy: Dash separation ----
    if (rawTitle.contains(' - ')) {
      final parts = rawTitle.split(' - ');
      final left = parts.first.trim();
      var right = parts.sublist(1).join(' - ').trim();
      right = cleanTitle(right);

      candidates.add((left, right)); // Artist - Title
      candidates.add((right, left)); // Title - Artist (swapped)
      if (cleanedRawAuthor != left) {
        candidates.add((cleanedRawAuthor, right)); // Author as artist
      }
      candidates.add((
        cleanedRawAuthor,
        cleanedRawTitle,
      )); // Author + cleaned title
    }

    // ---- Strategy: Raw author + raw/cleaned title (always) ----
    candidates.add((rawAuthor, rawTitle));
    if (cleanedRawTitle != rawTitle) {
      candidates.add((rawAuthor, cleanedRawTitle));
    }

    // ---- Remove duplicates and invalid entries ----
    final seen = <String>{};
    final unique = <(String, String)>[];
    for (final c in candidates) {
      final artist = c.$1.trim();
      final title = c.$2.trim();
      if (artist.isEmpty || title.isEmpty) continue;
      if (artist.toLowerCase() == title.toLowerCase()) continue;
      if (title.replaceAll(RegExp(r'[-–]\s*'), '').isEmpty) continue;
      final key = '$artist|$title';
      if (seen.add(key)) unique.add((artist, title));
    }
    return unique;
  }

  static String displayTitle(String rawTitle, String artistName) {
    String t = rawTitle;
    // Remove artist name if it appears at the start (case‑insensitive)
    final escaped = RegExp.escape(artistName);
    final pattern = RegExp('^$escaped[: -]+', caseSensitive: false);
    t = t.replaceFirst(pattern, '').trim();
    // Clean remaining tags
    t = cleanTitle(t);
    return t.isNotEmpty ? t : rawTitle; // fallback to raw if empty
  }

  static String normalizeForDedup(String title) {
    String t = cleanTitle(title);
    // Remove everything after the first dash or parenthesis
    int dash = t.indexOf(' - ');
    int paren = t.indexOf('(');
    int bracket = t.indexOf('[');
    int firstSeparator = [dash, paren, bracket]
        .where((pos) => pos > 0)
        .fold<int>(t.length, (min, pos) => pos < min ? pos : min);
    if (firstSeparator < t.length) {
      t = t.substring(0, firstSeparator);
    }
    t = t.replaceAll(RegExp(r'[^\w\s]'), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length > 30) t = t.substring(0, 30);
    return t.toLowerCase();
  }
}
