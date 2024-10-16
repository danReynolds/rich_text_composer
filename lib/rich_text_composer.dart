library rich_text_composer;

import 'package:flutter/material.dart';

typedef PlainTextBuilder = TextSpan Function(
  /// The unmatched plain text text substring from [startIndex] to [endIndex].
  String text, {
  /// The index of the start of the unmatched plain text in the string.
  required int startIndex,

  /// The index of the end of the unmatched plain text in the string.
  required int endIndex,
});

typedef PatternTextBuilder = InlineSpan Function(
  /// The matched text substring from [startIndex] to [endIndex].
  String text, {
  /// The index of the start of the match in the string.
  required int startIndex,

  /// The index of the end of the match in the string.
  required int endIndex,

  /// The index of the match. Whether it's the first 1st, 2nd, 3rd match etc.
  required int matchIndex,
});

TextSpan _defaultPlainTextBuilder(
  String text,
  TextStyle? style,
) {
  return TextSpan(text: text, style: style);
}

class RichTextPatternMatch {
  final int startIndex;
  final int endIndex;
  final String text;
  final InlineSpan child;

  RichTextPatternMatch({
    required this.startIndex,
    required this.endIndex,
    required this.child,
    required this.text,
  });
}

class RichTextPatternBuilder {
  final RegExp pattern;
  final PatternTextBuilder builder;
  final void Function(List<RichTextPatternMatch> matches)? onMatch;

  RichTextPatternBuilder({
    required this.pattern,
    required this.builder,
    this.onMatch,
  });

  factory RichTextPatternBuilder.basic(
    String patternText,
    InlineSpan Function() builder,
  ) {
    return RichTextPatternBuilder(
      pattern: RegExp(patternText),
      builder: (
        text, {
        required int startIndex,
        required int endIndex,
        required int matchIndex,
      }) {
        return builder();
      },
    );
  }
}

class RichTextComposer extends StatelessWidget {
  final List<RichTextPatternBuilder> richTextBuilders;

  final TextSpan Function(
    String text, {
    required int startIndex,
    required int endIndex,
  })? plainTextBuilder;

  final String text;

  /// The default text style. All plain text uses this style unless a [plainTextBuilder] is specified.
  final TextStyle? style;

  final int? maxLines;

  final TextAlign textAlign;

  final TextOverflow overflow;

  const RichTextComposer({
    super.key,
    required this.richTextBuilders,
    required this.text,
    this.plainTextBuilder,
    this.style,
    this.maxLines,
    this.textAlign = TextAlign.start,
    this.overflow = TextOverflow.clip,
  });

  static TextSpan _compose({
    required String text,
    required List<RichTextPatternBuilder> richTextBuilders,
    required PlainTextBuilder? plainTextBuilder,
    TextStyle? style,
  }) {
    final List<RichTextPatternMatch> allMatches = [];

    for (final richTextBuilder in richTextBuilders) {
      final List<RichTextPatternMatch> patternMatches = [];
      int index = 0;

      text.splitMapJoin(
        richTextBuilder.pattern,
        onMatch: (Match match) {
          final startIndex = match.start;
          final endIndex = match.end;
          final matchText = match.input.substring(startIndex, endIndex);

          // If multiple patterns from different builders overlap in their matching text,
          // then later matches should be ignored in favor of the first match for that text range.
          final hasOverlappingMatch = allMatches.any((overlappingMatch) {
            final overlapStartIndex = overlappingMatch.startIndex;
            final overlapEndIndex = overlappingMatch.endIndex;

            return startIndex <= overlapStartIndex &&
                    endIndex >= overlapStartIndex ||
                startIndex >= overlapStartIndex && startIndex < overlapEndIndex;
          });

          if (!hasOverlappingMatch) {
            patternMatches.add(
              RichTextPatternMatch(
                startIndex: match.start,
                endIndex: match.end,
                text: matchText,
                child: richTextBuilder.builder(
                  matchText,
                  startIndex: startIndex,
                  endIndex: endIndex - 1,
                  matchIndex: index++,
                ),
              ),
            );
          }

          return "";
        },
      );

      richTextBuilder.onMatch?.call(patternMatches);
      allMatches.addAll(patternMatches);
    }

    final sortedMatches = [...allMatches];
    sortedMatches.sort((a, b) => a.endIndex.compareTo(b.endIndex));

    List<InlineSpan> textSpans = [];

    RichTextPatternMatch? prevMatch;

    if (sortedMatches.isEmpty) {
      textSpans.add(
        plainTextBuilder?.call(
              text,
              startIndex: 0,
              endIndex: text.length - 1,
            ) ??
            _defaultPlainTextBuilder(text, style),
      );
    } else {
      for (final match in sortedMatches) {
        if (prevMatch == null) {
          if (match.startIndex > 0) {
            final plainText = text.substring(0, match.startIndex);
            textSpans.add(
              plainTextBuilder?.call(
                    plainText,
                    startIndex: 0,
                    endIndex: match.endIndex,
                  ) ??
                  _defaultPlainTextBuilder(plainText, style),
            );
          }
        } else if (match.startIndex > prevMatch.endIndex) {
          final plainText =
              text.substring(prevMatch.endIndex, match.startIndex);
          textSpans.add(
            plainTextBuilder?.call(
                  plainText,
                  startIndex: prevMatch.endIndex,
                  endIndex: match.endIndex,
                ) ??
                _defaultPlainTextBuilder(plainText, style),
          );
        }

        textSpans.add(match.child);
        prevMatch = match;
      }

      if (prevMatch != null && prevMatch.endIndex < text.length) {
        final plainText = text.substring(
          prevMatch.endIndex,
          text.length,
        );
        textSpans.add(
          plainTextBuilder?.call(
                plainText,
                startIndex: prevMatch.endIndex,
                endIndex: text.length - 1,
              ) ??
              _defaultPlainTextBuilder(plainText, style),
        );
      }
    }

    return TextSpan(style: style, children: textSpans);
  }

  @override
  build(context) {
    return _widget(
      richTextBuilders: richTextBuilders,
      plainTextBuilder: plainTextBuilder,
      text: text,
      style: style,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    );
  }

  static Widget _widget({
    required final List<RichTextPatternBuilder> richTextBuilders,
    required final PlainTextBuilder? plainTextBuilder,
    required final String text,
    final TextStyle? style,
    final int? maxLines,
    final TextAlign textAlign = TextAlign.start,
    final overflow = TextOverflow.clip,
  }) {
    return RichText(
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      text: _compose(
        text: text,
        richTextBuilders: richTextBuilders,
        plainTextBuilder: plainTextBuilder,
        style: style,
      ),
    );
  }

  static TextSpan span({
    required final List<RichTextPatternBuilder> richTextBuilders,
    required final PlainTextBuilder? plainTextBuilder,
    required final String text,
    final TextStyle? style,
  }) {
    return _compose(
      richTextBuilders: richTextBuilders,
      plainTextBuilder: plainTextBuilder,
      text: text,
      style: style,
    );
  }
}
