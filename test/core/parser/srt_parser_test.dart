import 'package:flutter_test/flutter_test.dart';
import 'package:srt_player/core/parser/srt_parser.dart';

void main() {
  group('SrtParser', () {
    test('parses valid single entry', () {
      const input = '1\n00:00:01,000 --> 00:00:03,500\nHello world';
      final result = SrtParser.parse(input);
      expect(result, hasLength(1));
      expect(result[0].index, 1);
      expect(result[0].startTimeMs, 1000);
      expect(result[0].endTimeMs, 3500);
      expect(result[0].text, 'Hello world');
    });

    test('parses multiple entries', () {
      const input =
          '1\n00:00:01,000 --> 00:00:03,500\nHello world\n\n'
          '2\n00:00:04,000 --> 00:00:06,000\nHow are you?';
      final result = SrtParser.parse(input);
      expect(result, hasLength(2));
      expect(result[1].index, 2);
      expect(result[1].startTimeMs, 4000);
    });

    test('handles multi-line text', () {
      const input = '1\n00:00:01,000 --> 00:00:03,500\nLine one\nLine two';
      final result = SrtParser.parse(input);
      expect(result[0].text, 'Line one\nLine two');
    });

    test('skips entries with invalid timestamps and reports errors', () {
      const input =
          '1\n00:00:01,000 --> 00:00:03,500\nGood entry\n\n'
          '2\ninvalid --> timestamp\nBad entry';
      final result = SrtParser.parse(input);
      expect(result, hasLength(1));
      expect(result[0].text, 'Good entry');
    });

    test('handles empty text gracefully', () {
      const input = '1\n00:00:01,000 --> 00:00:03,500\n';
      final result = SrtParser.parse(input);
      expect(result, hasLength(1));
      expect(result[0].text, isEmpty);
    });

    test('parses Chinese text correctly', () {
      const input = '1\n00:00:01,000 --> 00:00:03,500\n你好世界';
      final result = SrtParser.parse(input);
      expect(result[0].text, '你好世界');
    });

    test('returns empty list for empty input', () {
      final result = SrtParser.parse('');
      expect(result, isEmpty);
    });

    test('reports parse errors with line info', () {
      const input =
          '1\n00:00:01,000 --> 00:00:03,500\nGood\n\n'
          '2\nbad timestamp\nBad';
      final result = SrtParser.parseWithErrors(input);
      expect(result.entries, hasLength(1));
      expect(result.errors, isNotEmpty);
      expect(result.errors.first.lineNumber, greaterThan(0));
    });
  });
}
