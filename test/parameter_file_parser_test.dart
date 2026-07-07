import 'package:flutter_test/flutter_test.dart';
import 'package:mavlink_gcs_portfolio/features/dashboard/parameter_file_parser.dart';

void main() {
  test('parses common ArduPilot parameter file formats', () {
    final result = parseParameterFileWithReport('''
# comment
// another comment

PARAM_A,1
PARAM_B 2
PARAM_C=3 # inline note
malformed
PARAM_B=4
''');
    final parameters = result.entries;

    expect(parameters, hasLength(4));
    expect(parameters[0].name, 'PARAM_A');
    expect(parameters[0].value, '1');
    expect(parameters[1].name, 'PARAM_B');
    expect(parameters[1].value, '2');
    expect(parameters[2].name, 'PARAM_C');
    expect(parameters[2].value, '3');
    expect(result.commentLineCount, 2);
    expect(result.inlineCommentCount, 1);
    expect(result.invalidLineCount, 1);
    expect(result.duplicateNames, ['PARAM_B']);
    expect(result.hasWarnings, isTrue);
    expect(result.notes, contains('Unsupported lines ignored: 1'));
    expect(
      result.notes,
      contains(
        'Duplicate names are reported. During comparison, the last parsed value for each parameter name is used.',
      ),
    );
    expect(
      result.notes,
      contains(
        'Supported Mission Planner/ArduPilot-style rows: PARAM,VALUE, PARAM VALUE, and PARAM=VALUE.',
      ),
    );
    expect(result.notes.any((note) => note.startsWith('Line 8:')), isTrue);
  });

  test('reports Mission Planner style parser diagnostics clearly', () {
    final result = parseParameterFileWithReport('''
\uFEFFARMING_CHECK,1,ignored-column
GPS2_TYPE 1
not-a-param=3
1BAD,4
// full-line comment
SERVO1_FUNCTION 33 // keep the value, strip this note
''');

    expect(result.entries.map((entry) => entry.name), [
      'ARMING_CHECK',
      'GPS2_TYPE',
      'SERVO1_FUNCTION',
    ]);
    expect(result.entries.first.value, '1');
    expect(result.entries.last.value, '33');
    expect(result.commentLineCount, 1);
    expect(result.inlineCommentCount, 1);
    expect(result.invalidLineCount, 2);
    expect(result.hasWarnings, isTrue);
    expect(
      result.issues.map((issue) => issue.message),
      contains('Extra comma-separated columns ignored.'),
    );
    expect(
      result.issues.map((issue) => issue.message),
      contains(
        'Unsupported Mission Planner/ArduPilot-style parameter line ignored.',
      ),
    );
  });
}
