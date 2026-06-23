import 'package:abc_accounting/abc_accounting.dart';
import 'api/account_ledger.dart';
import 'effects/env.dart';

const String contractImplemented = '0.1.0';

String _majorMinor(String v) => v.split('.').take(2).join('.');

void register() {
  if (_majorMinor(contractVersion) != _majorMinor(contractImplemented)) {
    throw StateError(
      'Workspace version mismatch: abc_accounting_impl contractImplemented '
      '$contractImplemented vs abc_accounting contractVersion $contractVersion. '
      'Their MAJOR.MINOR segments must agree.',
    );
  }
  registerFactory((id) => AccountLedger.open(defaultEnv(), id));
}
