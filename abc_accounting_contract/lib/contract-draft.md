# Ideal Contract

## Contract

name: 'ledger_type_contract'
purpose: 'Defines the form and structure of the Ledger and the types it knows.'
version: 0.1.0
dependsOn: ['']
tags: 'Ledger Types'

## Importable file
- package:abc_accounting/ledger.dart

## All Types

- [AccountId] 'The unique identifier of the ledger'
- [AccountStatus] 'Represents the ability of the account to transact'
- [AccountStatus.open] 'The account is open and can transact'
- [AccountStatus.closed] 'The account is closed and cannot transact'
- [AccountStatus.frozen] 'The account is frozen and cannot transact'
- [Money] 'Represents a monetary value'
- [Option<Money>] 'Represents an optional monetary value'
- [Version] 'Represents the version of the ledger type'
- [Ledger] 'Tracks the movement of value'
- [LedgerResult] 'The outcome of an operation on the ledger'
- [LedgerError] 'Represents an error that occurred during a ledger operation'
- [LedgerError.InsufficientFunds] 'Represents an error where the ledger does not have sufficient funds'

## Type Structures

 - [AccountStatus] (bool canTransact)
 - [Ledger] ([AccountId], [Money], [Option<Money>], [Money], [Version])
 - [LedgerResult] ([Ledger], [LedgerError])
 - [LedgerError] ([String])
 - [LedgerError.InsufficientFunds] ([String])


## Contract

name: 'account_opening'
purpose: 'defines the ability to open an account'
version: 0.1.0
dependsOn: ['ledger_type_contract']
tags: 'operations, account, account_opening, ledger'

## Signatures

name: TaskEither<LedgerError, Ledger> LedgerFactory(AccountId id)
purpose: 'Creates a new [Ledger] for the given [AccountId]'
failure: 
rules:
  - [Ledger.state] must be [AccountStatus.open]
