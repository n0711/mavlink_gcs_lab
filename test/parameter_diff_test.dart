import 'package:flutter_test/flutter_test.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/parameter_diff.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/parameter_file_parser.dart';

void main() {
  test('classifies offline parameter differences', () {
    final baseline = parseParameterFile('''
PARAM_A=1
PARAM_B=2
PARAM_C=3
''');
    final current = parseParameterFile('''
PARAM_A=1
PARAM_B=20
PARAM_D=4
''');

    final diff = diffParameters(baseline: baseline, current: current);
    final byName = {for (final entry in diff) entry.name: entry};

    expect(byName['PARAM_A']?.status, ParameterDiffStatus.unchanged);
    expect(byName['PARAM_B']?.status, ParameterDiffStatus.changed);
    expect(byName['PARAM_B']?.baselineValue, '2');
    expect(byName['PARAM_B']?.currentValue, '20');
    expect(byName['PARAM_B']?.category, 'Other');
    expect(byName['PARAM_C']?.status, ParameterDiffStatus.removed);
    expect(byName['PARAM_D']?.status, ParameterDiffStatus.added);

    final summary = summarizeParameterDiff(diff);
    expect(summary.unchanged, 1);
    expect(summary.changed, 1);
    expect(summary.removed, 1);
    expect(summary.added, 1);
  });

  test('uses last parsed duplicate value during comparison', () {
    final baseline = parseParameterFile('''
PARAM_A=1
PARAM_A=2
''');
    final current = parseParameterFile('''
param_a=2
PARAM_B=3
''');

    final diff = diffParameters(baseline: baseline, current: current);
    final byName = {for (final entry in diff) entry.name: entry};

    expect(byName['PARAM_A']?.baselineValue, '2');
    expect(byName['PARAM_A']?.currentValue, '2');
    expect(byName['PARAM_A']?.status, ParameterDiffStatus.unchanged);
    expect(byName['PARAM_B']?.status, ParameterDiffStatus.added);
  });

  test('sorts parameter differences by supported modes', () {
    final entries = diffParameters(
      baseline: parseParameterFile('''
BATT_LOW_VOLT=10
GPS_TYPE=1
PARAM_Z=1
'''),
      current: parseParameterFile('''
BATT_LOW_VOLT=11
GPS_TYPE=1
PARAM_A=1
'''),
    );

    expect(
      sortParameterDiffEntries(
        entries,
        sortMode: ParameterDiffSortMode.status,
      ).map((entry) => entry.status),
      [
        ParameterDiffStatus.changed,
        ParameterDiffStatus.added,
        ParameterDiffStatus.removed,
        ParameterDiffStatus.unchanged,
      ],
    );
    expect(
      sortParameterDiffEntries(
        entries,
        sortMode: ParameterDiffSortMode.name,
      ).map((entry) => entry.name),
      ['BATT_LOW_VOLT', 'GPS_TYPE', 'PARAM_A', 'PARAM_Z'],
    );
    expect(
      sortParameterDiffEntries(
        entries,
        sortMode: ParameterDiffSortMode.category,
      ).first.category,
      'Battery',
    );
    expect(
      sortParameterDiffEntries(
        entries,
        sortMode: ParameterDiffSortMode.reviewTag,
      ).first.relevanceTag,
      'Navigation relevant',
    );
  });

  test('groups parameter differences by status and category', () {
    final entries = sortParameterDiffEntries(
      diffParameters(
        baseline: parseParameterFile('''
BATT_LOW_VOLT=10
GPS_TYPE=1
PARAM_Z=1
'''),
        current: parseParameterFile('''
BATT_LOW_VOLT=11
GPS_TYPE=1
PARAM_A=1
'''),
      ),
      sortMode: ParameterDiffSortMode.status,
    );

    final statusGroups = groupParameterDiffEntries(
      entries,
      displayMode: ParameterDiffDisplayMode.groupByStatus,
    );
    expect(statusGroups.map((group) => '${group.label}:${group.count}'), [
      'Changed:1',
      'Added:1',
      'Removed:1',
      'Unchanged:1',
    ]);

    final categoryGroups = groupParameterDiffEntries(
      entries,
      displayMode: ParameterDiffDisplayMode.groupByCategory,
    );
    expect(categoryGroups.map((group) => '${group.label}:${group.count}'), [
      'Battery:1',
      'GPS / GNSS:1',
      'Other:2',
    ]);

    final filteredBatteryEntries = entries
        .where((entry) => entry.category == 'Battery')
        .toList();
    expect(
      groupParameterDiffEntries(
        filteredBatteryEntries,
        displayMode: ParameterDiffDisplayMode.groupByCategory,
      ).single.count,
      1,
    );
  });
}
