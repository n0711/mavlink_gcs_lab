class ParameterEntry {
  const ParameterEntry({required this.name, required this.value});

  final String name;
  final String value;
}

class ParameterParseIssue {
  const ParameterParseIssue({
    required this.lineNumber,
    required this.message,
    this.line,
  });

  final int lineNumber;
  final String message;
  final String? line;
}

class ParameterParseResult {
  const ParameterParseResult({
    required this.entries,
    required this.commentLineCount,
    required this.inlineCommentCount,
    required this.emptyLineCount,
    required this.invalidLineCount,
    required this.duplicateNames,
    required this.issues,
  });

  final List<ParameterEntry> entries;
  final int commentLineCount;
  final int inlineCommentCount;
  final int emptyLineCount;
  final int invalidLineCount;
  final List<String> duplicateNames;
  final List<ParameterParseIssue> issues;

  int get parsedCount => entries.length;

  int get duplicateNameCount => duplicateNames.length;

  bool get hasWarnings => issues.isNotEmpty || duplicateNames.isNotEmpty;

  List<String> get notes {
    final duplicatePreview = duplicateNames.take(5).join(', ');
    return [
      'Parsed parameter count: $parsedCount',
      'Comments ignored: $commentLineCount',
      'Inline comments stripped: $inlineCommentCount',
      'Empty lines ignored: $emptyLineCount',
      'Unsupported lines ignored: $invalidLineCount',
      'Supported Mission Planner/ArduPilot-style rows: PARAM,VALUE, PARAM VALUE, and PARAM=VALUE.',
      if (duplicateNames.isEmpty)
        'Duplicate parameter names: none'
      else
        'Duplicate parameter names: $duplicateNameCount'
            '${duplicatePreview.isEmpty ? '' : ' ($duplicatePreview)'}',
      'Duplicate names are reported. During comparison, the last parsed value for each parameter name is used.',
      for (final issue in issues.take(8))
        'Line ${issue.lineNumber}: ${issue.message}',
      if (issues.length > 8) 'Additional parser warnings: ${issues.length - 8}',
    ];
  }
}

List<ParameterEntry> parseParameterFile(String contents) {
  return parseParameterFileWithReport(contents).entries;
}

ParameterParseResult parseParameterFileWithReport(String contents) {
  final entries = <ParameterEntry>[];
  final issues = <ParameterParseIssue>[];
  final seenNames = <String, int>{};
  final duplicates = <String>{};
  var commentLineCount = 0;
  var inlineCommentCount = 0;
  var emptyLineCount = 0;
  var invalidLineCount = 0;

  final lines = contents.split(RegExp(r'\r?\n'));
  for (var index = 0; index < lines.length; index += 1) {
    final rawLine = index == 0
        ? lines[index].replaceFirst('\uFEFF', '')
        : lines[index];
    final line = rawLine.trim();
    if (line.isEmpty) {
      emptyLineCount += 1;
      continue;
    }
    if (line.startsWith('#') || line.startsWith('//')) {
      commentLineCount += 1;
      continue;
    }

    final strippedLine = _stripInlineComment(line);
    if (strippedLine.inlineCommentStripped) {
      inlineCommentCount += 1;
    }
    if (strippedLine.value.isEmpty) {
      commentLineCount += 1;
      continue;
    }

    final parsed = _parseLine(strippedLine.value);
    if (parsed.entry == null) {
      invalidLineCount += 1;
      issues.add(
        ParameterParseIssue(
          lineNumber: index + 1,
          message:
              'Unsupported Mission Planner/ArduPilot-style parameter line ignored.',
          line: line,
        ),
      );
      continue;
    }
    for (final issueMessage in parsed.issueMessages) {
      issues.add(
        ParameterParseIssue(
          lineNumber: index + 1,
          message: issueMessage,
          line: line,
        ),
      );
    }

    final entry = parsed.entry!;
    final normalizedName = entry.name.toUpperCase();
    if (seenNames.containsKey(normalizedName)) {
      duplicates.add(entry.name);
      issues.add(
        ParameterParseIssue(
          lineNumber: index + 1,
          message:
              'Duplicate parameter name also seen on line ${seenNames[normalizedName]}.',
          line: line,
        ),
      );
    } else {
      seenNames[normalizedName] = index + 1;
    }
    entries.add(entry);
  }

  return ParameterParseResult(
    entries: entries,
    commentLineCount: commentLineCount,
    inlineCommentCount: inlineCommentCount,
    emptyLineCount: emptyLineCount,
    invalidLineCount: invalidLineCount,
    duplicateNames: duplicates.toList()..sort(),
    issues: issues,
  );
}

_ParsedParameterLine _parseLine(String line) {
  if (line.contains(',')) {
    return _entryFromParts(
      line.split(','),
      minimumParts: 2,
      extraPartsMessage: 'Extra comma-separated columns ignored.',
      useOnlyFirstValuePart: true,
    );
  }
  if (line.contains('=')) {
    return _entryFromParts(line.split('='), minimumParts: 2);
  }
  return _entryFromParts(
    line.split(RegExp(r'\s+')),
    minimumParts: 2,
    extraPartsMessage: 'Extra whitespace-separated fields kept in value.',
  );
}

_ParsedParameterLine _entryFromParts(
  List<String> parts, {
  required int minimumParts,
  String? extraPartsMessage,
  bool useOnlyFirstValuePart = false,
}) {
  if (parts.length < minimumParts) return const _ParsedParameterLine();

  final name = parts.first.trim();
  final value = useOnlyFirstValuePart
      ? parts[1].trim()
      : parts.sublist(1).join(' ').trim();
  if (name.isEmpty || value.isEmpty || !_looksLikeArduPilotName(name)) {
    return const _ParsedParameterLine();
  }

  return _ParsedParameterLine(
    entry: ParameterEntry(name: name, value: value),
    issueMessages: [
      if (extraPartsMessage != null && parts.length > minimumParts)
        extraPartsMessage,
    ],
  );
}

_StrippedParameterLine _stripInlineComment(String line) {
  final hashIndex = line.indexOf('#');
  final slashIndex = line.indexOf('//');
  final commentIndexes = [
    if (hashIndex >= 0) hashIndex,
    if (slashIndex >= 0) slashIndex,
  ]..sort();
  if (commentIndexes.isEmpty) {
    return _StrippedParameterLine(value: line);
  }

  return _StrippedParameterLine(
    value: line.substring(0, commentIndexes.first).trim(),
    inlineCommentStripped: true,
  );
}

bool _looksLikeArduPilotName(String name) {
  return RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(name);
}

class _ParsedParameterLine {
  const _ParsedParameterLine({this.entry, this.issueMessages = const []});

  final ParameterEntry? entry;
  final List<String> issueMessages;
}

class _StrippedParameterLine {
  const _StrippedParameterLine({
    required this.value,
    this.inlineCommentStripped = false,
  });

  final String value;
  final bool inlineCommentStripped;
}
