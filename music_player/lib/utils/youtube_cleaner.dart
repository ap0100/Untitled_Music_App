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
}
