import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/parameter_diff.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/parameter_diff_report.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/parameter_file_parser.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/parameter_metadata.dart';

class ParameterViewerPanel extends StatefulWidget {
  const ParameterViewerPanel({super.key});

  @override
  State<ParameterViewerPanel> createState() => _ParameterViewerPanelState();
}

class _ParameterViewerPanelState extends State<ParameterViewerPanel> {
  final _searchController = TextEditingController();
  String? _currentFilePath;
  String? _baselineFilePath;
  List<ParameterEntry> _currentParameters = const [];
  List<ParameterEntry> _baselineParameters = const [];
  ParameterParseResult? _currentParseResult;
  ParameterParseResult? _baselineParseResult;
  ParameterDiffStatus? _statusFilter;
  ParameterDiffSortMode _sortMode = ParameterDiffSortMode.status;
  ParameterDiffDisplayMode _displayMode = ParameterDiffDisplayMode.flat;
  String _categoryFilter = parameterCategoryAll;
  String _reviewTagFilter = parameterReviewTagAll;
  bool _exportFilteredView = false;
  String? _errorText;

  String get _currentFileName => _fileName(
    _currentFilePath,
    fallback: 'No current parameter file selected',
  );

  String get _baselineFileName => _fileName(
    _baselineFilePath,
    fallback: 'No baseline parameter file selected',
  );

  List<ParameterDiffEntry> get _diffEntries {
    return diffParameters(
      baseline: _baselineParameters,
      current: _currentParameters,
    );
  }

  List<ParameterDiffEntry> get _filteredDiffEntries {
    final query = _searchController.text.trim().toLowerCase();
    final activeEntries = _diffEntries.where((entry) {
      if (_statusFilter != null && entry.status != _statusFilter) return false;
      if (_categoryFilter != parameterCategoryAll &&
          entry.category != _categoryFilter) {
        return false;
      }
      if (_reviewTagFilter == parameterReviewTagNone &&
          entry.relevanceTag != null) {
        return false;
      }
      if (_reviewTagFilter != parameterReviewTagAll &&
          _reviewTagFilter != parameterReviewTagNone &&
          entry.relevanceTag != _reviewTagFilter) {
        return false;
      }
      if (query.isNotEmpty && !_matchesQuery(entry, query)) {
        return false;
      }
      return true;
    }).toList();

    return sortParameterDiffEntries(activeEntries, sortMode: _sortMode);
  }

  ParameterDiffSummary get _summary => summarizeParameterDiff(_diffEntries);

  bool get _hasCurrentParameters =>
      _currentFilePath != null && _currentParameters.isNotEmpty;

  bool get _hasBaselineParameters =>
      _baselineFilePath != null && _baselineParameters.isNotEmpty;

  bool get _hasComparison => _hasCurrentParameters && _hasBaselineParameters;

  bool get _canExportDiffReport {
    return _hasComparison && _diffEntries.isNotEmpty;
  }

