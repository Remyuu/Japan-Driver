import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japan_driver/widgets/ruby_text.dart';

void main() {
  test('parses ruby segments', () {
    final segments = parseRubySegments(
      '<ruby><rb>黄色</rb><rp>(</rp><rt>きいろ</rt><rp>)</rp></ruby>の信号',
      'fallback',
    );

    expect(segments, hasLength(2));
    expect(segments.first.text, '黄色');
    expect(segments.first.ruby, 'きいろ');
    expect(segments.last.text, 'の信号');
  });

  test('falls back to plain text without ruby source', () {
    final segments = parseRubySegments(null, '黄色の信号');

    expect(segments, hasLength(1));
    expect(segments.single.text, '黄色の信号');
    expect(segments.single.ruby, isNull);
  });

  testWidgets('renders plain fallback text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RubyText(text: '黄色の信号')),
      ),
    );

    expect(find.byType(RichText), findsOneWidget);
  });
}
