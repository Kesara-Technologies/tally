enum EntryType {
  expense('Expense'),
  income('Income'),
  transfer('Transfer'),
  adjustment('Balance adjustment');

  const EntryType(this.label);
  final String label;
}

enum Category {
  groceries('Groceries'),
  eatingOut('Eating Out'),
  shopping('Shopping'),
  transport('Transport'),
  bills('Bills'),
  entertainment('Entertainment'),
  subscriptions('Subscriptions'),
  health('Health'),
  education('Education'),
  household('Household'),
  other('Other'),
  salary('Salary'),
  freelance('Freelance'),
  business('Business'),
  gifts('Gifts'),
  refunds('Refunds'),
  interest('Interest'),
  otherIncome('Other Income');

  const Category(this.label);
  final String label;

  bool get isExpense => index <= Category.other.index;
  static List<Category> forType(EntryType type) => values
      .where((category) => category.isExpense == (type == EntryType.expense))
      .toList();
}

enum AccountType {
  current('Current account'),
  savings('Savings account'),
  cash('Cash'),
  credit('Credit card'),
  prepaid('Prepaid card'),
  investment('Investment account'),
  other('Other');

  const AccountType(this.label);
  final String label;
}

enum AccountIcon { wallet, bank, savings, card, cash, investment }

enum BudgetPeriod {
  weekly('Weekly', 'week'),
  monthly('Monthly', 'month'),
  yearly('Yearly', 'year');

  const BudgetPeriod(this.label, this.unit);
  final String label;
  final String unit;

  DateSpan span(DateTime date) => switch (this) {
    weekly => DateSpan(
      DateTime(date.year, date.month, date.day - date.weekday + 1),
      DateTime(date.year, date.month, date.day - date.weekday + 8),
    ),
    monthly => DateSpan.month(date),
    yearly => DateSpan(DateTime(date.year), DateTime(date.year + 1)),
  };
}

class DateSpan {
  const DateSpan(this.start, this.end);
  factory DateSpan.month(DateTime date) => DateSpan(
    DateTime(date.year, date.month),
    DateTime(date.year, date.month + 1),
  );

  final DateTime start;
  final DateTime end;
  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.opening,
    required this.opened,
    required this.colour,
    required this.icon,
    this.included = true,
    this.archived = false,
  });

  factory Account.fromJson(Map<String, dynamic> data) => Account(
    id: data['id'] as String,
    name: data['name'] as String,
    type: AccountType.values.byName(data['type'] as String),
    opening: data['opening'] as int,
    opened: DateTime.parse(data['opened'] as String),
    colour: data['colour'] as int,
    icon: AccountIcon.values.byName(data['icon'] as String),
    included: data['included'] as bool,
    archived: data['archived'] as bool,
  );

  final String id;
  final String name;
  final AccountType type;
  final int opening;
  final DateTime opened;
  final int colour;
  final AccountIcon icon;
  final bool included;
  final bool archived;

  Account withStatus({bool? archived, bool? included}) => Account(
    id: id,
    name: name,
    type: type,
    opening: opening,
    opened: opened,
    colour: colour,
    icon: icon,
    included: included ?? this.included,
    archived: archived ?? this.archived,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'opening': opening,
    'opened': opened.toIso8601String(),
    'colour': colour,
    'icon': icon.name,
    'included': included,
    'archived': archived,
  };
}

class PurchaseItem {
  const PurchaseItem(this.name, this.unitPrice, this.quantity, [this.category]);

  factory PurchaseItem.fromJson(Map<String, dynamic> data) => PurchaseItem(
    data['name'] as String,
    data['price'] as int,
    data['quantity'] as int,
    data['category'] == null
        ? null
        : Category.values.byName(data['category'] as String),
  );

  final String name;
  final int unitPrice;
  final int quantity;
  final Category? category;
  int get total => unitPrice * quantity;

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': unitPrice,
    'quantity': quantity,
    'category': category?.name,
  };
}

class Entry {
  const Entry({
    required this.id,
    required this.type,
    required this.name,
    required this.amount,
    required this.accountId,
    required this.date,
    this.destinationId,
    this.category,
    this.notes = '',
    this.items = const [],
    this.includeInCashFlow = true,
  });