  bool get _hasDuplicateWarnings {
    return (_currentParseResult?.duplicateNames.isNotEmpty ?? false) ||
        (_baselineParseResult?.duplicateNames.isNotEmpty ?? false);
  }

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        _statusFilter != null ||
        _categoryFilter != parameterCategoryAll ||
        _reviewTagFilter != parameterReviewTagAll;
  }

  List<String> get _activeFilterLabels {
    return [
      if (_searchController.text.trim().isNotEmpty) 'Search active',
      if (_statusFilter != null) 'Status: ${_statusFilter!.label}',
      if (_categoryFilter != parameterCategoryAll) 'Category: $_categoryFilter',
      if (_reviewTagFilter != parameterReviewTagAll) 'Tag: $_reviewTagFilter',
    ];
  }

  Future<void> _pickCurrentFile() => _pickParameterFile(isBaseline: false);

  Future<void> _pickBaselineFile() => _pickParameterFile(isBaseline: true);

  Future<void> _exportDiffReport() async {
    if (!_canExportDiffReport) return;

    final exportEntries = _exportFilteredView
        ? _filteredDiffEntries
        : _diffEntries;
    final report = buildParameterDiffMarkdownReport(
      generatedAt: DateTime.now().toLocal(),
      currentFileName: _currentFileName,
      baselineFileName: _baselineFileName,
      currentParameterCount: _currentParameters.length,
      baselineParameterCount: _baselineParameters.length,
      entries: exportEntries,
      filterSummary: _reportFilterSummary(filteredReport: _exportFilteredView),
      currentParseResult: _currentParseResult,
      baselineParseResult: _baselineParseResult,
      currentParserNotes: _currentParseResult?.notes ?? const [],
      baselineParserNotes: _baselineParseResult?.notes ?? const [],
    );

    final exportPath = await _selectReportPath();
    if (exportPath == null) return;

    try {
      await File(exportPath).writeAsString(report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported parameter diff report to $exportPath'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not export parameter diff report.'),
        ),
      );
    }
  }

  Future<String?> _selectReportPath() async {
    const typeGroup = XTypeGroup(label: 'Markdown', extensions: ['md']);
    try {
      final location = await getSaveLocation(
        acceptedTypeGroups: [typeGroup],
        suggestedName: 'mavlink_gcs_parameter_diff_report.md',
      );
      return location?.path;
    } catch (_) {
      return _defaultReportPath();
    }
  }

  Future<void> _pickParameterFile({required bool isBaseline}) async {
    const typeGroup = XTypeGroup(
      label: 'ArduPilot parameters',
      extensions: ['param', 'parm', 'txt'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null || !mounted) return;

    try {
      final contents = await File(file.path).readAsString();
      final parseResult = parseParameterFileWithReport(contents);
      if (!mounted) return;
      setState(() {
        if (isBaseline) {
          _baselineFilePath = file.path;
          _baselineParameters = parseResult.entries;
          _baselineParseResult = parseResult;
        } else {
          _currentFilePath = file.path;
          _currentParameters = parseResult.entries;
          _currentParseResult = parseResult;
        }
        _errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (isBaseline) {
          _baselineFilePath = file.path;
          _baselineParameters = const [];
          _baselineParseResult = null;
        } else {
          _currentFilePath = file.path;
          _currentParameters = const [];
          _currentParseResult = null;
        }
        _errorText = 'Could not read parameter file.';
      });
    }
  }

  bool _matchesQuery(ParameterDiffEntry entry, String query) {
    final searchableText = [
      entry.name,
      entry.baselineValue ?? '',
      entry.currentValue ?? '',
      entry.status.label,
      entry.category,
      entry.relevanceTag ?? '',
    ].join(' ').toLowerCase();
    return searchableText.contains(query);
  }

  String _comparisonStatus(ParameterDiffSummary summary) {
    if (!_hasCurrentParameters && !_hasBaselineParameters) {
      return 'Waiting for parameter files';
    }
    if (_hasCurrentParameters && !_hasBaselineParameters) {
      return 'Current loaded';
    }
    if (!_hasCurrentParameters && _hasBaselineParameters) {
      return 'Baseline loaded';
    }
    if (summary.changed == 0 && summary.added == 0 && summary.removed == 0) {
      return 'Ready to compare - no differences found';
    }
    return 'Ready to compare - differences found';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _filteredDiffEntries;
    final summary = _summary;
    final statusText = _comparisonStatus(summary);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Offline Parameters',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Inspect and compare saved parameter files without connecting to a vehicle.',
              style: TextStyle(
                color: Color(0xFFC8D2DC),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            const _SafetyLabel(),
            const SizedBox(height: 16),
            _ParameterWorkflow(
              hasCurrent: _hasCurrentParameters,
              hasBaseline: _hasBaselineParameters,
              hasComparison: _hasComparison,
              canExport: _canExportDiffReport,
              onImportCurrent: _pickCurrentFile,
              onImportBaseline: _pickBaselineFile,
              onExport: _canExportDiffReport ? _exportDiffReport : null,
            ),
            const SizedBox(height: 16),
            _ComparisonStatusPanel(
              statusText: statusText,
              canExport: _canExportDiffReport,
              hasDuplicateWarnings: _hasDuplicateWarnings,
            ),
            const SizedBox(height: 16),
            _FileRoleGrid(
              currentFileName: _currentFileName,
              baselineFileName: _baselineFileName,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            _ComparisonSummaryGrid(
              currentCount: _currentParameters.length,
              baselineCount: _baselineParameters.length,
              summary: summary,
            ),
            const SizedBox(height: 18),
            _ReviewControls(
              searchController: _searchController,
              filters: _ParameterFilters(
                selectedStatus: _statusFilter,
                selectedSortMode: _sortMode,
                selectedDisplayMode: _displayMode,
                selectedCategory: _categoryFilter,
                selectedReviewTag: _reviewTagFilter,
                activeFilterLabels: _activeFilterLabels,
                onStatusSelected: (status) =>
                    setState(() => _statusFilter = status),
                onSortSelected: (sortMode) =>
                    setState(() => _sortMode = sortMode),
                onDisplayModeSelected: (displayMode) =>
                    setState(() => _displayMode = displayMode),
                onCategorySelected: (category) =>
                    setState(() => _categoryFilter = category),
                onReviewTagSelected: (tag) =>
                    setState(() => _reviewTagFilter = tag),
              ),
              onSearchChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            _ParameterDiffList(
              entries: filteredEntries,
              hasComparison: _hasComparison,
              hasActiveFilters: _hasActiveFilters,
              displayMode: _displayMode,
            ),
            CheckboxListTile(
              value: _exportFilteredView,
              onChanged: _canExportDiffReport
                  ? (value) =>
                        setState(() => _exportFilteredView = value ?? false)
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Export current filtered view'),
              subtitle: const Text(
                'Markdown export stays offline and read-only.',
              ),
            ),
            const SizedBox(height: 8),
            _ParameterExpansionTile(
              title: 'File details',
              child: Text(
                'Current: ${_currentFilePath ?? 'None'}\nBaseline: ${_baselineFilePath ?? 'None'}',
                style: const TextStyle(color: Color(0xFFC8D2DC), height: 1.35),
              ),
            ),
            _ParameterExpansionTile(
              title: 'Parser notes',
              child: _ParserNotes(
                currentResult: _currentParseResult,
                baselineResult: _baselineParseResult,
              ),
            ),
            _ParameterExpansionTile(
              title: 'Duplicate parameters',
              child: _DuplicateParametersSummary(
                currentResult: _currentParseResult,
                baselineResult: _baselineParseResult,
              ),
            ),
            const _ParameterExpansionTile(
              title: 'Category and review tag rules',
              child: _CategoryRuleNotes(),
            ),
            const _ParameterExpansionTile(
              title: 'Safety policy',
              child: Text(
                'Level 0 offline comparison only. No vehicle connection is used, no live parameters are requested, no MAVLink messages are sent, and no parameters are written.',
                style: TextStyle(color: Color(0xFFC8D2DC), height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fileName(String? path, {required String fallback}) {
    if (path == null) return fallback;
    return path.replaceAll('\\', '/').split('/').last;
  }

  String _defaultReportPath() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    return '$home/mavlink_gcs_parameter_diff_report.md';
  }

  ParameterReportFilterSummary _reportFilterSummary({
    required bool filteredReport,
  }) {
    final searchQuery = _searchController.text.trim();
    return ParameterReportFilterSummary(
      filteredReport: filteredReport,
      searchQuery: searchQuery.isEmpty ? null : searchQuery,
      statusLabel: _statusFilter?.label,
      categoryLabel: _categoryFilter == parameterCategoryAll
          ? null
          : _categoryFilter,
      reviewTagLabel: _reviewTagFilter == parameterReviewTagAll
          ? null
          : _reviewTagFilter,
    );
  }
}

class _SafetyLabel extends StatelessWidget {
  const _SafetyLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF65D890).withValues(alpha: 0.12),
        border: Border.all(
          color: const Color(0xFF65D890).withValues(alpha: 0.45),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.visibility, size: 18, color: Color(0xFF65D890)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline comparison only · No vehicle communication',
              style: TextStyle(
                color: Color(0xFF65D890),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParameterWorkflow extends StatelessWidget {
  const _ParameterWorkflow({
    required this.hasCurrent,
    required this.hasBaseline,
    required this.hasComparison,
    required this.canExport,
    required this.onImportCurrent,
    required this.onImportBaseline,
    required this.onExport,
  });

  final bool hasCurrent;
  final bool hasBaseline;
  final bool hasComparison;
  final bool canExport;
  final VoidCallback onImportCurrent;
  final VoidCallback onImportBaseline;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final columns = constraints.maxWidth >= 1120
            ? 4
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _WorkflowStep(
              width: width,
              index: 1,
              label: 'Import current file',
              description: 'The settings file being reviewed.',
              complete: hasCurrent,
              action: FilledButton.icon(
                style: _primaryButtonStyle,
                onPressed: onImportCurrent,
                icon: const Icon(Icons.folder_open),
                label: const Text('Import current parameter file'),
              ),
            ),
            _WorkflowStep(
              width: width,
              index: 2,
              label: 'Import baseline file',
              description: 'The known-good or reference file.',
              complete: hasBaseline,
              action: OutlinedButton.icon(
                style: _secondaryButtonStyle,
                onPressed: onImportBaseline,
                icon: const Icon(Icons.folder_open),
                label: const Text('Import baseline parameter file'),
              ),
            ),
            _WorkflowStep(
              width: width,
              index: 3,
              label: 'Review differences',
              description: 'Compare current values against baseline values.',
              complete: hasComparison,
            ),
            _WorkflowStep(
              width: width,
              index: 4,
              label: 'Export report',
              description: 'Save a Markdown review record.',
              complete: canExport,
              action: OutlinedButton.icon(
                style: _secondaryButtonStyle,
                onPressed: onExport,
                icon: const Icon(Icons.description),
                label: const Text('Export report'),
              ),
            ),
          ],
        );
      },
    );
  }

  ButtonStyle get _primaryButtonStyle {
    return FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
    );
  }

  ButtonStyle get _secondaryButtonStyle {
    return OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({
    required this.width,
    required this.index,
    required this.label,
    required this.description,
    required this.complete,
    this.action,
  });

  final double width;
  final int index;
  final String label;
  final String description;
  final bool complete;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = complete ? const Color(0xFF65D890) : const Color(0xFF98A6B3);
    return SizedBox(
      width: width,
      height: 188,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF151A20),
          border: Border.all(color: const Color(0xFF29323B)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step $index',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFFE7EDF3),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  complete ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: color,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFC8D2DC),
                fontSize: 12,
                height: 1.3,
              ),
            ),
            const Spacer(),
            if (action != null)
              SizedBox(width: double.infinity, child: action!)
            else
              const Text(
                'Available after both files are imported.',
                style: TextStyle(
                  color: Color(0xFF98A6B3),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonStatusPanel extends StatelessWidget {
  const _ComparisonStatusPanel({
    required this.statusText,
    required this.canExport,
    required this.hasDuplicateWarnings,
  });

  final String statusText;
  final bool canExport;
  final bool hasDuplicateWarnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        border: Border.all(color: const Color(0xFF29323B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.fact_check, size: 20, color: Color(0xFF8FB4FF)),
          Text(
            'Comparison status: $statusText',
            style: const TextStyle(
              color: Color(0xFFE7EDF3),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (!canExport)
            const Text(
              'Export is available after a comparison is created.',
              style: TextStyle(color: Color(0xFF98A6B3), fontSize: 13),
            ),
          if (hasDuplicateWarnings)
            const Text(
              'Duplicate parameter names detected. Last parsed value is used for comparison.',
              style: TextStyle(
                color: Color(0xFFFFCF70),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _ComparisonSummaryGrid extends StatelessWidget {
  const _ComparisonSummaryGrid({
    required this.currentCount,
    required this.baselineCount,
    required this.summary,
  });

  final int currentCount;
  final int baselineCount;
  final ParameterDiffSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 1180
            ? 6
            : constraints.maxWidth >= 820
            ? 3
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _SummaryPill(
              width: width,
              label: 'Current parsed count',
              value: currentCount,
            ),
            _SummaryPill(
              width: width,
              label: 'Baseline parsed count',
              value: baselineCount,
            ),
            _SummaryPill(
              width: width,
              label: 'Changed',
              value: summary.changed,
            ),
            _SummaryPill(width: width, label: 'Added', value: summary.added),
            _SummaryPill(
              width: width,
              label: 'Removed',
              value: summary.removed,
            ),
            _SummaryPill(
              width: width,
              label: 'Unchanged',
              value: summary.unchanged,
            ),
          ],
        );
      },
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.width,
    required this.label,
    required this.value,
  });

  final double width;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF151A20),
          border: Border.all(color: const Color(0xFF29323B)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFF98A6B3), fontSize: 13),
              ),
            ),
            Text(
              value.toString(),
              style: const TextStyle(
                color: Color(0xFFE7EDF3),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileRoleGrid extends StatelessWidget {
  const _FileRoleGrid({
    required this.currentFileName,
    required this.baselineFileName,
  });

  final String currentFileName;
  final String baselineFileName;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final columns = constraints.maxWidth >= 760 ? 2 : 1;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _FileRoleCard(
              width: width,
              icon: Icons.flight_takeoff,
              label: 'Current file',
              helper: 'Values being checked',
              value: currentFileName,
            ),
            _FileRoleCard(
              width: width,
              icon: Icons.library_books,
              label: 'Baseline file',
              helper: 'Reference values for comparison',
              value: baselineFileName,
            ),
          ],
        );
      },
    );
  }
}

