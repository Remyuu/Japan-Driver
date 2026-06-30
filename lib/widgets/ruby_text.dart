import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class RubySegment {
  const RubySegment(this.text, [this.ruby]);

  final String text;
  final String? ruby;

  bool get hasRuby => ruby != null && ruby!.isNotEmpty;
}

List<RubySegment> parseRubySegments(String? htmlSource, String fallback) {
  if (htmlSource == null || htmlSource.trim().isEmpty) {
    return [RubySegment(fallback)];
  }

  try {
    final fragment = html_parser.parseFragment(htmlSource);
    final segments = <RubySegment>[];

    void appendPlain(String text) {
      if (text.isEmpty) {
        return;
      }
      if (segments.isNotEmpty && !segments.last.hasRuby) {
        final previous = segments.removeLast();
        segments.add(RubySegment('${previous.text}$text'));
      } else {
        segments.add(RubySegment(text));
      }
    }

    void visit(dom.Node node) {
      if (node is dom.Text) {
        appendPlain(node.data);
        return;
      }
      if (node is! dom.Element) {
        return;
      }

      switch (node.localName) {
        case 'ruby':
          final ruby = node.children
              .where((child) => child.localName == 'rt')
              .map((child) => child.text.trim())
              .where((text) => text.isNotEmpty)
              .join();
          final base = node.nodes
              .where((child) {
                return child is! dom.Element ||
                    (child.localName != 'rt' && child.localName != 'rp');
              })
              .map((child) => child.text)
              .join()
              .trim();
          if (base.isNotEmpty) {
            segments.add(RubySegment(base, ruby.isEmpty ? null : ruby));
          }
          return;
        case 'rt':
        case 'rp':
          return;
        default:
          for (final child in node.nodes) {
            visit(child);
          }
      }
    }

    for (final node in fragment.nodes) {
      visit(node);
    }
    return segments.isEmpty ? [RubySegment(fallback)] : segments;
  } catch (_) {
    return [RubySegment(fallback)];
  }
}

class RubyText extends StatelessWidget {
  const RubyText({
    super.key,
    required this.text,
    this.rubyHtml,
    this.style,
    this.rubyStyle,
    this.textAlign,
    this.showRuby = true,
  });

  final String text;
  final String? rubyHtml;
  final TextStyle? style;
  final TextStyle? rubyStyle;
  final TextAlign? textAlign;
  final bool showRuby;

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(
      context,
    ).style.merge(style).copyWith(height: 1.42);
    if (!showRuby) {
      return Text(text, style: baseStyle, textAlign: textAlign);
    }

    final segments = parseRubySegments(rubyHtml, text);
    final smallStyle =
        rubyStyle ??
        baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 16) * 0.48,
          height: 1.0,
          color: baseStyle.color?.withValues(alpha: 0.72),
        );

    if (segments.every((segment) => !segment.hasRuby)) {
      return Text(text, style: baseStyle, textAlign: textAlign);
    }

    return Wrap(
      spacing: 0,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.end,
      alignment: switch (textAlign) {
        TextAlign.center => WrapAlignment.center,
        TextAlign.right || TextAlign.end => WrapAlignment.end,
        _ => WrapAlignment.start,
      },
      children: [
        for (final segment in segments)
          if (!segment.hasRuby)
            for (final rune in segment.text.runes)
              Text(String.fromCharCode(rune), style: baseStyle)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(segment.ruby!, style: smallStyle),
                  Text(segment.text, style: baseStyle),
                ],
              ),
            ),
      ],
    );
  }
}
