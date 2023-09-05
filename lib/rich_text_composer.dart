library rich_text_composer;

import 'package:flutter/material.dart';

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
  final TextSpan Function(
    /// The matched text substring from [startIndex] to [endIndex].
    String text, {
    /// The index of the start of the match in the string.
    required int startIndex,

    /// The index of the end of the match in the string.
    required int endIndex,

    /// The index of the match. Whether it's the first 1st, 2nd, 3rd match etc.
    required int matchIndex,
  }) builder;
  final void Function(List<RichTextPatternMatch> matches)? onMatch;

  RichTextPatternBuilder({
    required this.pattern,
    required this.builder,
    this.onMatch,
  });
}

class RichTextComposer extends StatelessWidget {
  final List<RichTextPatternBuilder> richTextBuilders;
  final TextSpan Function(String text) plainTextBuilder;
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign textAlign;
  final TextOverflow overflow;

  const RichTextComposer({
    super.key,
    required this.richTextBuilders,
    required this.plainTextBuilder,
    required this.text,
    this.style,
    this.maxLines,
    this.textAlign = TextAlign.start,
    this.overflow = TextOverflow.clip,
  });

  static TextSpan _compose({
    required String text,
    required List<RichTextPatternBuilder> richTextBuilders,
    required TextSpan Function(String text) plainTextBuilder,
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
                startIndex >= overlapStartIndex &&
                    startIndex <= overlapEndIndex;
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
      textSpans.add(plainTextBuilder(text));
    } else {
      for (final match in sortedMatches) {
        if (prevMatch == null) {
          if (match.startIndex > 0) {
            textSpans.add(
              plainTextBuilder(text.substring(0, match.startIndex)),
            );
          }
        } else if (match.startIndex > prevMatch.endIndex) {
          textSpans.add(
            plainTextBuilder(
              text.substring(prevMatch.endIndex, match.startIndex),
            ),
          );
        }

        textSpans.add(match.child);
        prevMatch = match;
      }

      if (prevMatch != null && prevMatch.endIndex < text.length) {
        textSpans.add(
          plainTextBuilder(
            text.substring(
              prevMatch.endIndex,
              text.length,
            ),
          ),
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
    required final TextSpan Function(String text) plainTextBuilder,
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
    required final TextSpan Function(String text) plainTextBuilder,
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