class _FileRoleCard extends StatelessWidget {
  const _FileRoleCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.helper,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String helper;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF151A20),
          border: Border.all(color: const Color(0xFF29323B)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF8FB4FF), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF98A6B3),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE7EDF3),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    helper,
                    style: const TextStyle(
                      color: Color(0xFF98A6B3),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewControls extends StatelessWidget {
  const _ReviewControls({
    required this.searchController,
    required this.filters,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final Widget filters;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10161D),
        border: Border.all(color: const Color(0xFF31404D)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: Color(0xFF8FB4FF), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Search and filters',
                  style: TextStyle(
                    color: Color(0xFFE7EDF3),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Search parameters',
              prefixIcon: Icon(Icons.search),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 12),
          filters,
        ],
      ),
    );
  }
}

class _ParameterFilters extends StatelessWidget {
  const _ParameterFilters({
    required this.selectedStatus,
    required this.selectedSortMode,
    required this.selectedDisplayMode,
    required this.selectedCategory,
    required this.selectedReviewTag,
    required this.activeFilterLabels,
    required this.onStatusSelected,
    required this.onSortSelected,
    required this.onDisplayModeSelected,
    required this.onCategorySelected,
    required this.onReviewTagSelected,
  });

  final ParameterDiffStatus? selectedStatus;
  final ParameterDiffSortMode selectedSortMode;
  final ParameterDiffDisplayMode selectedDisplayMode;
  final String selectedCategory;
  final String selectedReviewTag;
  final List<String> activeFilterLabels;
  final ValueChanged<ParameterDiffStatus?> onStatusSelected;
  final ValueChanged<ParameterDiffSortMode> onSortSelected;
  final ValueChanged<ParameterDiffDisplayMode> onDisplayModeSelected;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onReviewTagSelected;

