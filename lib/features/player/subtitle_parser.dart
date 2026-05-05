class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleCue({required this.start, required this.end, required this.text});
}

class SubtitleParser {
  static List<SubtitleCue> parse(String content) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.contains('WEBVTT')) return _parseVtt(normalized);
    return _parseSrt(normalized);
  }

  static List<SubtitleCue> _parseVtt(String content) {
    final cues = <SubtitleCue>[];
    final lines = content.split('\n');
    int i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.contains('-->')) {
        final arrowIndex = line.indexOf('-->');
        final startStr = line.substring(0, arrowIndex).trim();
        // VTT may have position cues after end time — take only the time part
        final endStr = line.substring(arrowIndex + 3).trim().split(' ').first;
        final start = _parseDuration(startStr);
        final end = _parseDuration(endStr);
        final textLines = <String>[];
        i++;
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          textLines.add(_stripTags(lines[i]));
          i++;
        }
        final text = textLines.where((l) => l.isNotEmpty).join('\n');
        if (text.isNotEmpty) {
          cues.add(SubtitleCue(start: start, end: end, text: text));
        }
      } else {
        i++;
      }
    }
    return cues;
  }

  static List<SubtitleCue> _parseSrt(String content) {
    final cues = <SubtitleCue>[];
    final blocks = content.trim().split(RegExp(r'\n\n+'));
    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 2) continue;
      // Find the timestamp line (it contains '-->') — skip the index line
      int tsIdx = 0;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('-->')) {
          tsIdx = i;
          break;
        }
      }
      if (!lines[tsIdx].contains('-->')) continue;
      final parts = lines[tsIdx].split('-->');
      final start = _parseDuration(parts[0].trim().replaceAll(',', '.'));
      final end = _parseDuration(parts[1].trim().replaceAll(',', '.'));
      final text = lines
          .sublist(tsIdx + 1)
          .map(_stripTags)
          .where((l) => l.isNotEmpty)
          .join('\n');
      if (text.isNotEmpty) {
        cues.add(SubtitleCue(start: start, end: end, text: text));
      }
    }
    return cues;
  }

  static Duration _parseDuration(String s) {
    s = s.trim();
    final parts = s.split(':');
    if (parts.length != 3) return Duration.zero;
    try {
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final secParts = parts[2].split('.');
      final sec = int.parse(secParts[0]);
      final ms = secParts.length > 1
          ? int.parse(secParts[1].padRight(3, '0').substring(0, 3))
          : 0;
      return Duration(hours: h, minutes: m, seconds: sec, milliseconds: ms);
    } catch (_) {
      return Duration.zero;
    }
  }

  static String _stripTags(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\{[^}]*\}'), '').trim();
}
