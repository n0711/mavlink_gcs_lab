import 'package:mavlink_gcs_portfolio/features/dashboard/parameter_diff.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/parameter_file_parser.dart';

const parameterDiffReportTitle =
    'MAVLink GCS Portfolio Offline Parameter Comparison Report';
const parameterDiffReportFormat = 'MAVLINK-GCS-PORTFOLIO-PARAM-DIFF-v1';
const parameterDiffReportSafetyNote =
    'Offline comparison only. No vehicle communication or parameter writes were performed.';
const parameterDiffReportCategoryRuleNote =
    'Categories and review tags are local prefix-based review hints only. They are not official ArduPilot metadata, do not assign severity, do not block anything, and do not communicate with the vehicle.';

class ParameterReportFilterSummary {
  const ParameterReportFilterSummary({
    required this.filteredReport,
    this.searchQuery,
    this.statusLabel,
    this.categoryLabel,
    this.reviewTagLabel,
  });

  final bool filteredReport;
  final String? searchQuery;
  final String? statusLabel;
  final String? categoryLabel;
  final String? reviewTagLabel;

  List<String> get activeFilters {
    return [
      if (searchQuery != null && searchQuery!.isNotEmpty)
        'Search: $searchQuery',
      if (statusLabel != null && statusLabel!.isNotEmpty)
        'Status: $statusLabel',
      if (categoryLabel != null && categoryLabel!.isNotEmpty)
        'Category: $categoryLabel',
      if (reviewTagLabel != null && reviewTagLabel!.isNotEmpty)
        'Review tag: $reviewTagLabel',
    ];
  }
}

String buildParameterDiffMarkdownReport({
  required DateTime generatedAt,
  required String currentFileName,
  required String baselineFileName,
  required int currentParameterCount,
  required int baselineParameterCount,
  required List<ParameterDiffEntry> entries,
  ParameterReportFilterSummary filterSummary =
      const ParameterReportFilterSummary(filteredReport: false),
  ParameterParseResult? currentParseResult,
  ParameterParseResult? baselineParseResult,
  List<String> currentParserNotes = const [],
  List<String> baselineParserNotes = const [],
}) {
  final summary = summarizeParameterDiff(entries);
  final buffer = StringBuffer()
    ..writeln('# $parameterDiffReportTitle')
    ..writeln()
    ..writeln('- Report format: $parameterDiffReportFormat')
    ..writeln(
      '- Filtered report: ${filterSummary.filteredReport ? 'yes' : 'no'}',
    )
    ..writeln()
    ..writeln(parameterDiffReportSafetyNote)
    ..writeln()
    ..writeln('## Safety boundary')
    ..writeln()
    ..writeln('- No vehicle communication.')
    ..writeln('- No live parameter requests.')
    ..writeln('- No parameter writes or `PARAM_SET`.')
    ..writeln('- No mission upload or vehicle commands.')
    ..writeln()
    ..writeln('## Summary')
    ..writeln()
    ..writeln('- Generated timestamp: ${generatedAt.toIso8601String()}')
    ..writeln('- Current parameter file name: $currentFileName')
    ..writeln('- Baseline parameter file name: $baselineFileName')
    ..writeln('- Current parsed count: $currentParameterCount')
    ..writeln('- Baseline parsed count: $baselineParameterCount')
    ..writeln('- Changed count: ${summary.changed}')
    ..writeln('- Added count: ${summary.added}')
    ..writeln('- Removed count: ${summary.removed}')
    ..writeln('- Unchanged count: ${summary.unchanged}')
    ..writeln();

  _writeFilterSection(buffer, filterSummary);
  _writeSection(
    buffer,
    title: 'Changed parameters',
    entries: entries,
    status: ParameterDiffStatus.changed,
  );
  _writeSection(
    buffer,
    title: 'Added parameters',
    entries: entries,
    status: ParameterDiffStatus.added,
  );
  _writeSection(
    buffer,
    title: 'Removed parameters',
    entries: entries,
    status: ParameterDiffStatus.removed,
  );
  _writeCountSection(
    buffer,
    title: 'Category summary',
    counts: _categoryCounts(entries),
  );
  _writeCountSection(
    buffer,
    title: 'Review tag summary',
    counts: _reviewTagCounts(entries),
  );
  _writeParserNotes(
    buffer,
    currentParseResult: currentParseResult,
    baselineParseResult: baselineParseResult,
    currentParserNotes: currentParserNotes,
    baselineParserNotes: baselineParserNotes,
  );
  _writeDuplicateSummary(
    buffer,
    currentParseResult: currentParseResult,
    baselineParseResult: baselineParseResult,
  );
  _writeCategoryRuleNote(buffer);

  return buffer.toString();
}

