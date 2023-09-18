# Rich text composer

Sometimes `RichText` composing is easier with pattern matching. `RichTextComposer` turns composition like this:

```dart
RichText(
  text: TextSpan(
    children: [
      TextSpan("The forecast for today is ", style: TextStyle(color: Colors.black)),
      TextSpan(weatherType, style: TextStyle(fontWeight: FontWeight.bold)),
      TextSpan(" with a high of ", style: TextStyle(color: Colors.black)),
      TextSpan(temperatureMax, style: TextStyle(color: Colors.red)),
    ]
  )
)
```

into this:

```dart
RichTextComposer(
  text: "The forecast for today is @weatherType with a high of @high",
  richTextBuilders: [
    RichTextPatternBuilder(
      pattern: RegExp('@weatherType'),
      builder: (
        text, {
        required endIndex,
        required matchIndex,
        required startIndex,
      }) {
        return TextSpan(text: weatherType, style: TextStyle(fontWeight: FontWeight.bold));
      },
    ),
    RichTextPatternBuilder(
      pattern: RegExp('@high'),
      builder: (
        text, {
        required endIndex,
        required matchIndex,
        required startIndex,
      }) {
        return TextSpan(text: high, style: TextStyle(color: Colors.red));
      },
    ),
  ],
  plainTextBuilder: (text) => TextSpan(
    text: text,
    style: TextStyle(color: Colors.black)
  ),
)
```