  @override
  Widget build(BuildContext context) {
    final statuses = [
      null,
      ParameterDiffStatus.changed,
      ParameterDiffStatus.added,
      ParameterDiffStatus.removed,
      ParameterDiffStatus.unchanged,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF11161D),
        border: Border.all(color: const Color(0xFF29323B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statuses.map((status) {
              final label = status == null ? 'All' : status.label;
              return ChoiceChip(
                label: Text(label),
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                selected: selectedStatus == status,
                onSelected: (_) => onStatusSelected(status),
                visualDensity: VisualDensity.standard,
                materialTapTargetSize: MaterialTapTargetSize.padded,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ParameterDiffDisplayMode>(
            initialValue: selectedDisplayMode,
            decoration: const InputDecoration(
              labelText: 'Display mode',
              prefixIcon: Icon(Icons.view_list),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            items: ParameterDiffDisplayMode.values
                .map(
                  (displayMode) => DropdownMenuItem<ParameterDiffDisplayMode>(
                    value: displayMode,
                    child: Text(displayMode.label),
                  ),
                )
                .toList(),
            onChanged: (displayMode) {
              if (displayMode != null) onDisplayModeSelected(displayMode);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ParameterDiffSortMode>(
            initialValue: selectedSortMode,
            decoration: const InputDecoration(
              labelText: 'Sort by',
              prefixIcon: Icon(Icons.sort),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            items: ParameterDiffSortMode.values
                .map(
                  (sortMode) => DropdownMenuItem<ParameterDiffSortMode>(
                    value: sortMode,
                    child: Text(sortMode.label),
                  ),
                )
                .toList(),
            onChanged: (sortMode) {
              if (sortMode != null) onSortSelected(sortMode);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            items: parameterCategories
                .map(
                  (category) => DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  ),
                )
                .toList(),
            onChanged: (category) {
              if (category != null) onCategorySelected(category);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedReviewTag,
            decoration: const InputDecoration(
              labelText: 'Review tag',
              prefixIcon: Icon(Icons.label_outline),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            items: parameterReviewTags
                .map(
                  (tag) =>
                      DropdownMenuItem<String>(value: tag, child: Text(tag)),
                )
                .toList(),
            onChanged: (tag) {
              if (tag != null) onReviewTagSelected(tag);
            },
          ),
          if (activeFilterLabels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activeFilterLabels
                  .map((label) => _MetadataBadge(label: label))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParameterDiffList extends StatelessWidget {
  const _ParameterDiffList({
    required this.entries,
    required this.hasComparison,
    required this.hasActiveFilters,
    required this.displayMode,
  });

  final List<ParameterDiffEntry> entries;
  final bool hasComparison;
  final bool hasActiveFilters;
  final ParameterDiffDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        constraints: const BoxConstraints(minHeight: 132),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF151A20),
          border: Border.all(color: const Color(0xFF29323B)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasComparison ? Icons.check_circle_outline : Icons.upload_file,
              color: hasComparison
                  ? const Color(0xFF65D890)
                  : const Color(0xFF8FB4FF),
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              hasComparison && hasActiveFilters
                  ? 'No parameters match the current filters.'
                  : hasComparison
                  ? 'No parameter differences found.'
                  : 'Import both parameter files to compare.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE7EDF3),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Comparison is offline only. No vehicle communication or parameter writes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF98A6B3),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 360),
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        border: Border.all(color: const Color(0xFF29323B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                for (final group in groupParameterDiffEntries(
                  entries,
                  displayMode: displayMode,
                ))
                  _ParameterDiffGroupSection(group: group),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParameterDiffGroupSection extends StatelessWidget {
  const _ParameterDiffGroupSection({required this.group});

  final ParameterDiffGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          color: const Color(0xFF11161D),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${group.label} (${group.count})',
                  style: const TextStyle(
                    color: Color(0xFFE7EDF3),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const _ParameterDiffHeader(),
        const Divider(height: 1),
        for (final entry in group.entries) ...[
          _ParameterDiffRow(entry: entry),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _ParameterDiffHeader extends StatelessWidget {
  const _ParameterDiffHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Parameter',
              style: TextStyle(color: Color(0xFF98A6B3), fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Baseline',
              style: TextStyle(color: Color(0xFF98A6B3), fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Current',
              style: TextStyle(color: Color(0xFF98A6B3), fontSize: 12),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Category / Review tag',
              style: TextStyle(color: Color(0xFF98A6B3), fontSize: 12),
            ),
          ),
          SizedBox(width: 88),
        ],
      ),
    );
  }
}

class _ParameterDiffRow extends StatelessWidget {
  const _ParameterDiffRow({required this.entry});

  final ParameterDiffEntry entry;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _ParameterNameText(name: entry.name)),
          Expanded(
            flex: 2,
            child: _ValueText(value: entry.baselineValue ?? '--'),
          ),
          Expanded(
            flex: 2,
            child: _ValueText(value: entry.currentValue ?? '--'),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MetadataBadge(label: entry.category),
                _MetadataBadge(label: entry.relevanceTag ?? 'No tag'),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusBadge(status: entry.status),
        ],
      ),
      children: [_ParameterDetail(entry: entry)],
    );
  }
}

class _ParameterNameText extends StatelessWidget {
  const _ParameterNameText({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFFE7EDF3),
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ParameterDetail extends StatelessWidget {
  const _ParameterDetail({required this.entry});

  final ParameterDiffEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF11161D),
        border: Border.all(color: const Color(0xFF29323B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailLine(label: 'Parameter', value: entry.name),
          _DetailLine(
            label: 'Baseline value',
            value: entry.baselineValue ?? '--',
          ),
          _DetailLine(
            label: 'Current value',
            value: entry.currentValue ?? '--',
          ),
          _DetailLine(label: 'Status', value: entry.status.label),
          _DetailLine(label: 'Category', value: entry.category),
          _DetailLine(
            label: 'Review tag',
            value: entry.relevanceTag ?? 'No tag',
          ),
          const SizedBox(height: 8),
          const Text(
            'Category and review tag are prefix-based review hints only.',
            style: TextStyle(color: Color(0xFF98A6B3), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF98A6B3), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFE7EDF3),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataBadge extends StatelessWidget {
  const _MetadataBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF202832),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFC8D2DC),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ValueText extends StatelessWidget {
  const _ValueText({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFFC8D2DC),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ParserNotes extends StatelessWidget {
  const _ParserNotes({
    required this.currentResult,
    required this.baselineResult,
  });

  final ParameterParseResult? currentResult;
  final ParameterParseResult? baselineResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ParserNotesBlock(title: 'Current file', result: currentResult),
        const SizedBox(height: 10),
        _ParserNotesBlock(title: 'Baseline file', result: baselineResult),
      ],
    );
  }
}

class _ParserNotesBlock extends StatelessWidget {
  const _ParserNotesBlock({required this.title, required this.result});

  final String title;
  final ParameterParseResult? result;

  @override
  Widget build(BuildContext context) {
    final notes =
        result?.notes ??
        const [
          'No parameter file imported.',
          'Supports Mission Planner/ArduPilot-style PARAM_NAME,VALUE, PARAM_NAME VALUE, and PARAM_NAME=VALUE rows.',
        ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        border: Border.all(color: const Color(0xFF29323B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFE7EDF3),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (result != null) ...[
            _ParserDiagnosticsSummary(fileLabel: title, result: result!),
            const SizedBox(height: 8),
          ],
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '- $note',
                style: const TextStyle(color: Color(0xFFC8D2DC), height: 1.3),
              ),
            ),
        ],
      ),
    );
  }
}

class _ParserDiagnosticsSummary extends StatelessWidget {
  const _ParserDiagnosticsSummary({
    required this.fileLabel,
    required this.result,
  });

  final String fileLabel;
  final ParameterParseResult result;

  @override
  Widget build(BuildContext context) {
    final visibleIssues = result.issues.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetadataBadge(label: 'Parsed: ${result.parsedCount}'),
            _MetadataBadge(label: 'Comments: ${result.commentLineCount}'),
            _MetadataBadge(
              label: 'Inline comments: ${result.inlineCommentCount}',
            ),
            _MetadataBadge(label: 'Empty: ${result.emptyLineCount}'),
            _MetadataBadge(label: 'Invalid: ${result.invalidLineCount}'),
            _MetadataBadge(label: 'Duplicates: ${result.duplicateNameCount}'),
          ],
        ),
        if (result.duplicateNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Duplicate names: ${result.duplicateNames.take(8).join(', ')}',
            style: const TextStyle(color: Color(0xFFFFCF70), height: 1.3),
          ),
          const Text(
            'Last parsed value is used for comparison.',
            style: TextStyle(color: Color(0xFFFFCF70), height: 1.3),
          ),
        ],
        if (visibleIssues.isNotEmpty) ...[
          const SizedBox(height: 8),
          const _ParserIssueHeader(),
          for (final issue in visibleIssues)
            _ParserIssueRow(fileLabel: fileLabel, issue: issue),
          if (result.issues.length > visibleIssues.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Showing first ${visibleIssues.length} of ${result.issues.length} parser issues.',
                style: const TextStyle(
                  color: Color(0xFF98A6B3),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ParserIssueHeader extends StatelessWidget {
  const _ParserIssueHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 82, child: _IssueHeaderText('File')),
          SizedBox(width: 50, child: _IssueHeaderText('Line')),
          Expanded(flex: 2, child: _IssueHeaderText('Issue')),
          Expanded(flex: 2, child: _IssueHeaderText('Raw text')),
        ],
      ),
    );
  }
}

class _IssueHeaderText extends StatelessWidget {
  const _IssueHeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Color(0xFF98A6B3), fontSize: 11),
    );
  }
}

class _ParserIssueRow extends StatelessWidget {
  const _ParserIssueRow({required this.fileLabel, required this.issue});

  final String fileLabel;
  final ParameterParseIssue issue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 82, child: _IssueCell(fileLabel)),
          SizedBox(width: 50, child: _IssueCell(issue.lineNumber.toString())),
          Expanded(flex: 2, child: _IssueCell(issue.message)),
          Expanded(flex: 2, child: _IssueCell(issue.line ?? '--')),
        ],
      ),
    );
  }
}

