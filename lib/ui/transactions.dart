import 'package:flutter/material.dart';

import '../data/ledger.dart';
import '../data/models.dart';
import 'charts.dart';
import 'design.dart';
import 'entry_form.dart';

class TransactionsView extends StatefulWidget {
  const TransactionsView({super.key, this.accountId});
  final String? accountId;

  @override
  State<TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<TransactionsView> {
  static const _types = <(String, EntryType?)>[
    ('All', null),
    ('Expenses', EntryType.expense),
    ('Income', EntryType.income),
    ('Transfers', EntryType.transfer),
  ];

  final _search = TextEditingController();
  EntryType? _type;
  _TransactionFilters _filters = const _TransactionFilters();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _add() => openPage<void>(
    context,
    EntryForm(accountId: widget.accountId),
    form: true,
  );

  Future<void> _openFilters() async {
    FocusScope.of(context).unfocus();
    final result = await showModalBottomSheet<_TransactionFilters>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 590),
      builder: (context) => _FilterSheet(
        current: _filters,
        accountLocked: widget.accountId != null,
      ),
    );
    if (mounted && result != null) setState(() => _filters = result);
  }

  bool _matches(Entry entry, Ledger ledger) {
    final account = widget.accountId ?? _filters.account;
    if (account != null && !entry.involves(account)) return false;
    if (_type != null && entry.type != _type) return false;
    final category = _filters.category;
    if (category != null &&
        entry.category != category &&
        !entry.allocations.containsKey(category)) {
      return false;
    }
    final range = _filters.range;
    if (range != null &&
        !DateSpan(
          range.start,
          DateTime(range.end.year, range.end.month, range.end.day + 1),
        ).contains(entry.date)) {
      return false;
    }
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    if (!ledger.hidden && RegExp(r'^[+−-]?£?\d[\d,.]*$').hasMatch(query)) {
      final amount = parseMoney(query, signed: true);
      if (amount != null) {
        if (query.startsWith('-') || query.startsWith('−')) {
          return (entry.type == EntryType.expense && entry.amount == -amount) ||
              (entry.type == EntryType.adjustment && entry.amount == amount);
        }
        if (query.startsWith('+')) {
          return (entry.type == EntryType.income ||
                  entry.type == EntryType.adjustment) &&
              entry.amount == amount;
        }
      }
    }
    final fields = [
      entry.name,
      entry.notes,
      entry.category?.label ?? '',
      entry.type.label,
      ledger.accountName(entry.accountId),
      if (entry.destinationId != null) ledger.accountName(entry.destinationId),
      for (final item in entry.items) item.name,
      for (final allocation in entry.allocations.keys) allocation.label,
      if (!ledger.hidden) ...[
        money(entry.amount.abs()),
        moneyInput(entry.amount.abs()),
      ],
    ].join(' ').toLowerCase();
    final indexed = fields.replaceAll(',', '').replaceAll('’', "'");
    return query
        .replaceAll(',', '')
        .replaceAll('’', "'")
        .split(RegExp(r'\s+'))
        .every(indexed.contains);
  }

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final all = ledger.entries.where(
      (entry) => widget.accountId == null || entry.involves(widget.accountId!),
    );
    final filtered = all.where((entry) => _matches(entry, ledger)).toList();
    final groups = <DateTime, List<Entry>>{};
    for (final entry in filtered) {
      final key = DateUtils.dateOnly(entry.date);
      (groups[key] ??= []).add(entry);
    }
    final sections = groups.entries.toList();
    final content = Column(
      children: [
        if (widget.accountId == null)
          MainHeader(
            title: 'Transactions',
            actionLabel: 'Add transaction',
            onAdd: _add,
          ),
        Expanded(
          child: CustomScrollView(
            key: PageStorageKey(widget.accountId ?? 'transactions'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        style: textStyle(14),
                        decoration: InputDecoration(
                          hintText: 'Search transactions...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Palette.secondary,
                            size: 22,
                          ),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(_search.clear),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final (label, type) in _types)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: SmallChip(
                                        label,
                                        horizontalPadding: 10,
                                        selected: _type == type,
                                        onTap: () =>
                                            setState(() => _type = type),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'More transaction filters',
                            onPressed: () => _openFilters(),
                            style: IconButton.styleFrom(
                              backgroundColor: _filters.active
                                  ? Palette.greenSurface
                                  : Palette.surface,
                              foregroundColor: _filters.active
                                  ? Palette.mint
                                  : Palette.secondary,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size.square(40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            icon: const Icon(Icons.tune_rounded, size: 20),
                          ),
                        ],
                      ),
                      if (widget.accountId == null) ...[
                        const SizedBox(height: 17),
                        _CashFlowCard(ledger: ledger),
                      ],
                      const SizedBox(height: 19),
                      SectionTitle(
                        _search.text.trim().isNotEmpty
                            ? 'Search results'
                            : 'Transaction history',
                        action: _filters.active ? 'Clear filters' : null,
                        onAction: () => setState(() {
                          _filters = const _TransactionFilters();
                          _type = null;
                        }),
                      ),
                      if (filtered.isEmpty)
                        EmptyPanel(
                          icon: all.isEmpty
                              ? Icons.receipt_long_outlined
                              : Icons.search_off_rounded,
                          title: all.isEmpty
                              ? 'No transactions yet'
                              : 'No matching transactions',
                          message: all.isEmpty
                              ? 'Add your first transaction to start tracking your money.'
                              : 'Try a different search or clear your filters.',
                          action: all.isEmpty
                              ? 'Add Transaction'
                              : 'Clear search and filters',
                          onAction: all.isEmpty
                              ? _add
                              : () => setState(() {
                                  _search.clear();
                                  _filters = const _TransactionFilters();
                                  _type = null;
                                }),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.builder(
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    final group = sections[index];
                    return Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 0 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
                            child: Text(
                              _dayLabel(group.key, ledger.now),
                              style: textStyle(
                                12,
                                color: Palette.secondary,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TransactionGroup(entries: group.value),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return widget.accountId == null
        ? content
        : Subpage(title: 'Account history', child: content);
  }
}

String _dayLabel(DateTime date, DateTime now) {
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  if (sameDay(date, now)) return 'Today — ${shortDate(date)}';
  if (sameDay(date, yesterday)) return 'Yesterday — ${shortDate(date)}';
  if (date.year != now.year) return fullDate(date);
  return '${weekdays[date.weekday - 1]} — ${shortDate(date)}';
}

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard({required this.ledger});
  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final now = ledger.now;
    final flow = ledger.monthlyCashFlow(now);
    final net = flow.income - flow.expenses;

    return Surface(
      color: Palette.greenSurface,
      border: Palette.greenLine,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: Palette.mint,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  monthLabel(now),
                  style: textStyle(
                    12,
                    weight: FontWeight.w700,
                    color: Palette.mint,
                  ),
                ),
              ),
              const Icon(
                Icons.insights_outlined,
                size: 17,
                color: Palette.mint,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MoneyText(
                      net,
                      size: 34,
                      plus: true,
                      weight: FontWeight.w900,
                      fit: true,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Net cash flow this month',
                      style: textStyle(11, color: Palette.secondary),
                    ),
                  ],
                ),
              ),
              if (flow.income > 0 || flow.expenses > 0)
                Expanded(
                  flex: 3,
                  child: SizedBox(height: 43, child: Sparkline(flow.trend)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Palette.greenLine),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _CashMetric(
                  flow.excludedIncome > 0 ? 'Income counted' : 'Income',
                  flow.income,
                  EntryType.income,
                ),
              ),
              Container(width: 1, height: 31, color: Palette.greenLine),
              const SizedBox(width: 13),
              Expanded(
                child: _CashMetric(
                  'Expenses',
                  flow.expenses,
                  EntryType.expense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashMetric extends StatelessWidget {
  const _CashMetric(this.title, this.amount, this.type);
  final String title;
  final int amount;
  final EntryType type;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Glyph(
        typeIcon(type),
        typeColour(type),
        size: 31,
        radius: 9,
        iconSize: 15,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textStyle(10, color: Palette.secondary)),
            const SizedBox(height: 2),
            MoneyText(amount, size: 14, color: typeColour(type), fit: true),
          ],
        ),
      ),
    ],
  );
}

