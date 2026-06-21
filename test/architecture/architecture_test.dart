import 'dart:io';

import 'package:dart_arch_test/dart_arch_test.dart';
import 'package:test/test.dart';

/// The layering in `SPEC.md` §9 is enforced here, not merely documented.
/// Patterns match the package-relative path (the `package:abc_accounting/`
/// prefix is stripped), so `src/<layer>/**` selects one layer.
void main() {
  late DependencyGraph graph;

  setUpAll(() async {
    graph = await Collector.buildGraph('${Directory.current.path}/lib');
  });

  test('dependencies only point downward through the layers', () {
    defineLayers({
      'di': 'src/di/**',
      'api': 'src/api/**',
      'runtime': 'src/runtime/**',
      'effects': 'src/effects/**',
      'core': 'src/core/**',
      'domain': 'src/domain/**',
      'contract': 'src/contract/**',
    }).enforceDirection(graph);
  });

  test('the pure core never imports outer layers', () {
    for (final layer in ['effects', 'runtime', 'api', 'di']) {
      shouldNotDependOn(
        filesMatching('src/core/**'),
        filesMatching('src/$layer/**'),
        graph,
      );
    }
  });

  test('the contract (interface + types) depends on no other layer', () {
    for (final layer in ['domain', 'core', 'effects', 'runtime', 'api', 'di']) {
      shouldNotDependOn(
        filesMatching('src/contract/**'),
        filesMatching('src/$layer/**'),
        graph,
      );
    }
  });

  test('the package is free of import cycles', () {
    shouldBeFreeOfCycles(filesMatching('src/**'), graph);
  });
}
