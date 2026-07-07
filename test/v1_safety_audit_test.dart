import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V1 safety audit', () {
    test('does not introduce command-capable transport dependencies', () {
      final manifests = [
        File('pubspec.yaml').readAsStringSync(),
        File('rust/Cargo.toml').readAsStringSync(),
      ].join('\n');

      for (final dependency in const [
        'mavsdk',
        'mavsdk_server',
        'grpc',
        'protobuf',
        'tonic',
        'prost',
      ]) {
        expect(manifests, isNot(contains(dependency)));
      }
    });

    test('backend source does not expose vehicle command paths', () {
      final sourceText = _sourceFiles(
        'rust/src',
        '.rs',
      ).map((file) => file.readAsStringSync()).join('\n');

      for (final token in const [
        'COMMAND_LONG',
        'COMMAND_INT',
        'PARAM_SET',
        'MISSION_ITEM',
        'MISSION_ITEM_INT',
        'MISSION_COUNT',
        'MAV_CMD_COMPONENT_ARM_DISARM',
        'MAV_CMD_NAV_RETURN_TO_LAUNCH',
        'SET_MODE',
        'MANUAL_CONTROL',
        'RC_CHANNELS_OVERRIDE',
        'ACTUATOR_CONTROL_TARGET',
      ]) {
        expect(sourceText, isNot(contains(token)));
      }
    });
  });
}

Iterable<File> _sourceFiles(String root, String extension) sync* {
  final directory = Directory(root);
  if (!directory.existsSync()) return;

  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith(extension)) {
      yield entity;
    }
  }
}
