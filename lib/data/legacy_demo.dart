import 'dart:convert';

import 'models.dart';

/// Matches the original saved demo so upgrades can remove untouched sample data.
bool isUnchangedDemo(
  List<Account> accounts,
  List<Entry> entries,
  List<Budget> budgets,
) {
  if (entries.isEmpty) return false;
  final latest = entries.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
  final original = demoLedger(latest.date);
  return jsonEncode(accounts) == jsonEncode(original.accounts) &&
      jsonEncode(entries) == jsonEncode(original.entries) &&
      jsonEncode(budgets) == jsonEncode(original.budgets);
}

({List<Account> accounts, List<Entry> entries, List<Budget> budgets})
demoLedger(DateTime now) {
  final entries = <Entry>[];
  DateTime day(int ago, int hour, int minute) =>
      DateTime(now.year, now.month, now.day - ago, hour, minute);
  void add(
    String name,
    int amount,
    EntryType type,
    String account,
    DateTime date, {
    Category? category,
    String? to,
    List<PurchaseItem> items = const [],
    String notes = '',
  }) {
    entries.add(
      Entry(
        id: 'sample-${entries.length}',
        type: type,
        name: name,
        amount: amount,
        accountId: account,
        date: date.isAfter(now) ? now : date,
        category: category,
        destinationId: to,
        items: items,
        notes: notes,
      ),
    );
  }

  void spend(
    String name,
    int pence,
    Category category,
    int ago,
    int hour,
    int minute, {
    String account = 'monzo',
    List<PurchaseItem> items = const [],
    String notes = '',
  }) {
    final date = day(ago, hour, minute);
    final current = date.month == now.month
        ? date
        : DateTime(now.year, now.month, 1, hour, minute);
    add(
      name,
      pence,
      EntryType.expense,
      account,
      current,
      category: category,
      items: items,
      notes: notes,
    );
  }

  add(
    'Salary',
    245000,
    EntryType.income,
    'barclays',
    day(0, 9, 15),
    category: Category.salary,
  );
  add(
    'Account transfer',
    20000,
    EntryType.transfer,
    'barclays',
    day(0, 8, 30),
    to: 'monzo',
  );
  spend(
    'Tesco',
    3680,
    Category.groceries,
    0,
    12,
    42,
    notes: 'Weekly shop',
    items: const [
      PurchaseItem('Milk', 155, 1),
      PurchaseItem('Bread', 125, 1),
      PurchaseItem('Eggs', 240, 1),
      PurchaseItem('Washing-up liquid', 290, 1, Category.household),
    ],
  );
  spend('Pret A Manger', 1245, Category.eatingOut, 1, 13, 10);
  spend('Spotify', 1199, Category.subscriptions, 1, 10, 0);
  spend('TfL', 850, Category.transport, 1, 8, 24);
  spend('Amazon', 6499, Category.shopping, 2, 18, 16);
  spend('National Rail', 2840, Category.transport, 2, 8, 5);
  spend('Dishoom', 7820, Category.eatingOut, 3, 19, 52);
  spend(
    'Aldi',
    9265,
    Category.groceries,
    4,
    16,
    25,
    items: const [PurchaseItem('Milk', 145, 2), PurchaseItem('Coffee', 475, 2)],
  );
  spend('Everyman Cinema', 3750, Category.entertainment, 5, 17, 15);
  spend('John Lewis', 41230, Category.shopping, 6, 14, 12, account: 'barclays');
  spend('Boots', 4540, Category.health, 7, 15, 18);
  spend(
    'Tesco',
    8540,
    Category.groceries,
    8,
    12,
    11,
    items: const [
      PurchaseItem('Milk', 155, 2),
      PurchaseItem('Bread', 125, 2),
      PurchaseItem('Toothpaste', 285, 1, Category.health),
    ],
  );
  spend('Octopus Energy', 14270, Category.bills, 9, 11, 0, account: 'barclays');
  spend('TfL Travelcard', 12650, Category.transport, 10, 9, 25);
  spend('Sainsbury’s', 7215, Category.groceries, 11, 15, 25);
  spend('IKEA', 6502, Category.household, 12, 14, 9);
  spend('Council tax', 19000, Category.bills, 13, 9, 0, account: 'barclays');
  spend('BT Broadband', 6170, Category.bills, 14, 9, 0, account: 'barclays');
  spend('Flat rent', 136000, Category.bills, 17, 9, 0, account: 'barclays');

  const historicTotals = [142000, 155000, 124000, 138000, 112000];
  for (var index = 0; index < historicTotals.length; index++) {
    DateTime date(int d) => DateTime(now.year, now.month - index - 1, d, 12);
    final total = historicTotals[index];
    final groceries = 24800 + index * 3800;
    final travel = 14000 + index * 2100;
    final meals = 10500 + index * 1800;
    add(
      'Tesco',
      groceries,
      EntryType.expense,
      'monzo',
      date(25),
      category: Category.groceries,
      items: const [
        PurchaseItem('Milk', 155, 4),
        PurchaseItem('Coffee', 475, 2),
      ],
    );
    add(
      'TfL',
      travel,
      EntryType.expense,
      'monzo',
      date(18),
      category: Category.transport,
    );
    add(
      'Eating out',
      meals,
      EntryType.expense,
      'monzo',
      date(14),
      category: Category.eatingOut,
    );
    add(
      'Rent and utilities',
      total - groceries - travel - meals,
      EntryType.expense,
      'barclays',
      date(4),
      category: Category.bills,
    );
    add(
      'Salary',
      245000,
      EntryType.income,
      'barclays',
      date(1),
      category: Category.salary,
    );
  }

  final opened = DateTime(now.year, now.month - 6);
  Account account(
    String id,
    String name,
    AccountType type,
    int balance,
    int colour,
    AccountIcon icon,
  ) => Account(
    id: id,
    name: name,
    type: type,
    opening: balance - entries.fold(0, (sum, entry) => sum + entry.impact(id)),
    opened: opened,
    colour: colour,
    icon: icon,
  );

  return (
    accounts: [
      account(
        'monzo',
        'Monzo',
        AccountType.current,
        46320,
        0xFFF38E90,
        AccountIcon.wallet,
      ),
      account(
        'barclays',
        'Barclays',
        AccountType.current,
        130000,
        0xFF91BFFA,
        AccountIcon.bank,
      ),
      account(
        'savings',
        'Savings',
        AccountType.savings,
        400000,
        0xFFB2A6F7,
        AccountIcon.savings,
      ),
    ],
    entries: entries,
    budgets: const [
      Budget('sample-overall', 340000, BudgetPeriod.monthly),
      Budget(
        'sample-groceries',
        34000,
        BudgetPeriod.monthly,
        Category.groceries,
      ),
      Budget('sample-meals', 10000, BudgetPeriod.monthly, Category.eatingOut),
      Budget('sample-travel', 17000, BudgetPeriod.monthly, Category.transport),
    ],
  );
}