class _IssueCell extends StatelessWidget {
  const _IssueCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
      style: const TextStyle(color: Color(0xFFC8D2DC), fontSize: 11),
    );
  }
}

class _DuplicateParametersSummary extends StatelessWidget {
  const _DuplicateParametersSummary({
    required this.currentResult,
    required this.baselineResult,
  });

  final ParameterParseResult? currentResult;
  final ParameterParseResult? baselineResult;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ..._rowsFor('Current', currentResult),
      ..._rowsFor('Baseline', baselineResult),
    ];

    if (rows.isEmpty) {
      return const Text(
        'No duplicate parameter names detected.',
        style: TextStyle(color: Color(0xFFC8D2DC), height: 1.35),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        border: Border.all(color: const Color(0xFF29323B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Duplicate names are reported. Last parsed value is used for comparison.',
            style: TextStyle(color: Color(0xFFFFCF70), height: 1.35),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(child: _IssueHeaderText('Parameter')),
              SizedBox(width: 90, child: _IssueHeaderText('File')),
              Expanded(child: _IssueHeaderText('Policy')),
            ],
          ),
          const SizedBox(height: 4),
          for (final row in rows) row,
        ],
      ),
    );
  }

  List<Widget> _rowsFor(String fileLabel, ParameterParseResult? result) {
    if (result == null || result.duplicateNames.isEmpty) return const [];
    return result.duplicateNames.map((name) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(child: _IssueCell(name)),
            SizedBox(width: 90, child: _IssueCell(fileLabel)),
            const Expanded(child: _IssueCell('Last parsed value used')),
          ],
        ),
      );
    }).toList();
  }
}

