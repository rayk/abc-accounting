import '../contract/ledger.dart';

LedgerFactory? _factory;

LedgerFactory get defaultFactory {
  final f = _factory;
  if (f == null) {
    throw StateError(
      'No abc_accounting implementation registered in this isolate. '
      'The harness must call abc_accounting_impl.register() in setUpAll before '
      'running the conformance suite.',
    );
  }
  return f;
}

bool get isFactoryRegistered => _factory != null;
void registerFactory(LedgerFactory factory) => _factory = factory;
