import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mavlink_gcs_portfolio/features/logging/application/gcs_session_log.dart';

void main() {
  group('GcsSessionLog', () {
    test('writes valid local JSONL diagnostics with UTC timestamps', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'mavlink_gcs_portfolio_session_log_test_',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final log = GcsSessionLog.forTesting(
        startedAt: DateTime.parse('2026-07-07T08:00:00+03:00'),
        baseDirectory: tempDirectory,
      );

      await log.record('telemetry_source_start', {
        'source_type': 'UDP JSON adapter',
        'receive_only': true,
      });

      final logDirectory = Directory('${tempDirectory.path}/session_logs');
      final files = await logDirectory
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.jsonl'))
          .cast<File>()
          .toList();

      expect(files, hasLength(1));
      final lines = await files.single.readAsLines();
      expect(lines, hasLength(1));

      final decoded = jsonDecode(lines.single) as Map<String, Object?>;
      expect(decoded['event'], 'telemetry_source_start');
      expect(decoded['source_type'], 'UDP JSON adapter');
      expect(decoded['receive_only'], isTrue);
      expect(decoded['session_started_at'], '2026-07-07T05:00:00.000Z');
      expect(DateTime.parse(decoded['timestamp']! as String).isUtc, isTrue);
    });

    test(
      'swallows file system errors so logging cannot crash the app',
      () async {
        final tempDirectory = await Directory.systemTemp.createTemp(
          'mavlink_gcs_portfolio_session_log_blocked_',
        );
        addTearDown(() async {
          if (await tempDirectory.exists()) {
            await tempDirectory.delete(recursive: true);
          }
        });

        await File(
          '${tempDirectory.path}/session_logs',
        ).writeAsString('not a directory');
        final log = GcsSessionLog.forTesting(baseDirectory: tempDirectory);

        await expectLater(log.record('telemetry_source_start', {}), completes);
      },
    );
  });
}