class TransactionGroup extends StatelessWidget {
  const TransactionGroup({super.key, required this.entries, this.category});
  final List<Entry> entries;
  final Category? category;

  @override
  Widget build(BuildContext context) => Surface(
    padding: EdgeInsets.zero,
    radius: 15,
    child: Column(
      children: [
        for (final (index, entry) in entries.indexed) ...[
          if (index != 0) const Divider(height: 1, indent: 61, endIndent: 12),
          TransactionTile(entry, category: category),
        ],
      ],
    ),
  );
}

class TransactionTile extends StatelessWidget {
  const TransactionTile(this.entry, {super.key, this.category});
  final Entry entry;
  final Category? category;

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final classification = category ?? entry.category;
    final visual = classification == null
        ? (icon: typeIcon(entry.type), color: typeColour(entry.type))
        : categoryVisual(classification);
    final account = ledger.accountName(entry.accountId);
    final detail = entry.type == EntryType.transfer
        ? '$account → ${ledger.accountName(entry.destinationId)}'
        : '${classification?.label ?? entry.type.label} · $account';
    final amount = category == null
        ? entry.amount
        : entry.allocations[category] ?? 0;
    return InkWell(
      onTap: () => openPage<void>(context, TransactionDetails(id: entry.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        child: Row(
          children: [
            Glyph(visual.icon, visual.color, size: 40, iconSize: 20),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle(14, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle(11, color: Palette.secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MoneyText(
                    entry.type == EntryType.expense ? -amount : amount,
                    size: 14,
                    plus:
                        entry.type == EntryType.income ||
                        entry.type == EntryType.adjustment,
                    color: typeColour(entry.type),
                    align: TextAlign.right,
                    fit: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeLabel(entry.date),
                    style: textStyle(10, color: Palette.muted, tabular: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionDetails extends StatefulWidget {
  const TransactionDetails({super.key, required this.id});
  final String id;

  @override
  State<TransactionDetails> createState() => _TransactionDetailsState();
}

class _TransactionDetailsState extends State<TransactionDetails> {
  bool _deleting = false;

  Future<void> _delete(Ledger ledger) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete transaction?',
      message: 'The transaction will be removed and balances, charts and budgets will update.',
      action: 'Delete transaction',
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ledger.deleteEntry(widget.id);
      if (!mounted) return;
      Navigator.pop(context);
      feedback(context, 'Transaction deleted');
    } catch (error) {
      if (!mounted) return;
      feedback(context, actionError(error));
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final entry = ledger.entry(widget.id);
    if (entry == null) {
      return Subpage(
        title: 'Transaction details',
        child: PageScroll(
          children: const [
            EmptyPanel(
              icon: Icons.receipt_long_outlined,
              title: 'Transaction unavailable',
              message: 'This transaction has been removed.',
            ),
          ],
        ),
      );
    }
    final category = entry.category;
    final visual = category == null
        ? (icon: typeIcon(entry.type), color: typeColour(entry.type))
        : categoryVisual(category);
    return Subpage(
      title: 'Transaction details',
      child: PageScroll(
        children: [
          Surface(
            color: Palette.greenSurface,
            border: Palette.greenLine,
            child: Column(
              children: [
                Glyph(
                  visual.icon,
                  visual.color,
                  size: 54,
                  iconSize: 26,
                  radius: 15,
                ),
                const SizedBox(height: 10),
                Text(
                  entry.name,
                  textAlign: TextAlign.center,
                  style: textStyle(18, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                MoneyText(
                  entry.type == EntryType.expense
                      ? -entry.amount
                      : entry.amount,
                  size: 35,
                  color: typeColour(entry.type),
                  plus:
                      entry.type == EntryType.income ||
                      entry.type == EntryType.adjustment,
                  fit: true,
                  align: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  entry.type.label,
                  style: textStyle(12, color: Palette.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Details'),
          Surface(
            child: Column(
              children: [
                if (category != null) DetailLine('Category', category.label),
                if (entry.type == EntryType.income)
                  DetailLine(
                    'Net cash flow',
                    entry.includeInCashFlow ? 'Included' : 'Excluded',
                  ),
                DetailLine(
                  entry.type == EntryType.transfer ? 'From account' : 'Account',
                  ledger.accountName(entry.accountId),
                ),
                if (entry.type == EntryType.transfer)
                  DetailLine(
                    'To account',
                    ledger.accountName(entry.destinationId),
                  ),
                DetailLine(
                  'Date and time',
                  '${fullDate(entry.date)} · ${timeLabel(entry.date)}',
                ),
                DetailLine('Description', entry.name),
                DetailLine('Notes', entry.notes.isEmpty ? 'None' : entry.notes),
              ],
            ),
          ),
          if (entry.items.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionTitle('Itemised purchases'),
            Surface(
              child: Column(
                children: [
                  for (final item in entry.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: textStyle(14, weight: FontWeight.w700),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${item.quantity} × ${masked(context, item.unitPrice)} · ${(item.category ?? category)?.label ?? 'Other'}',
                                  style: textStyle(
                                    11,
                                    color: Palette.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          MoneyText(item.total),
                        ],
                      ),
                    ),
                  const Divider(),
                  DetailLine(
                    'Items subtotal',
                    masked(context, entry.itemSubtotal),
                  ),
                  DetailLine(
                    'Unitemised amount',
                    masked(context, entry.amount - entry.itemSubtotal),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _deleting
                ? null
                : () => openPage<void>(
                    context,
                    EntryForm(existing: entry),
                    form: true,
                  ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit Transaction'),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _deleting ? null : () => _delete(ledger),
            style: TextButton.styleFrom(
              foregroundColor: Palette.expense,
              minimumSize: const Size(0, 46),
            ),
            icon: _deleting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete Transaction'),
          ),
        ],
      ),
    );
  }
}

class DetailLine extends StatelessWidget {
  const DetailLine(
    this.label,
    this.value, {
    super.key,
    this.color = Palette.text,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: textStyle(12, color: Palette.secondary)),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: textStyle(
              12,
              color: color,
              weight: FontWeight.w700,
              tabular: true,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TransactionFilters {
  const _TransactionFilters({this.account, this.category, this.range});
  final String? account;
  final Category? category;
  final DateTimeRange? range;
  bool get active => account != null || category != null || range != null;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.current, required this.accountLocked});
  final _TransactionFilters current;
  final bool accountLocked;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _account = widget.current.account;
  late Category? _category = widget.current.category;
  late DateTimeRange? _range = widget.current.range;

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionTitle(
              'Filter transactions',
              action: 'Reset',
              onAction: () => setState(() {
                _account = null;
                _category = null;
                _range = null;
              }),
            ),
            if (!widget.accountLocked) ...[
              SelectField(
                label: 'Account',
                value: _account == null
                    ? 'All accounts'
                    : ledger.accountName(_account),
                onTap: () async {
                  final result = await choose(context, 'Filter by account', [
                    const SheetOption('', 'All accounts'),
                    for (final account in ledger.accounts)
                      SheetOption(
                        account.id,
                        account.name,
                        icon: accountSymbol(account.icon),
                        color: Color(account.colour),
                      ),
                  ], selected: _account ?? '');
                  if (mounted && result != null) {
                    setState(() => _account = result.isEmpty ? null : result);
                  }
                },
              ),
              const SizedBox(height: 14),
            ],
            SelectField(
              label: 'Category',
              value: _category?.label ?? 'All categories',
              onTap: () async {
                final result = await choose(context, 'Filter by category', [
                  const SheetOption('', 'All categories'),
                  for (final category in Category.values)
                    SheetOption(
                      category.name,
                      category.label,
                      icon: categoryVisual(category).icon,
                      color: categoryVisual(category).color,
                    ),
                ], selected: _category?.name ?? '');
                if (mounted && result != null) {
                  setState(
                    () => _category = result.isEmpty
                        ? null
                        : Category.values.byName(result),
                  );
                }
              },
            ),
            const SizedBox(height: 14),
            SelectField(
              label: 'Date range',
              value: _range == null
                  ? 'Any time'
                  : '${shortDate(_range!.start)} – ${fullDate(_range!.end)}',
              trailing: Icons.calendar_today_outlined,
              onTap: () async {
                final result = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(1900),
                  lastDate: ledger.now,
                  initialDateRange: _range,
                );
                if (mounted && result != null) setState(() => _range = result);
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _TransactionFilters(
                  account: _account,
                  category: _category,
                  range: _range,
                ),
              ),
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
  }
}