class _CategoryRuleNotes extends StatelessWidget {
  const _CategoryRuleNotes();

  @override
  Widget build(BuildContext context) {
    const rules = [
      'Categories and tags are local prefix-based review hints.',
      'They are not official ArduPilot metadata.',
      'They do not assign severity, block anything, or communicate with the vehicle.',
      'BATT_/BAT_/battery number patterns -> Battery / Power relevant',
      'GPS_/GNSS_/GPS number patterns -> GPS / GNSS / Navigation relevant',
      'EKF_/EK*/AHRS_/INS_ -> EKF / AHRS / State-estimation relevant',
      'FS_/FENCE_ -> Failsafe / Failsafe relevant',
      'ARMING_ -> Arming / Arming relevant',
      'RC_/RSSI_/RC number patterns -> RC / Radio / Radio-control input relevant',
      'SERVO_/MOT_/Q_M_/SERVO number patterns -> Motors / Servo / Actuator-output relevant',
      'NAV_/WP_/WPNAV_ -> Navigation / Navigation relevant',
      'MIS_/MISSION_/DO_ -> Mission / No review tag',
      'SERIAL_/MAV_/SR* -> Communication / Communication relevant',
      'Everything else -> Other / No tag',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        border: Border.all(color: const Color(0xFF29323B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '- $rule',
                style: const TextStyle(color: Color(0xFFC8D2DC), height: 1.3),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ParameterDiffStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Color _colorForStatus(ParameterDiffStatus status) {
    switch (status) {
      case ParameterDiffStatus.changed:
        return const Color(0xFFFFCF70);
      case ParameterDiffStatus.added:
        return const Color(0xFF65D890);
      case ParameterDiffStatus.removed:
        return const Color(0xFFFF6B6B);
      case ParameterDiffStatus.unchanged:
        return const Color(0xFF98A6B3);
    }
  }
}

class _ParameterExpansionTile extends StatelessWidget {
  const _ParameterExpansionTile({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 10),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        children: [child],
      ),
    );
  }
}
