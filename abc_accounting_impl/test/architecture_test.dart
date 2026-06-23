import 'dart:io';

import 'package:dart_arch_test/dart_arch_test.dart';
import 'package:test/test.dart';

/// Root-level architecture test for abc_accounting_impl.
///
/// Enforces structural constraints on the implementation package's lib/ tree.
/// The lib path is anchored to abc_accounting_impl/lib/ relative to this test
/// file's location (one directory up from test/).
void main() {
  late DependencyGraph graph;

  setUpAll(() async {
    final testDir = File(Platform.script.toFilePath()).parent.parent;
    final libPath = '${testDir.path}/lib';
    graph = await Collector.buildGraph(libPath);
  });

  test('core/ is pure — no I/O, no framework, no coupling to api/ or effects/',
      () {
    for (final layer in ['effects', 'api']) {
      shouldNotDependOn(
        filesMatching('src/core/**'),
        filesMatching('src/$layer/**'),
        graph,
      );
    }
  });

  test('api/ must not import effects/ directly', () {
    shouldNotDependOn(
      filesMatching('src/api/**'),
      filesMatching('src/effects/**'),
      graph,
    );
  });

  test('no lib/ file imports abc_accounting_contract', () {
    shouldBeFreeOfCycles(filesMatching('src/**'), graph);
  });
}