void _writeFilterSection(
  StringBuffer buffer,
  ParameterReportFilterSummary filterSummary,
) {
  buffer
    ..writeln('## Filter metadata')
    ..writeln()
    ..writeln(
      '- Filtered report: ${filterSummary.filteredReport ? 'yes' : 'no'}',
    );
  if (filterSummary.activeFilters.isEmpty) {
    buffer.writeln('- Active filters: none');
  } else {
    for (final filter in filterSummary.activeFilters) {
      buffer.writeln('- ${_markdownCell(filter)}');
    }
  }
  buffer.writeln();
}

void _writeSection(
  StringBuffer buffer, {
  required String title,
  required List<ParameterDiffEntry> entries,
  required ParameterDiffStatus status,
}) {
  final sectionEntries = entries.where((entry) => entry.status == status);
  buffer
    ..writeln('## $title')
    ..writeln()
    ..writeln(_tableHeaderFor(status))
    ..writeln(_tableDividerFor(status));

  for (final entry in sectionEntries) {
    if (status == ParameterDiffStatus.added) {
      buffer.writeln(
        '| ${_markdownCell(entry.name)} | '
        '${_markdownCell(entry.currentValue ?? '--')} | '
        '${_markdownCell(entry.category)} | '
        '${_markdownCell(entry.relevanceTag ?? '--')} |',
      );
    } else if (status == ParameterDiffStatus.removed) {
      buffer.writeln(
        '| ${_markdownCell(entry.name)} | '
        '${_markdownCell(entry.baselineValue ?? '--')} | '
        '${_markdownCell(entry.category)} | '
        '${_markdownCell(entry.relevanceTag ?? '--')} |',
      );
    } else {
      buffer.writeln(
        '| ${_markdownCell(entry.name)} | '
        '${_markdownCell(entry.baselineValue ?? '--')} | '
        '${_markdownCell(entry.currentValue ?? '--')} | '
        '${_markdownCell(entry.category)} | '
        '${_markdownCell(entry.relevanceTag ?? '--')} |',
      );
    }
  }

  buffer.writeln();
}

String _tableHeaderFor(ParameterDiffStatus status) {
  if (status == ParameterDiffStatus.added ||
      status == ParameterDiffStatus.removed) {
    return '| Parameter | Value | Category | Review Tag |';
  }
  return '| Parameter | Baseline Value | Current Value | Category | Review Tag |';
}

String _tableDividerFor(ParameterDiffStatus status) {
  if (status == ParameterDiffStatus.added ||
      status == ParameterDiffStatus.removed) {
    return '| --- | --- | --- | --- |';
  }
  return '| --- | --- | --- | --- | --- |';
}

void _writeCountSection(
  StringBuffer buffer, {
  required String title,
  required Map<String, int> counts,
}) {
  buffer
    ..writeln('## $title')
    ..writeln()
    ..writeln('| Name | Count |')
    ..writeln('| --- | --- |');

  for (final entry in counts.entries) {
    buffer.writeln('| ${_markdownCell(entry.key)} | ${entry.value} |');
  }

  buffer.writeln();
}

void _writeParserNotes(
  StringBuffer buffer, {
  required ParameterParseResult? currentParseResult,
  required ParameterParseResult? baselineParseResult,
  required List<String> currentParserNotes,
  required List<String> baselineParserNotes,
}) {
  buffer
    ..writeln('## Parser diagnostics')
    ..writeln()
    ..writeln('### Current file')
    ..writeln();
  _writeParserDiagnosticSummary(buffer, currentParseResult);
  _writeParserIssueTable(buffer, 'Current', currentParseResult);
  _writeNotes(buffer, currentParserNotes);
  buffer
    ..writeln()
    ..writeln('### Baseline file')
    ..writeln();
  _writeParserDiagnosticSummary(buffer, baselineParseResult);
  _writeParserIssueTable(buffer, 'Baseline', baselineParseResult);
  _writeNotes(buffer, baselineParserNotes);
  buffer.writeln();
}

void _writeParserDiagnosticSummary(
  StringBuffer buffer,
  ParameterParseResult? result,
) {
  if (result == null) {
    buffer.writeln('- Parser diagnostics: not available.');
    return;
  }
  buffer
    ..writeln('- Parsed parameter count: ${result.parsedCount}')
    ..writeln('- Comments ignored: ${result.commentLineCount}')
    ..writeln('- Inline comments stripped: ${result.inlineCommentCount}')
    ..writeln('- Empty lines ignored: ${result.emptyLineCount}')
    ..writeln('- Unsupported/invalid lines ignored: ${result.invalidLineCount}')
    ..writeln(
      '- Duplicate parameter names count: ${result.duplicateNameCount}',
    );
  if (result.duplicateNames.isNotEmpty) {
    buffer.writeln(
      '- Duplicate names: ${_markdownCell(result.duplicateNames.take(8).join(', '))}',
    );
  }
  buffer.writeln(
    '- Duplicate policy: Duplicate names are reported. During comparison, the last parsed value for each parameter name is used.',
  );
}

