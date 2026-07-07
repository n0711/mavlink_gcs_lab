import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/log_replay_helper_resolver.dart';

enum _ReplaySpeed {
  visual(label: '1x visual replay', argument: '1'),
  smoke(label: 'Fast smoke test', argument: '0');

  const _ReplaySpeed({required this.label, required this.argument});

  final String label;
  final String argument;
}

class LogReplayPanel extends StatefulWidget {
  const LogReplayPanel({super.key});

  @override
  State<LogReplayPanel> createState() => _LogReplayPanelState();
}

class _LogReplayPanelState extends State<LogReplayPanel> {
  static const _targetHost = '127.0.0.1';
  static const _targetPort = 16000;
  String? _selectedLogPath;
  Process? _runningProcess;
  _ReplaySpeed _selectedSpeed = _ReplaySpeed.visual;
  String _status = 'Select a log to replay';
  String? _errorMessage;
  int? _lastExitCode;
  var _detectedOutputPacketLines = 0;
  final List<String> _outputLines = [];

  bool get _isRunning => _runningProcess != null;

  String? get _scriptPath {
    return resolveReplayHelperPath(Platform.environment);
  }

  bool get _scriptExists {
    final scriptPath = _scriptPath;
    return scriptPath != null && File(scriptPath).existsSync();
  }

  bool get _canStartReplay {
    return _selectedLogPath != null && !_isRunning && _scriptExists;
  }

  String get _displayStatus {
    if (_selectedLogPath == null && !_isRunning) {
      return 'Select a log to replay';
    }
    if (_selectedLogPath != null && !_isRunning && !_scriptExists) {
      return 'Replay script not found';
    }
    return _status;
  }

  String? get _displayErrorMessage {
    if (_selectedLogPath != null && !_isRunning && !_scriptExists) {
      final scriptPath = _scriptPath;
      return replayHelperPathHelp(scriptPath);
    }
    return _errorMessage;
  }

  String get _playTooltip {
    if (_selectedLogPath == null) return 'Select a log first';
    if (!_scriptExists) return 'Replay script not found';
    if (_isRunning) return 'Stop replay';
    return 'Play replay';
  }

  String get _selectedFileName {
    final path = _selectedLogPath;
    if (path == null) return 'No log selected';
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').last;
  }

  String get _replayCommand {
    final logPath = _selectedLogPath ?? 'test_usv.bin';
    final scriptPath = _scriptPath ?? '\$$replayHelperPathEnvironmentVariable';
    return 'python3 "$scriptPath" "$logPath" --target-host $_targetHost --target-port $_targetPort --speed ${_selectedSpeed.argument}';
  }

  Future<void> _pickLog() async {
    const logTypeGroup = XTypeGroup(
      label: 'ArduPilot logs',
      extensions: ['BIN', 'bin', 'tlog', 'TLOG'],
    );
    final file = await openFile(acceptedTypeGroups: [logTypeGroup]);
    if (file == null || !mounted) return;

    setState(() {
      _selectedLogPath = file.path;
      _status = 'Ready to replay';
      _errorMessage = null;
      _lastExitCode = null;
      _detectedOutputPacketLines = 0;
      _outputLines.clear();
    });
  }

  Future<void> _toggleReplay() async {
    if (_isRunning) {
      _stopReplay();
      return;
    }
    await _startReplay();
  }

