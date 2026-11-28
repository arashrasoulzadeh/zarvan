import 'dart:io';

import 'package:zarvan_api/zarvan_api.dart';
import 'package:zarvan_core/zarvan_core_ops.dart';
import 'package:test/test.dart';

void main() {
  test('docs/reference/operations.md is up to date with the registry', () {
    final committed = File(
      '../../docs/reference/operations.md',
    ).readAsStringSync();
    expect(
      committed,
      renderOperationsReference(buildRegistry()),
      reason:
          'Regenerate it: cd packages/zarvan_api && dart run tool/gen_api_docs.dart > ../../docs/reference/operations.md',
    );
  });

  test('docs/reference/transports.md is up to date with the registry', () {
    final committed = File(
      '../../docs/reference/transports.md',
    ).readAsStringSync();
    expect(
      committed,
      renderTransportsQuickStart(buildRegistry()),
      reason:
          'Regenerate it: cd packages/zarvan_api && dart run tool/gen_api_docs.dart --transports > ../../docs/reference/transports.md',
    );
  });

  test('every public operation parameter has a useful description', () {
    for (final op in buildRegistry().all) {
      for (final param in [...op.params, ...op.implicitParams]) {
        expect(
          param.description.trim(),
          isNotEmpty,
          reason: '${op.name}.${param.name} needs a parameter description.',
        );
      }
    }
  });

  test('every operation has a section and Flutter-only ones say so', () {
    final text = renderOperationsReference(buildRegistry());
    for (final op in buildRegistry().all) {
      expect(text, contains('### `${op.name}`'));
    }
    expect(text, contains('CLI only (needs the Flutter SDK)'));
  });
}
