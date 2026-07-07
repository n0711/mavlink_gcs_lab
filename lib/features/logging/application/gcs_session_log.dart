import 'dart:convert';
import 'dart:io';

class GcsSessionLog {
  GcsSessionLog({DateTime? startedAt}) : this._(startedAt, null);

  GcsSessionLog.forTesting({
    DateTime? startedAt,
    required Directory baseDirectory,
  }) : this._(startedAt, baseDirectory);

  GcsSessionLog._(DateTime? startedAt, this._baseDirectory)
    : _startedAt = (startedAt ?? DateTime.now()).toUtc();

  final DateTime _startedAt;
  final Directory? _baseDirectory;

  Future<void> record(String event, Map<String, Object?> fields) async {
    try {
      final file = await _logFile();
      final payload = <String, Object?>{
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'session_started_at': _startedAt.toIso8601String(),
        'event': event,
        ...fields,
      };
      await file.writeAsString(
        '${jsonEncode(payload)}\n',
        mode: FileMode.append,
      );
    } on Object {
      // Diagnostics logging must never interrupt receive-only monitoring.
    }
  }

  Future<File> _logFile() async {
    final baseDirectory = _baseDirectory ?? _defaultBaseDirectory();
    final logDirectory = Directory('${baseDirectory.path}/session_logs');
    if (!await logDirectory.exists()) {
      await logDirectory.create(recursive: true);
    }
    final sessionStamp = _startedAt
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    return File('${logDirectory.path}/gcs_session_$sessionStamp.jsonl');
  }

  Directory _defaultBaseDirectory() {
    final home = Platform.environment['HOME'];
    if (home == null || home.trim().isEmpty) {
      return Directory('${Directory.systemTemp.path}/mavlink_gcs_portfolio');
    }
    return Directory('$home/.mavlink_gcs_portfolio');
  }
}
