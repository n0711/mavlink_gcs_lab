import 'package:flutter_test/flutter_test.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/parameter_diff.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/parameter_diff_report.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/parameter_file_parser.dart';

void main() {
  test('builds offline parameter diff markdown report', () {
    final baselineResult = parseParameterFileWithReport('''
PARAM_A=1
GPS_TYPE=2
PARAM_C=3
PARAM_C=30
''');
    final currentResult = parseParameterFileWithReport('''
PARAM_A=1
GPS_TYPE=20
BATT_LOW_VOLT=4
badline
''');
    final diff = diffParameters(
      baseline: baselineResult.entries,
      current: currentResult.entries,
    );

    final report = buildParameterDiffMarkdownReport(
      generatedAt: DateTime.utc(2026, 7),
      currentFileName: 'current.param',
      baselineFileName: 'baseline.param',
      currentParameterCount: currentResult.entries.length,
      baselineParameterCount: baselineResult.entries.length,
      entries: diff,
      filterSummary: const ParameterReportFilterSummary(
        filteredReport: true,
        searchQuery: 'GPS',
        statusLabel: 'Changed',
        categoryLabel: 'GPS / GNSS',
        reviewTagLabel: 'Navigation relevant',
      ),
      currentParseResult: currentResult,
      baselineParseResult: baselineResult,
      currentParserNotes: currentResult.notes,
      baselineParserNotes: baselineResult.notes,
    );

    expect(report, contains('# $parameterDiffReportTitle'));
    expect(report, contains('- Report format: $parameterDiffReportFormat'));
    expect(report, contains('- Filtered report: yes'));
    expect(report, contains(parameterDiffReportSafetyNote));
    expect(report, contains('## Safety boundary'));
    expect(report, contains('- No parameter writes or `PARAM_SET`.'));
    expect(report, contains('- Changed count: 1'));
    expect(report, contains('- Added count: 1'));
    expect(report, contains('- Removed count: 1'));
    expect(report, contains('- Unchanged count: 1'));
    expect(report, contains('## Filter metadata'));
    expect(report, contains('- Search: GPS'));
    expect(report, contains('## Category summary'));
    expect(report, contains('## Review tag summary'));
    expect(report, contains('## Parser diagnostics'));
    expect(report, contains('- Duplicate parameter names count: 1'));
    expect(report, contains('- Inline comments stripped: 0'));
    expect(report, contains('- Unsupported/invalid lines ignored: 1'));
    expect(
      report,
      contains(
        '| Current | 4 | Unsupported Mission Planner/ArduPilot-style parameter line ignored. | badline |',
      ),
    );
    expect(
      report,
      contains(
        '| Baseline | 4 | Duplicate parameter name also seen on line 3. | PARAM_C=30 |',
      ),
    );
    expect(report, contains('## Duplicate parameter summary'));
    expect(report, contains('| PARAM_C | Baseline | Last parsed value used |'));
    expect(report, contains('## Category and review tag note'));
    expect(report, contains(parameterDiffReportCategoryRuleNote));
    expect(
      report,
      contains('| GPS_TYPE | 2 | 20 | GPS / GNSS | Navigation relevant |'),
    );
    expect(
      report,
      contains('| BATT_LOW_VOLT | 4 | Battery | Power relevant |'),
    );
    expect(report, contains('| PARAM_C | 30 | Other | -- |'));
  });

  test('limits parser issue table to first ten issues', () {
    final noisyResult = parseParameterFileWithReport('''
bad1
bad2
bad3
bad4
bad5
bad6
bad7
bad8
bad9
bad10
bad11
''');

    final report = buildParameterDiffMarkdownReport(
      generatedAt: DateTime.utc(2026, 7),
      currentFileName: 'current.param',
      baselineFileName: 'baseline.param',
      currentParameterCount: 0,
      baselineParameterCount: 0,
      entries: const [],
      currentParseResult: noisyResult,
      baselineParseResult: noisyResult,
    );

    expect(report, contains('Showing first 10 of 11 parser issues.'));
    expect(
      report,
      contains(
        '| Current | 1 | Unsupported Mission Planner/ArduPilot-style parameter line ignored. | bad1 |',
      ),
    );
    expect(
      report,
      isNot(
        contains(
          '| Current | 11 | Unsupported Mission Planner/ArduPilot-style parameter line ignored. | bad11 |',
        ),
      ),
    );
  });
}
