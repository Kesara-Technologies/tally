import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import 'ledger_snapshot.dart';
import 'legacy_demo.dart';
import 'models.dart';
import 'storage.dart';

class LedgerException implements Exception {
  const LedgerException(this.message);
  final String message;
}

class Ledger extends ChangeNotifier {
  Ledger(this._storage, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LedgerStorage _storage;
  final DateTime Function() _clock;
  List<Account> _accounts = [];
  List<Entry> _entries = [];
  List<Budget> _budgets = [];
  bool _hidden = false;
  bool _disposed = false;
  Future<void> _pending = Future.value();

  DateTime get now => _clock();
  bool get hidden => _hidden;
  List<Account> get accounts => List.unmodifiable(_accounts);
  List<Account> get activeAccounts =>
      _accounts.where((account) => !account.archived).toList();
  List<Budget> get budgets => List.unmodifiable(_budgets);
  List<Entry> get entries =>
      [..._entries]..sort((a, b) => b.date.compareTo(a.date));
  List<Account> get includedAccounts =>
      activeAccounts.where((account) => account.included).toList();
  int get totalBalance =>
      includedAccounts.fold(0, (sum, account) => sum + balance(account));
  String newId() {
    final random = Random.secure();
    return '${now.microsecondsSinceEpoch.toRadixString(36)}-${random.nextInt(1 << 30).toRadixString(36)}';
  }

  Account? account(String? id) =>
      _accounts.where((item) => item.id == id).firstOrNull;
  String accountName(String? id) => account(id)?.name ?? 'Unknown account';
  Entry? entry(String id) =>
      _entries.where((item) => item.id == id).firstOrNull;
  Budget? budget(String id) =>
      _budgets.where((item) => item.id == id).firstOrNull;

  Future<void> load() async {
    final source = await _storage.read();
    if (_disposed) return;
    if (source != null) {
      final data = jsonDecode(source) as Map<String, dynamic>;
      _applySnapshot(LedgerSnapshot.fromJson(data));
      if (data['demo'] == true &&
          isUnchangedDemo(_accounts, _entries, _budgets)) {
        await _save(accounts: [], entries: [], budgets: []);
        return;
      }
    }
    notifyListeners();
  }

  Future<void> _save({
    List<Account>? accounts,
    List<Entry>? entries,
    List<Budget>? budgets,
    bool? hidden,
  }) async {
    final snapshot = LedgerSnapshot(
      accounts: accounts ?? _accounts,
      entries: entries ?? _entries,
      budgets: budgets ?? _budgets,
      hidden: hidden ?? _hidden,
    );
    try {
      await _storage.write(jsonEncode(snapshot.toJson()));
    } catch (_) {
      throw const LedgerException(
        'Your changes could not be saved. Try again.',
      );
    }
    _applySnapshot(snapshot);
    if (!_disposed) notifyListeners();
  }

  void _applySnapshot(LedgerSnapshot snapshot) {
    _accounts = snapshot.accounts;
    _entries = snapshot.entries;
    _budgets = snapshot.budgets;
    _hidden = snapshot.hidden;
  }

  Uint8List exportBackup() => LedgerSnapshot(
    accounts: _accounts,
    entries: _entries,
    budgets: _budgets,
    hidden: _hidden,
  ).toBackup();

  Future<void> restoreBackup(LedgerSnapshot backup) => _serial(
    () => _save(
      accounts: backup.accounts,
      entries: backup.entries,
      budgets: backup.budgets,
      hidden: backup.hidden,
    ),
  );

  Future<void> _serial(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> togglePrivacy() => _serial(() => _save(hidden: !_hidden));

  Future<void> putAccount(Account value) => _serial(() {
    if (value.name.trim().isEmpty || value.opening.abs() > maximumAmount) {
      throw const LedgerException(
        'Enter an account name and a valid opening balance.',
      );
    }
    if (_accounts.any(
      (item) =>
          item.id != value.id &&
          item.name.toLowerCase() == value.name.toLowerCase(),
    )) {
      throw const LedgerException('An account with this name already exists.');
    }
    return _save(
      accounts: _replace(_accounts, value, (item) => item.id == value.id),
    );
  });

  Future<void> setArchived(String id, bool archived) => _serial(() {
    final current = account(id);
    if (current == null) {
      throw const LedgerException('This account could not be found.');
    }
    return _save(
      accounts: _replace(
        _accounts,
        current.withStatus(archived: archived),
        (item) => item.id == id,
      ),
    );
  });

  Future<void> reorderAccounts(List<String> ids, {required bool archived}) =>
      _serial(() {
        final group = {
          for (final account in _accounts)
            if (account.archived == archived) account.id: account,
        };
        if (ids.length != group.length ||
            ids.toSet().length != ids.length ||
            !ids.every(group.containsKey)) {
          throw const LedgerException(
            'The accounts changed. Try reordering again.',
          );
        }
        var next = 0;
        return _save(
          accounts: [
            for (final account in _accounts)
              account.archived == archived ? group[ids[next++]]! : account,
          ],
        );
      });

  Future<void> adjust(String id, int newBalance, String reason) => _serial(() {
    final current = account(id);
    if (current == null || current.archived) {
      throw const LedgerException('Select an active account to adjust.');
    }
    final change = newBalance - balance(current);
    if (change == 0) {
      throw const LedgerException(
        'Enter a balance different from the current balance.',
      );
    }
    if (newBalance.abs() > maximumAmount || reason.trim().isEmpty) {
      throw const LedgerException(
        'Enter a valid balance and a reason for the adjustment.',
      );
    }
    final adjustment = Entry(
      id: newId(),
      type: EntryType.adjustment,
      name: 'Balance adjustment',
      amount: change,
      accountId: id,
      date: now,
      notes: reason.trim(),
    );
    return _save(entries: [..._entries, adjustment]);
  });

  Future<void> putEntry(Entry value) => _serial(() {
    final previous = entry(value.id);
    if (value.type == EntryType.adjustment) {
      if (previous?.type != EntryType.adjustment ||
          value.amount == 0 ||
          value.accountId != previous?.accountId ||
          value.date != previous?.date ||
          value.notes.trim().isEmpty) {
        throw const LedgerException(
          'Enter a non-zero adjustment and a reason.',
        );
      }
      return _save(
        entries: _replace(_entries, value, (item) => item.id == value.id),
      );
    }
    if (value.amount <= 0 || value.amount > maximumAmount) {
      throw const LedgerException('Enter an amount greater than zero.');
    }
    if (value.name.trim().isEmpty) {
      throw const LedgerException('Enter a description.');
    }
    _validateAccount(value.accountId, previous);
    if (value.type == EntryType.transfer) {
      if (value.destinationId == value.accountId) {
        throw const LedgerException('Choose a different destination account.');
      }
      _validateAccount(value.destinationId, previous);
    } else if (value.category == null ||
        value.category!.isExpense != (value.type == EntryType.expense)) {
      throw const LedgerException('Choose a category for this transaction.');
    }
    if (value.date.isAfter(now)) {
      throw const LedgerException('Choose a date and time up to now.');
    }
    if (value.type != EntryType.expense && value.items.isNotEmpty) {
      throw const LedgerException('Itemised purchases belong to expenses.');
    }
    if (value.items.any(
      (item) =>
          item.name.trim().isEmpty ||
          item.unitPrice <= 0 ||
          item.unitPrice > maximumAmount ||
          item.quantity < 1 ||
          item.quantity > 9999 ||
          item.category?.isExpense == false,
    )) {
      throw const LedgerException(
        'Check every item’s name, price and quantity.',
      );
    }
    if (value.itemSubtotal > value.amount) {
      throw const LedgerException(
        'The item subtotal exceeds the expense amount.',
      );
    }
    return _save(
      entries: _replace(_entries, value, (item) => item.id == value.id),
    );
  });

  void _validateAccount(String? id, Entry? previous) {
    final selected = account(id);
    if (selected == null ||
        (selected.archived && previous?.involves(selected.id) != true)) {
      throw const LedgerException(
        'Choose an active account for this transaction.',
      );
    }
  }

  Future<void> deleteEntry(String id) => _serial(
    () => _save(entries: _entries.where((item) => item.id != id).toList()),
  );

  Future<void> putBudget(Budget value) => _serial(() {
    if (value.limit <= 0 || value.limit > maximumAmount) {
      throw const LedgerException('Enter a budget amount greater than zero.');
    }
    if (value.category?.isExpense == false) {
      throw const LedgerException('Choose a spending category.');
    }
    if (_budgets.any(
      (item) =>
          item.id != value.id &&
          item.category == value.category &&
          item.period == value.period,
    )) {
      throw const LedgerException(
        'A goal already exists for this category and period.',
      );
    }
    return _save(
      budgets: _replace(_budgets, value, (item) => item.id == value.id),
    );
  });

  Future<void> deleteBudget(String id) => _serial(
    () => _save(budgets: _budgets.where((item) => item.id != id).toList()),
  );

  int balance(Account account, {DateTime? before}) {
    final opening = before == null || account.opened.isBefore(before)
        ? account.opening
        : 0;
    return _entries.fold(
      opening,
      (sum, entry) => before == null || entry.date.isBefore(before)
          ? sum + entry.impact(account.id)
          : sum,
    );
  }

  int combinedChange(DateSpan span) => includedAccounts.fold(
    0,
    (sum, account) =>
        sum +
        balance(account, before: span.end) -
        balance(account, before: span.start),
  );

  Iterable<Entry> inSpan(DateSpan span, {String? accountId}) => _entries.where(
    (entry) =>
        span.contains(entry.date) &&
        (accountId == null || entry.involves(accountId)),
  );

  ({int income, int expenses, int excludedIncome, List<int> trend})
  monthlyCashFlow(DateTime date) {
    final span = DateSpan(
      DateTime(date.year, date.month),
      DateTime(date.year, date.month, date.day + 1),
    );
    final daily = List<int>.filled(date.day, 0);
    var income = 0;
    var expenses = 0;
    var excludedIncome = 0;
    for (final entry in inSpan(span)) {
      final dayIndex = entry.date.toLocal().day - 1;
      switch (entry.type) {
        case EntryType.income when entry.includeInCashFlow:
          income += entry.amount;
          daily[dayIndex] += entry.amount;
        case EntryType.income:
          excludedIncome += entry.amount;
        case EntryType.expense:
          expenses += entry.amount;
          daily[dayIndex] -= entry.amount;
        case EntryType.transfer || EntryType.adjustment:
          break;
      }
    }
    final trend = [0];
    for (final value in daily) {
      trend.add(trend.last + value);
    }
    return (
      income: income,
      expenses: expenses,
      excludedIncome: excludedIncome,
      trend: trend,
    );
  }

  ({
    int income,
    int expenses,
    int transfersIn,
    int transfersOut,
    int adjustments,
  })
  activity(DateSpan span, {String? accountId}) {
    var income = 0;
    var expenses = 0;
    var transfersIn = 0;
    var transfersOut = 0;
    var adjustments = 0;
    for (final entry in inSpan(span, accountId: accountId)) {
      switch (entry.type) {
        case EntryType.income:
          income += entry.amount;
        case EntryType.expense:
          expenses += entry.amount;
        case EntryType.transfer:
          if (accountId == null) continue;
          if (entry.accountId == accountId) transfersOut += entry.amount;
          if (entry.destinationId == accountId) transfersIn += entry.amount;
        case EntryType.adjustment:
          adjustments += entry.amount;
      }
    }
    return (
      income: income,
      expenses: expenses,
      transfersIn: transfersIn,
      transfersOut: transfersOut,
      adjustments: adjustments,
    );
  }

  int spending(DateSpan span, {Category? category, String? accountId}) =>
      inSpan(span, accountId: accountId).fold(
        0,
        (sum, entry) =>
            sum +
            (entry.type != EntryType.expense
                ? 0
                : category == null
                ? entry.amount
                : entry.allocations[category] ?? 0),
      );

  Map<Category, int> breakdown(DateSpan span) {
    final totals = <Category, int>{};
    for (final entry in inSpan(span)) {
      for (final allocation in entry.allocations.entries) {
        totals.update(
          allocation.key,
          (sum) => sum + allocation.value,
          ifAbsent: () => allocation.value,
        );
      }
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  int budgetUsage(Budget budget, DateTime reference) =>
      spending(budget.period.span(reference), category: budget.category);

  Budget? preferredBudget(Category? category) {
    final matches = _budgets.where((item) => item.category == category);
    return matches
            .where((item) => item.period == BudgetPeriod.monthly)
            .firstOrNull ??
        matches.firstOrNull;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

List<T> _replace<T>(List<T> items, T value, bool Function(T) matches) {
  final index = items.indexWhere(matches);
  if (index < 0) return [...items, value];
  return [...items]..[index] = value;
}