void _writeParserIssueTable(
  StringBuffer buffer,
  String fileLabel,
  ParameterParseResult? result,
) {
  if (result == null || result.issues.isEmpty) {
    buffer.writeln('- Parser issue table: none.');
    return;
  }

  final visibleIssues = result.issues.take(10).toList();
  buffer
    ..writeln()
    ..writeln('| File | Line | Issue | Raw text |')
    ..writeln('| --- | --- | --- | --- |');
  for (final issue in visibleIssues) {
    buffer.writeln(
      '| ${_markdownCell(fileLabel)} | ${issue.lineNumber} | '
      '${_markdownCell(issue.message)} | ${_markdownCell(issue.line ?? '--')} |',
    );
  }
  if (result.issues.length > visibleIssues.length) {
    buffer
      ..writeln()
      ..writeln(
        'Showing first ${visibleIssues.length} of ${result.issues.length} parser issues.',
      );
  }
}

void _writeDuplicateSummary(
  StringBuffer buffer, {
  required ParameterParseResult? currentParseResult,
  required ParameterParseResult? baselineParseResult,
}) {
  final rows = <({String fileLabel, String name})>[
    ..._duplicateRows('Current', currentParseResult),
    ..._duplicateRows('Baseline', baselineParseResult),
  ];

  buffer
    ..writeln('## Duplicate parameter summary')
    ..writeln()
    ..writeln(
      'Duplicate names are reported. During comparison, the last parsed value for each parameter name is used.',
    )
    ..writeln();

  if (rows.isEmpty) {
    buffer
      ..writeln('- Duplicate parameters: none')
      ..writeln();
    return;
  }

  buffer
    ..writeln('| Parameter | File | Policy |')
    ..writeln('| --- | --- | --- |');
  for (final row in rows) {
    buffer.writeln(
      '| ${_markdownCell(row.name)} | ${_markdownCell(row.fileLabel)} | Last parsed value used |',
    );
  }
  buffer.writeln();
}

List<({String fileLabel, String name})> _duplicateRows(
  String fileLabel,
  ParameterParseResult? result,
) {
  if (result == null) return const [];
  return result.duplicateNames
      .map((name) => (fileLabel: fileLabel, name: name))
      .toList();
}

void _writeNotes(StringBuffer buffer, List<String> notes) {
  if (notes.isEmpty) {
    buffer.writeln('- No parser notes available.');
    return;
  }
  for (final note in notes) {
    buffer.writeln('- ${_markdownCell(note)}');
  }
}

Map<String, int> _categoryCounts(List<ParameterDiffEntry> entries) {
  return _sortedCounts(entries.map((entry) => entry.category));
}

Map<String, int> _reviewTagCounts(List<ParameterDiffEntry> entries) {
  return _sortedCounts(entries.map((entry) => entry.relevanceTag ?? 'No tag'));
}

void _writeCategoryRuleNote(StringBuffer buffer) {
  buffer
    ..writeln('## Category and review tag note')
    ..writeln()
    ..writeln(parameterDiffReportCategoryRuleNote)
    ..writeln()
    ..writeln(
      '- `BATT_`/`BAT_`/battery number patterns: Battery / Power relevant',
    )
    ..writeln(
      '- `GPS_`/`GNSS_`/GPS number patterns: GPS / GNSS / Navigation relevant',
    )
    ..writeln(
      '- `EKF_`/`EK*`/`AHRS_`/`INS_`: EKF / AHRS / State-estimation relevant',
    )
    ..writeln('- `FS_`/`FENCE_`: Failsafe / Failsafe relevant')
    ..writeln('- `ARMING_`: Arming / Arming relevant')
    ..writeln(
      '- `RC_`/`RSSI_`/RC number patterns: RC / Radio / Radio-control input relevant',
    )
    ..writeln(
      '- `SERVO_`/`MOT_`/`Q_M_`/SERVO number patterns: Motors / Servo / Actuator-output relevant',
    )
    ..writeln('- `NAV_`/`WP_`/`WPNAV_`: Navigation / Navigation relevant')
    ..writeln('- `MIS_`/`MISSION_`/`DO_`: Mission / No review tag')
    ..writeln(
      '- `SERIAL_`/`MAV_`/`SR*`: Communication / Communication relevant',
    )
    ..writeln('- Everything else: Other / No tag')
    ..writeln();
}

Map<String, int> _sortedCounts(Iterable<String> values) {
  final counts = <String, int>{};
  for (final value in values) {
    counts[value] = (counts[value] ?? 0) + 1;
  }
  return Map.fromEntries(
    counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

String _markdownCell(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll('|', r'\|');
}