  Future<void> _startReplay() async {
    final selectedLogPath = _selectedLogPath;
    final scriptPath = _scriptPath;

    if (selectedLogPath == null) {
      setState(() {
        _status = 'Select a log first';
        _errorMessage = null;
      });
      return;
    }
    if (scriptPath == null || !File(scriptPath).existsSync()) {
      setState(() {
        _status = 'Replay script not found';
        _errorMessage = replayHelperPathHelp(scriptPath);
      });
      return;
    }

    setState(() {
      _status = 'Starting replay';
      _errorMessage = null;
      _lastExitCode = null;
      _detectedOutputPacketLines = 0;
      _outputLines.clear();
    });

    try {
      final process = await Process.start('python3', [
        scriptPath,
        selectedLogPath,
        '--target-host',
        _targetHost,
        '--target-port',
        _targetPort.toString(),
        '--speed',
        _selectedSpeed.argument,
      ]);

      if (!mounted) {
        process.kill();
        return;
      }

      setState(() {
        _runningProcess = process;
        _status = 'Replay running';
      });

      _listenToOutput(process.stdout);
      _listenToOutput(process.stderr);

      unawaited(
        process.exitCode.then((exitCode) {
          if (!mounted || _runningProcess != process) return;
          setState(() {
            _runningProcess = null;
            if (exitCode == 0) {
              _status = _detectedOutputPacketLines > 0
                  ? 'Replay complete'
                  : 'Replay finished but no packets were reported';
              _errorMessage = null;
            } else {
              _status = 'Replay failed';
              _errorMessage = 'Replay process exited with code $exitCode.';
            }
            _lastExitCode = exitCode;
          });
        }),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _runningProcess = null;
        _status = 'Replay failed';
        _errorMessage = error.toString();
      });
    }
  }

  void _stopReplay() {
    final process = _runningProcess;
    if (process == null) return;
    process.kill();
    setState(() {
      _runningProcess = null;
      _status = 'Replay stopped';
      _errorMessage = null;
    });
  }

  void _listenToOutput(Stream<List<int>> stream) {
    stream.transform(utf8.decoder).transform(const LineSplitter()).listen((
      line,
    ) {
      if (!mounted) return;
      setState(() {
        _outputLines.add(line);
        if (_looksLikePacketOutput(line)) {
          _detectedOutputPacketLines += 1;
        }
        if (_outputLines.length > 10) {
          _outputLines.removeRange(0, _outputLines.length - 10);
        }
      });
    });
  }

  bool _looksLikePacketOutput(String line) {
    final lower = line.toLowerCase();
    return lower.contains('packet') ||
        lower.contains('sent') ||
        lower.contains('decoded') ||
        lower.contains('replay');
  }

  Future<void> _copyCommand() async {
    await Clipboard.setData(ClipboardData(text: _replayCommand));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Replay command copied')));
  }

  @override
  void dispose() {
    _runningProcess?.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Log Replay',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Replay recorded telemetry into the receive-only GCS.',
              style: TextStyle(color: Color(0xFFC8D2DC), height: 1.35),
            ),
            const SizedBox(height: 14),
            _SelectedFileSummary(fileName: _selectedFileName),
            const SizedBox(height: 10),
            const _TargetLine(value: '127.0.0.1:16000'),
            const SizedBox(height: 10),
            _SpeedSelector(
              selectedSpeed: _selectedSpeed,
              enabled: !_isRunning,
              onChanged: (speed) => setState(() => _selectedSpeed = speed),
            ),
            const SizedBox(height: 10),
            _StatusLine(
              status: _displayStatus,
              errorMessage: _displayErrorMessage,
            ),
            if (_isRunning) ...[
              const SizedBox(height: 6),
              const Text(
                'Stop replay before changing log',
                style: TextStyle(color: Color(0xFFFFCF70), fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _isRunning ? null : _pickLog,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Import log'),
                ),
                OutlinedButton.icon(
                  onPressed: _copyCommand,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy command'),
                ),
                Tooltip(
                  message: _playTooltip,
                  child: FilledButton.tonalIcon(
                    onPressed: _isRunning || _canStartReplay
                        ? _toggleReplay
                        : null,
                    icon: Icon(
                      _isRunning ? Icons.stop_circle : Icons.play_arrow,
                    ),
                    label: Text(_isRunning ? 'Stop replay' : 'Play replay'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ReplayExpansionTile(
              title: 'Replay command',
              child: _CommandBox(command: _replayCommand),
            ),
            _ReplayExpansionTile(
              title: 'Replay output',
              child: _OutputBox(
                lines: _outputLines,
                exitCode: _lastExitCode,
                packetLineCount: _detectedOutputPacketLines,
              ),
            ),
            _ReplayExpansionTile(
              title: 'Selected file details',
              child: Text(
                _selectedLogPath ?? 'No log selected',
                style: const TextStyle(color: Color(0xFFC8D2DC)),
              ),
            ),
            const _ReplayExpansionTile(
              title: 'Supported logs',
              child: Text(
                '.BIN, .bin, .tlog, .TLOG',
                style: TextStyle(color: Color(0xFFC8D2DC)),
              ),
            ),
            const _ReplayExpansionTile(
              title: 'Notes',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Note(text: 'Run the replay command from a terminal.'),
                  _Note(text: 'TELEMETRY STALE after replay ends is expected.'),
                  _Note(text: 'This workflow is telemetry-only.'),
                  _Note(text: 'Replay uses the local helper process only.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status, required this.errorMessage});

  final String status;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final isError =
        status == 'Replay failed' || status == 'Replay script not found';
    final isRunning = status == 'Replay running';
    final color = isError
        ? Theme.of(context).colorScheme.error
        : isRunning
        ? const Color(0xFF65D890)
        : const Color(0xFF7DC6FF);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.38)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (status == 'Replay complete' ||
              status == 'Replay finished but no packets were reported') ...[
            const SizedBox(height: 6),
            const Text(
              'TELEMETRY STALE after replay completion is expected.',
              style: TextStyle(color: Color(0xFFC8D2DC), fontSize: 12),
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              errorMessage!,
              style: const TextStyle(color: Color(0xFFC8D2DC), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectedFileSummary extends StatelessWidget {
  const _SelectedFileSummary({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        border: Border.all(color: const Color(0xFF29323B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.insert_drive_file,
            size: 20,
            color: Color(0xFF7DC6FF),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected log',
                  style: TextStyle(color: Color(0xFF98A6B3), fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF5F7FA),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetLine extends StatelessWidget {
  const _TargetLine({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.lan, size: 18, color: Color(0xFF65D890)),
        const SizedBox(width: 8),
        const Text(
          'Replay target',
          style: TextStyle(color: Color(0xFF98A6B3), fontSize: 12),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFE7EDF3),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({
    required this.selectedSpeed,
    required this.enabled,
    required this.onChanged,
  });

  final _ReplaySpeed selectedSpeed;
  final bool enabled;
  final ValueChanged<_ReplaySpeed> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Replay speed',
          style: TextStyle(color: Color(0xFF98A6B3), fontSize: 12),
        ),
        const SizedBox(height: 6),
        SegmentedButton<_ReplaySpeed>(
          segments: _ReplaySpeed.values
              .map(
                (speed) => ButtonSegment<_ReplaySpeed>(
                  value: speed,
                  label: Text(speed.label),
                ),
              )
              .toList(),
          selected: {selectedSpeed},
          onSelectionChanged: enabled
              ? (selection) => onChanged(selection.single)
              : null,
          showSelectedIcon: false,
        ),
      ],
    );
  }
}

class _ReplayExpansionTile extends StatelessWidget {
  const _ReplayExpansionTile({required this.title, required this.child});

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
        iconColor: const Color(0xFF7DC6FF),
        collapsedIconColor: const Color(0xFF98A6B3),
        children: [Align(alignment: Alignment.centerLeft, child: child)],
      ),
    );
  }
}

class _CommandBox extends StatelessWidget {
  const _CommandBox({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF07090C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF29323B)),
      ),
      child: SelectableText(
        command,
        style: const TextStyle(
          color: Color(0xFFD5DEE8),
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }
}

class _OutputBox extends StatelessWidget {
  const _OutputBox({
    required this.lines,
    required this.exitCode,
    required this.packetLineCount,
  });

  final List<String> lines;
  final int? exitCode;
  final int packetLineCount;

  @override
  Widget build(BuildContext context) {
    final text = lines.isEmpty ? 'No replay output yet.' : lines.join('\n');

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 160),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF07090C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF29323B)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exit code: ${exitCode?.toString() ?? "--"}',
              style: const TextStyle(
                color: Color(0xFF98A6B3),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            Text(
              'Detected packet lines: $packetLineCount',
              style: const TextStyle(
                color: Color(0xFF98A6B3),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              text,
              style: const TextStyle(
                color: Color(0xFFD5DEE8),
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF98A6B3)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFC8D2DC), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