  factory Entry.fromJson(Map<String, dynamic> data) => Entry(
    id: data['id'] as String,
    type: EntryType.values.byName(data['type'] as String),
    name: data['name'] as String,
    amount: data['amount'] as int,
    accountId: data['account'] as String,
    destinationId: data['destination'] as String?,
    category: data['category'] == null
        ? null
        : Category.values.byName(data['category'] as String),
    date: DateTime.parse(data['date'] as String),
    notes: data['notes'] as String,
    includeInCashFlow: data['includeInCashFlow'] as bool? ?? true,
    items: (data['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(PurchaseItem.fromJson)
        .toList(),
  );

  final String id;
  final EntryType type;
  final String name;
  final int amount;
  final String accountId;
  final String? destinationId;
  final Category? category;
  final DateTime date;
  final String notes;
  final List<PurchaseItem> items;
  final bool includeInCashFlow;

  bool involves(String account) =>
      accountId == account || destinationId == account;

  int impact(String account) {
    if (destinationId == account && type == EntryType.transfer) return amount;
    if (accountId != account) return 0;
    return switch (type) {
      EntryType.expense || EntryType.transfer => -amount,
      EntryType.income || EntryType.adjustment => amount,
    };
  }

  int get itemSubtotal => items.fold(0, (sum, item) => sum + item.total);

  Map<Category, int> get allocations {
    final parent = category;
    if (type != EntryType.expense || parent == null) return {};
    final totals = <Category, int>{};
    for (final item in items) {
      final key = item.category ?? parent;
      totals.update(
        key,
        (total) => total + item.total,
        ifAbsent: () => item.total,
      );
    }
    final remainder = amount - itemSubtotal;
    if (remainder > 0) {
      totals.update(
        parent,
        (total) => total + remainder,
        ifAbsent: () => remainder,
      );
    }
    return totals;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'amount': amount,
    'account': accountId,
    'destination': destinationId,
    'category': category?.name,
    'date': date.toIso8601String(),
    'notes': notes,
    'items': items.map((item) => item.toJson()).toList(),
    if (type == EntryType.income && !includeInCashFlow)
      'includeInCashFlow': false,
  };
}

class Budget {
  const Budget(this.id, this.limit, this.period, [this.category]);

  factory Budget.fromJson(Map<String, dynamic> data) => Budget(
    data['id'] as String,
    data['limit'] as int,
    BudgetPeriod.values.byName(data['period'] as String),
    data['category'] == null
        ? null
        : Category.values.byName(data['category'] as String),
  );

  final String id;
  final int limit;
  final BudgetPeriod period;
  final Category? category;

  String get name => category?.label ?? 'Overall spending';

  Map<String, dynamic> toJson() => {
    'id': id,
    'limit': limit,
    'period': period.name,
    'category': category?.name,
  };
}

const months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String monthLabel(DateTime date) => '${months[date.month - 1]} ${date.year}';
String shortMonth(DateTime date) => months[date.month - 1].substring(0, 3);
String shortDate(DateTime date) => '${date.day} ${shortMonth(date)}';
String fullDate(DateTime date) => '${date.day} ${monthLabel(date)}';
String timeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime periodReference(DateTime month, DateTime now) =>
    month.year == now.year && month.month == now.month
    ? now
    : DateTime(month.year, month.month + 1, 0);

const maximumAmount = 99999999999;

int? parseMoney(String input, {bool signed = false}) {
  var text = input.trim().replaceAll('−', '-');
  var sign = 1;
  if (text.startsWith('-') || text.startsWith('+')) {
    if (!signed) return null;
    if (text.startsWith('-')) sign = -1;
    text = text.substring(1);
  }
  if (text.startsWith('£')) text = text.substring(1);
  if (!RegExp(r'^(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d{0,2})?$|^\.\d{1,2}$')
      .hasMatch(text)) {
    return null;
  }
  final parts = text.replaceAll(',', '').split('.');
  final pounds = int.tryParse(parts.first.isEmpty ? '0' : parts.first);
  if (pounds == null || pounds > maximumAmount ~/ 100) return null;
  final pence = parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0'));
  return sign * (pounds * 100 + pence);
}

String money(int amount, {bool plus = false}) {
  final value = amount.abs();
  final pounds = (value ~/ 100).toString();
  final grouped = StringBuffer();
  for (var index = 0; index < pounds.length; index++) {
    if (index > 0 && (pounds.length - index) % 3 == 0) grouped.write(',');
    grouped.write(pounds[index]);
  }
  final sign = amount < 0 ? '−' : (plus && amount > 0 ? '+' : '');
  return '$sign£$grouped.${(value % 100).toString().padLeft(2, '0')}';
}

String moneyInput(int amount) =>
    '${amount < 0 ? '-' : ''}${amount.abs() ~/ 100}.${(amount.abs() % 100).toString().padLeft(2, '0')}';

String percentage(double fraction) {
  final rounded = (fraction * 100).toStringAsFixed(1);
  return '${rounded.endsWith('.0') ? rounded.substring(0, rounded.length - 2) : rounded}%';
}
