class ParsedSentence {
  final int index;
  final int startTimeMs;
  final int endTimeMs;
  final String text;

  ParsedSentence({
    required this.index,
    required this.startTimeMs,
    required this.endTimeMs,
    required this.text,
  });
}

class SrtParseError {
  final int lineNumber;
  final String content;
  final String message;

  SrtParseError({
    required this.lineNumber,
    required this.content,
    required this.message,
  });
}

class SrtParseResult {
  final List<ParsedSentence> entries;
  final List<SrtParseError> errors;

  SrtParseResult({required this.entries, required this.errors});
}

class SrtParser {
  static List<ParsedSentence> parse(String input) {
    return parseWithErrors(input).entries;
  }

  static SrtParseResult parseWithErrors(String input) {
    final entries = <ParsedSentence>[];
    final errors = <SrtParseError>[];

    if (input.trim().isEmpty) {
      return SrtParseResult(entries: entries, errors: errors);
    }

    final blocks = input.trim().split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final lines = block.split('\n');
      if (lines.length < 2) {
        errors.add(SrtParseError(
          lineNumber: 0,
          content: block,
          message: 'Block has fewer than 2 lines',
        ));
        continue;
      }

      final indexLine = lines[0].trim();
      final index = int.tryParse(indexLine);
      if (index == null) {
        errors.add(SrtParseError(
          lineNumber: 1,
          content: indexLine,
          message: 'Invalid index: "$indexLine"',
        ));
        continue;
      }

      final timeLine = lines.length > 1 ? lines[1].trim() : '';
      final timeRegex = RegExp(
        r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})',
      );
      final timeMatch = timeRegex.firstMatch(timeLine);
      if (timeMatch == null) {
        errors.add(SrtParseError(
          lineNumber: 2,
          content: timeLine,
          message: 'Invalid timestamp: "$timeLine"',
        ));
        continue;
      }

      final startMs = _parseTimestamp(
        timeMatch.group(1)!, timeMatch.group(2)!, timeMatch.group(3)!, timeMatch.group(4)!,
      );
      final endMs = _parseTimestamp(
        timeMatch.group(5)!, timeMatch.group(6)!, timeMatch.group(7)!, timeMatch.group(8)!,
      );

      final rawText = lines.length > 2
          ? lines.sublist(2).join('\n').trim()
          : '';

      // Strip HTML tags (e.g. <font color="#ffff00"><i>word</i></font>)
      final text = rawText.replaceAll(RegExp(r'<[^>]+>'), '');

      entries.add(ParsedSentence(
        index: index,
        startTimeMs: startMs,
        endTimeMs: endMs,
        text: text,
      ));
    }

    return SrtParseResult(entries: entries, errors: errors);
  }

  static int _parseTimestamp(String h, String m, String s, String ms) {
    return int.parse(h) * 3600000 +
        int.parse(m) * 60000 +
        int.parse(s) * 1000 +
        int.parse(ms);
  }
}
