import 'dart:convert';
import 'dart:typed_data';

import 'models.dart';

class LedgerSnapshot {
  const LedgerSnapshot({
    required this.accounts,
    required this.entries,
    required this.budgets,
    required this.hidden,
  });

  static const _backupFormat = 'tally-backup';
  static const _version = 1;

  factory LedgerSnapshot.fromJson(Map<String, dynamic> data) {
    if (data['version'] != _version) {
      throw const FormatException('Unknown ledger version');
    }
    return LedgerSnapshot(
      accounts: (data['accounts'] as List)
          .cast<Map<String, dynamic>>()
          .map(Account.fromJson)
          .toList(),
      entries: (data['entries'] as List)
          .cast<Map<String, dynamic>>()
          .map(Entry.fromJson)
          .toList(),
      budgets: (data['budgets'] as List)
          .cast<Map<String, dynamic>>()
          .map(Budget.fromJson)
          .toList(),
      hidden: data['hidden'] as bool,
    );
  }

  factory LedgerSnapshot.fromBackup(List<int> bytes) {
    const invalid = FormatException('Choose a valid Tally backup file.');
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw invalid;
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != _backupFormat) {
      throw invalid;
    }
    if (decoded['version'] != _version) {
      throw const FormatException('This Tally backup version is unsupported.');
    }

    final LedgerSnapshot snapshot;
    try {
      snapshot = LedgerSnapshot.fromJson(decoded);
    } on TypeError {
      throw invalid;
    } on ArgumentError {
      throw invalid;
    } on FormatException {
      throw invalid;
    }
    if (!snapshot._isConsistent()) {
      throw const FormatException('This backup contains invalid ledger data.');
    }
    return snapshot;
  }

  final List<Account> accounts;
  final List<Entry> entries;
  final List<Budget> budgets;
  final bool hidden;

  Map<String, dynamic> toJson() => {
    'version': _version,
    'accounts': accounts,
    'entries': entries,
    'budgets': budgets,
    'hidden': hidden,
  };

  Uint8List toBackup() =>
      utf8.encode(jsonEncode({'format': _backupFormat, ...toJson()}));

  bool _isConsistent() {
    final accountIds = <String>{};
    final accountNames = <String>{};
    for (final account in accounts) {
      if (account.id.isEmpty ||
          !accountIds.add(account.id) ||
          account.name.trim().isEmpty ||
          !accountNames.add(account.name.toLowerCase()) ||
          account.opening < -maximumAmount ||
          account.opening > maximumAmount ||
          account.colour < 0 ||
          account.colour > 0xFFFFFFFF) {
        return false;
      }
    }

    final entryIds = <String>{};
    for (final entry in entries) {
      if (entry.id.isEmpty ||
          !entryIds.add(entry.id) ||
          !accountIds.contains(entry.accountId) ||
          entry.name.trim().isEmpty ||
          !_isValidEntry(entry, accountIds)) {
        return false;
      }
    }

    final budgetIds = <String>{};
    final targets = <(Category?, BudgetPeriod)>{};
    return budgets.every(
      (budget) =>
          budget.id.isNotEmpty &&
          budgetIds.add(budget.id) &&
          targets.add((budget.category, budget.period)) &&
          budget.limit > 0 &&
          budget.limit <= maximumAmount &&
          budget.category?.isExpense != false,
    );
  }

  static bool _isValidEntry(Entry entry, Set<String> accountIds) {
    if (entry.type == EntryType.adjustment) {
      return entry.amount != 0 &&
          entry.notes.trim().isNotEmpty &&
          entry.destinationId == null &&
          entry.category == null &&
          entry.items.isEmpty;
    }
    if (entry.amount <= 0 || entry.amount > maximumAmount) return false;

    return switch (entry.type) {
      EntryType.expense =>
        entry.destinationId == null &&
            entry.category?.isExpense == true &&
            _hasValidItems(entry),
      EntryType.income =>
        entry.destinationId == null &&
            entry.category?.isExpense == false &&
            entry.items.isEmpty,
      EntryType.transfer =>
        entry.destinationId != entry.accountId &&
            accountIds.contains(entry.destinationId) &&
            entry.category == null &&
            entry.items.isEmpty,
      EntryType.adjustment => false,
    };
  }

  static bool _hasValidItems(Entry entry) {
    var remaining = entry.amount;
    for (final item in entry.items) {
      if (item.name.trim().isEmpty ||
          item.unitPrice <= 0 ||
          item.unitPrice > maximumAmount ||
          item.quantity < 1 ||
          item.quantity > 9999 ||
          item.category?.isExpense == false) {
        return false;
      }
      remaining -= item.total;
      if (remaining < 0) return false;
    }
    return true;
  }
}
