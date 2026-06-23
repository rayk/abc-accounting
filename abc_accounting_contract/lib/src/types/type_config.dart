/// Type override maps and format notes for the Ledger contract brief.
///
/// Extracted from the ContractBrief construction in ledger_brief.dart so the
/// same literals are reused for every domainType() call without repetition.
library;

/// `dart:mirrors` cannot see through `extension type`s, so these overrides
/// restore the real newtype names in the brief's TYPES block.
const Map<String, String> accountStateOverrides = {
  'id': 'AccountId',
  'balance': 'Money',
  'dailyLimit': 'Option<Money>',
  'withdrawnToday': 'Money',
  'version': 'Version',
};

/// Implicit field-value conventions that the type signature alone cannot
/// express — rendered in the brief's FIELD-FORMATS section.
const Map<String, String> accountStateFormatNotes = {
  'balance': 'integer minor units; Money is a newtype over int',
  'dailyLimit': 'None ⇒ unlimited',
  'version': 'monotonic; advances by one per applied event',
};

/// Type overrides for `InsufficientFunds` constructor parameters.
const Map<String, String> insufficientFundsOverrides = {
  'balance': 'Money',
  'requested': 'Money',
};

/// Type overrides for `DailyLimitExceeded` constructor parameters.
const Map<String, String> dailyLimitExceededOverrides = {
  'limit': 'Money',
  'attempted': 'Money',
};
