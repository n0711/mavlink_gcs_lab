import 'package:mavlink_gcs_portfolio/features/dashboard/parameter_file_parser.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/parameter_metadata.dart';

enum ParameterDiffStatus {
  unchanged,
  changed,
  added,
  removed;

  String get label {
    switch (this) {
      case ParameterDiffStatus.unchanged:
        return 'Unchanged';
      case ParameterDiffStatus.changed:
        return 'Changed';
      case ParameterDiffStatus.added:
        return 'Added';
      case ParameterDiffStatus.removed:
        return 'Removed';
    }
  }
}

enum ParameterDiffSortMode {
  status,
  name,
  category,
  reviewTag;

  String get label {
    switch (this) {
      case ParameterDiffSortMode.status:
        return 'Status';
      case ParameterDiffSortMode.name:
        return 'Name';
      case ParameterDiffSortMode.category:
        return 'Category';
      case ParameterDiffSortMode.reviewTag:
        return 'Review tag';
    }
  }
}

enum ParameterDiffDisplayMode {
  flat,
  groupByStatus,
  groupByCategory;

  String get label {
    switch (this) {
      case ParameterDiffDisplayMode.flat:
        return 'Flat list';
      case ParameterDiffDisplayMode.groupByStatus:
        return 'Group by status';
      case ParameterDiffDisplayMode.groupByCategory:
        return 'Group by category';
    }
  }
}

class ParameterDiffEntry {
  const ParameterDiffEntry({
    required this.name,
    required this.baselineValue,
    required this.currentValue,
    required this.status,
  });

  final String name;
  final String? baselineValue;
  final String? currentValue;
  final ParameterDiffStatus status;

  ParameterMetadata get metadata => metadataForParameter(name);

  String get category => metadata.category;

  String? get relevanceTag => metadata.relevanceTag;
}

class ParameterDiffSummary {
  const ParameterDiffSummary({
    required this.unchanged,
    required this.changed,
    required this.added,
    required this.removed,
  });

  final int unchanged;
  final int changed;
  final int added;
  final int removed;
}

class ParameterDiffGroup {
  const ParameterDiffGroup({required this.label, required this.entries});

  final String label;
  final List<ParameterDiffEntry> entries;

  int get count => entries.length;
}

List<ParameterDiffEntry> diffParameters({
  required List<ParameterEntry> baseline,
  required List<ParameterEntry> current,
}) {
  final baselineMap = _toMap(baseline);
  final currentMap = _toMap(current);
  final names = {...baselineMap.keys, ...currentMap.keys}.toList()..sort();

  return names.map((name) {
    final baselineValue = baselineMap[name];
    final currentValue = currentMap[name];

    if (baselineValue == null) {
      return ParameterDiffEntry(
        name: name,
        baselineValue: null,
        currentValue: currentValue,
        status: ParameterDiffStatus.added,
      );
    }
    if (currentValue == null) {
      return ParameterDiffEntry(
        name: name,
        baselineValue: baselineValue,
        currentValue: null,
        status: ParameterDiffStatus.removed,
      );
    }
    if (baselineValue != currentValue) {
      return ParameterDiffEntry(
        name: name,
        baselineValue: baselineValue,
        currentValue: currentValue,
        status: ParameterDiffStatus.changed,
      );
    }
    return ParameterDiffEntry(
      name: name,
      baselineValue: baselineValue,
      currentValue: currentValue,
      status: ParameterDiffStatus.unchanged,
    );
  }).toList();
}

List<ParameterDiffEntry> sortParameterDiffEntries(
  List<ParameterDiffEntry> entries, {
  required ParameterDiffSortMode sortMode,
}) {
  final sorted = [...entries];
  sorted.sort((a, b) {
    final primaryCompare = switch (sortMode) {
      ParameterDiffSortMode.status => _statusSort(
        a.status,
      ).compareTo(_statusSort(b.status)),
      ParameterDiffSortMode.name => a.name.compareTo(b.name),
      ParameterDiffSortMode.category => a.category.compareTo(b.category),
      ParameterDiffSortMode.reviewTag => (a.relevanceTag ?? 'No tag').compareTo(
        b.relevanceTag ?? 'No tag',
      ),
    };
    if (primaryCompare != 0) return primaryCompare;

    final statusCompare = _statusSort(
      a.status,
    ).compareTo(_statusSort(b.status));
    if (statusCompare != 0) return statusCompare;
    return a.name.compareTo(b.name);
  });
  return sorted;
}

List<ParameterDiffGroup> groupParameterDiffEntries(
  List<ParameterDiffEntry> entries, {
  required ParameterDiffDisplayMode displayMode,
}) {
  switch (displayMode) {
    case ParameterDiffDisplayMode.flat:
      return [ParameterDiffGroup(label: 'All parameters', entries: entries)];
    case ParameterDiffDisplayMode.groupByStatus:
      return const [
            ParameterDiffStatus.changed,
            ParameterDiffStatus.added,
            ParameterDiffStatus.removed,
            ParameterDiffStatus.unchanged,
          ]
          .map((status) {
            return ParameterDiffGroup(
              label: status.label,
              entries: entries
                  .where((entry) => entry.status == status)
                  .toList(),
            );
          })
          .where((group) => group.entries.isNotEmpty)
          .toList();
    case ParameterDiffDisplayMode.groupByCategory:
      return parameterCategories
          .skip(1)
          .map((category) {
            return ParameterDiffGroup(
              label: category,
              entries: entries
                  .where((entry) => entry.category == category)
                  .toList(),
            );
          })
          .where((group) => group.entries.isNotEmpty)
          .toList();
  }
}

ParameterDiffSummary summarizeParameterDiff(List<ParameterDiffEntry> entries) {
  var unchanged = 0;
  var changed = 0;
  var added = 0;
  var removed = 0;

  for (final entry in entries) {
    switch (entry.status) {
      case ParameterDiffStatus.unchanged:
        unchanged += 1;
      case ParameterDiffStatus.changed:
        changed += 1;
      case ParameterDiffStatus.added:
        added += 1;
      case ParameterDiffStatus.removed:
        removed += 1;
    }
  }

  return ParameterDiffSummary(
    unchanged: unchanged,
    changed: changed,
    added: added,
    removed: removed,
  );
}

Map<String, String> _toMap(List<ParameterEntry> entries) {
  return {for (final entry in entries) entry.name.toUpperCase(): entry.value};
}

int _statusSort(ParameterDiffStatus status) {
  switch (status) {
    case ParameterDiffStatus.changed:
      return 0;
    case ParameterDiffStatus.added:
      return 1;
    case ParameterDiffStatus.removed:
      return 2;
    case ParameterDiffStatus.unchanged:
      return 3;
  }
}
