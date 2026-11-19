import 'package:flutter/material.dart';

import '../data/models.dart';
import 'backup_panel.dart';
import 'budgets.dart';
import 'charts.dart';
import 'design.dart';
import 'transactions.dart';

class AnalysisView extends StatefulWidget {
  const AnalysisView({super.key});

  @override
  State<AnalysisView> createState() => _AnalysisViewState();
}

class _AnalysisViewState extends State<AnalysisView> {
  DateTime? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final current = DateTime(ledger.now.year, ledger.now.month);
    final month = _selectedMonth ?? current;
    final reference = periodReference(month, ledger.now);
    final span = DateSpan.month(month);
    final breakdown = ledger.breakdown(span);
    final amount = ledger.spending(span);
    final overall = ledger.preferredBudget(null);
    final categoryBudgets = ledger.budgets
        .where((goal) => goal.category != null)
        .toList();
    void add() => openPage<void>(context, const BudgetForm(), form: true);
    void categoryDetails(Category category) => openPage<void>(
      context,
      CategoryAnalysis(category: category, month: month),
    );
    return Column(
      children: [
        MainHeader(
          title: 'Analysis',
          actionLabel: 'Create budget goal',
          onAdd: add,
        ),
        Expanded(
          child: PageScroll(
            storageKey: const PageStorageKey('analysis'),
            top: 0,
            children: [
              _MonthControl(
                month: month,
                previous: () => setState(
                  () => _selectedMonth = DateTime(month.year, month.month - 1),
                ),
                next: !month.isBefore(current)
                    ? null
                    : () => setState(
                        () => _selectedMonth = DateTime(
                          month.year,
                          month.month + 1,
                        ),
                      ),
              ),
              const SizedBox(height: 13),
              _MonthlySpending(
                amount: amount,
                budget: overall,
                used: overall == null
                    ? 0
                    : ledger.budgetUsage(overall, reference),
                onCreate: add,
              ),
              const SizedBox(height: 21),
              const SectionTitle('Spending breakdown'),
              if (breakdown.isEmpty)
                const EmptyPanel(
                  icon: Icons.donut_large_rounded,
                  title: 'No spending data yet',
                  message: 'Your spending insights will appear as you add transactions.',
                )
              else
                _BreakdownCard(
                  breakdown: breakdown,
                  total: amount,
                  onSelect: categoryDetails,
                ),
              const SizedBox(height: 21),
              SectionTitle(
                'Budget goals',
                action: 'See all',
                onAction: () => openPage<void>(
                  context,
                  BudgetManagement(reference: reference),
                ),
              ),
              if (ledger.budgets.isEmpty)
                EmptyPanel(
                  icon: Icons.track_changes_rounded,
                  title: 'No budgets created',
                  message:
                      'Set a spending goal to stay on top of your finances.',
                  action: 'Create Budget',
                  onAction: add,
                )
              else if (categoryBudgets.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Surface(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.category_outlined,
                          color: Palette.mint,
                          size: 21,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Set a limit for a specific spending category.',
                            style: textStyle(13, color: Palette.secondary),
                          ),
                        ),
                        TextButton(
                          onPressed: add,
                          child: const Text('Create goal'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final budget in categoryBudgets.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: BudgetCard(
                      budget: budget,
                      used: ledger.budgetUsage(budget, reference),
                      onTap: () => openPage<void>(
                        context,
                        CategoryAnalysis(
                          category: budget.category!,
                          month: month,
                          budgetId: budget.id,
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 18),
              const SectionTitle('Spending trends'),
              _Trends(month: month),
              const SizedBox(height: 21),
              const SectionTitle('Insights'),
              _Insights(
                month: month,
                breakdown: breakdown,
                reference: reference,
              ),
              const SizedBox(height: 21),
              const BackupPanel(),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthControl extends StatelessWidget {
  const _MonthControl({required this.month, required this.previous, this.next});
  final DateTime month;
  final VoidCallback previous;
  final VoidCallback? next;

  @override
  Widget build(BuildContext context) => Surface(
    radius: 13,
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: previous,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: Palette.mint,
                size: 15,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  monthLabel(month),
                  textAlign: TextAlign.center,
                  style: textStyle(14, weight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: next,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}

class _MonthlySpending extends StatelessWidget {
  const _MonthlySpending({
    required this.amount,
    required this.budget,
    required this.used,
    required this.onCreate,
  });
  final int amount;
  final Budget? budget;
  final int used;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final goal = budget;
    final samePeriod = goal?.period == BudgetPeriod.monthly;
    return Surface(
      color: Palette.greenSurface,
      border: Palette.greenLine,
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Monthly spending',
                  style: textStyle(
                    13,
                    color: Palette.mint,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              const Glyph(
                Icons.track_changes_rounded,
                Palette.mint,
                size: 31,
                iconSize: 17,
                radius: 9,
              ),
            ],
          ),
          MoneyText(amount, size: 35, weight: FontWeight.w900, fit: true),
          if (goal == null) ...[
            const SizedBox(height: 6),
            Text(
              'Set an overall budget to track how much you have left.',
              style: textStyle(12, color: Palette.secondary, height: 1.4),
            ),
            TextButton(
              onPressed: onCreate,
              child: const Text('Create a budget'),
            ),
          ] else ...[
            const SizedBox(height: 5),
            Text(
              samePeriod
                  ? 'of ${masked(context, goal.limit)} budget'
                  : '${goal.period.label} budget · ${masked(context, used)} of ${masked(context, goal.limit)}',
              style: textStyle(12, color: Palette.secondary),
            ),
            const SizedBox(height: 15),
            BudgetStatus(limit: goal.limit, used: used),
          ],
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.breakdown,
    required this.total,
    required this.onSelect,
  });
  final Map<Category, int> breakdown;
  final int total;
  final ValueChanged<Category> onSelect;

  @override
  Widget build(BuildContext context) {
    final hidden = LedgerScope.of(context).hidden;
    final legend = Column(
      children: [
        for (final slice in breakdown.entries)
          InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: () => onSelect(slice.key),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: categoryVisual(slice.key).color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: Text(slice.key.label, style: textStyle(12))),
                  const SizedBox(width: 3),
                  Text(
                    hidden ? '••%' : percentage(slice.value / total),
                    style: textStyle(
                      11,
                      color: Palette.secondary,
                      tabular: true,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Palette.muted,
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    final chart = SpendingDonut(slices: breakdown, onSelect: onSelect);
    return Surface(
      padding: const EdgeInsets.all(13),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 290 ||
              MediaQuery.textScalerOf(context).scale(12) > 17) {
            return Column(
              children: [chart, const SizedBox(height: 10), legend],
            );
          }
          return Row(
            children: [
              chart,
              const SizedBox(width: 11),
              Expanded(child: legend),
            ],
          );
        },
      ),
    );
  }
}

class _Trends extends StatefulWidget {
  const _Trends({required this.month});
  final DateTime month;

  @override
  State<_Trends> createState() => _TrendsState();
}

class _TrendsState extends State<_Trends> {
  int _count = 6;
  Category? _category;
  String? _account;

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final dates = List.generate(
      _count,
      (index) =>
          DateTime(widget.month.year, widget.month.month - _count + index + 1),
    );
    final account = ledger.account(_account);
    return Surface(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            children: [
              for (final count in [3, 6, 12])
                SmallChip(
                  '${count}M',
                  selected: _count == count,
                  onTap: () => setState(() => _count = count),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectField(
                  label: 'Category',
                  value: _category?.label ?? 'All expenses',
                  onTap: () async {
                    final choice = await choose(context, 'Spending category', [
                      const SheetOption('', 'All expenses'),
                      for (final category in Category.forType(
                        EntryType.expense,
                      ))
                        SheetOption(
                          category.name,
                          category.label,
                          icon: categoryVisual(category).icon,
                          color: categoryVisual(category).color,
                        ),
                    ], selected: _category?.name ?? '');
                    if (mounted && choice != null) {
                      setState(
                        () => _category = choice.isEmpty
                            ? null
                            : Category.values.byName(choice),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectField(
                  label: 'Account',
                  value: account?.name ?? 'All accounts',
                  onTap: () async {
                    final choice = await choose(context, 'Spending account', [
                      const SheetOption('', 'All accounts'),
                      for (final account in ledger.accounts)
                        SheetOption(
                          account.id,
                          account.name,
                          icon: accountSymbol(account.icon),
                          color: Color(account.colour),
                        ),
                    ], selected: account?.id ?? '');
                    if (mounted && choice != null) {
                      setState(() => _account = choice.isEmpty ? null : choice);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SpendingBars(
            labels: dates.map(shortMonth).toList(),
            values: dates
                .map(
                  (date) => ledger.spending(
                    DateSpan.month(date),
                    category: _category,
                    accountId: account?.id,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  const _Insights({
    required this.month,
    required this.breakdown,
    required this.reference,
  });
  final DateTime month;
  final Map<Category, int> breakdown;
  final DateTime reference;

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final List<({String text, IconData icon, Color color})> insights = [];
    if (!ledger.hidden) {
      final previous = ledger.breakdown(
        DateSpan.month(DateTime(month.year, month.month - 1)),
      );
      final groceries = breakdown[Category.groceries] ?? 0;
      final previousGroceries = previous[Category.groceries] ?? 0;
      if (previousGroceries > 0 && groceries != previousGroceries) {
        final percent = percentage(
          (groceries - previousGroceries).abs() / previousGroceries,
        );
        final down = groceries < previousGroceries;
        insights.add((
          text:
              'Groceries are $percent ${down ? 'lower' : 'higher'} than last month.',
          icon: down ? Icons.trending_down_rounded : Icons.trending_up_rounded,
          color: down ? Palette.income : Palette.amber,
        ));
      }
      final goal = ledger.budgets
          .where(
            (goal) =>
                goal.category != null &&
                ledger.budgetUsage(goal, reference) / goal.limit >= .75,
          )
          .firstOrNull;
      if (goal != null) {
        final fraction = ledger.budgetUsage(goal, reference) / goal.limit;
        insights.add((
          text:
              'You’ve used ${percentage(fraction)} of your ${goal.period.label.toLowerCase()} ${goal.name} budget.',
          icon: Icons.track_changes_rounded,
          color: budgetColour(fraction),
        ));
      }
      if (breakdown.isNotEmpty) {
        final highest = breakdown.entries.first;
        insights.add((
          text:
              '${highest.key.label} is your largest spending category at ${money(highest.value)}.',
          icon: categoryVisual(highest.key).icon,
          color: categoryVisual(highest.key).color,
        ));
      }
      final moreSubscriptions =
          (breakdown[Category.subscriptions] ?? 0) -
          (previous[Category.subscriptions] ?? 0);
      if (previous.isNotEmpty && moreSubscriptions > 0) {
        insights.add((
          text:
              'You spent ${money(moreSubscriptions)} more on subscriptions than last month.',
          icon: Icons.subscriptions_outlined,
          color: Palette.purple,
        ));
      }
    }
    if (insights.isEmpty) {
      return Surface(
        child: Text(
          ledger.hidden
              ? 'Reveal amounts to see spending insights.'
              : 'Insights will appear as you record more expenses.',
          style: textStyle(13, color: Palette.secondary),
        ),
      );
    }
    return Surface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Column(
        children: [
          for (final (index, insight) in insights.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: 42),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Glyph(
                    insight.icon,
                    insight.color,
                    size: 34,
                    iconSize: 17,
                    radius: 9,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      insight.text,
                      style: textStyle(13, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CategoryAnalysis extends StatefulWidget {
  const CategoryAnalysis({
    super.key,
    required this.category,
    required this.month,
    this.budgetId,
  });
  final Category category;
  final DateTime month;
  final String? budgetId;

  @override
  State<CategoryAnalysis> createState() => _CategoryAnalysisState();
}

class _CategoryAnalysisState extends State<CategoryAnalysis> {
  BudgetPeriod _range = BudgetPeriod.monthly;

  List<DateSpan> _history(DateTime reference) => switch (_range) {
    BudgetPeriod.weekly => List.generate(
      6,
      (index) => _range.span(
        DateTime(
          reference.year,
          reference.month,
          reference.day - (5 - index) * 7,
        ),
      ),
    ),
    BudgetPeriod.monthly => List.generate(
      6,
      (index) =>
          _range.span(DateTime(reference.year, reference.month - 5 + index)),
    ),
    BudgetPeriod.yearly => List.generate(
      5,
      (index) => _range.span(DateTime(reference.year - 4 + index)),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final category = widget.category;
    final month = widget.month;
    final reference = periodReference(month, ledger.now);
    final visual = categoryVisual(category);
    final span = DateSpan.month(month);
    final entries = ledger.entries
        .where(
          (entry) =>
              span.contains(entry.date) &&
              entry.allocations.containsKey(category),
        )
        .toList();
    final amount = entries.fold(
      0,
      (sum, entry) => sum + entry.allocations[category]!,
    );
    final selectedBudget = widget.budgetId == null
        ? null
        : ledger.budget(widget.budgetId!);
    final budget = selectedBudget?.category == category
        ? selectedBudget
        : ledger.preferredBudget(category);
    final used = budget == null ? 0 : ledger.budgetUsage(budget, reference);
    final history = _history(reference);
    final merchants = <String, _MerchantTotal>{};
    final purchased = <String, _ProductTotal>{};
    for (final entry in entries) {
      final merchant = merchants.putIfAbsent(
        entry.name.toLowerCase(),
        () => _MerchantTotal(entry.name),
      );
      merchant.total += entry.allocations[category]!;
      for (final item in entry.items.where(
        (item) => (item.category ?? entry.category) == category,
      )) {
        final product = purchased.putIfAbsent(
          item.name.toLowerCase(),
          () => _ProductTotal(item.name),
        );
        product.total += item.total;
        product.quantity += item.quantity;
        product.entries.add(entry.id);
      }
    }
    final merchantRows = merchants.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final productRows = purchased.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final groups = <DateTime, List<Entry>>{};
    for (final entry in entries) {
      (groups[DateUtils.dateOnly(entry.date)] ??= []).add(entry);
    }
    final hidden = ledger.hidden;

    return Subpage(
      title: category.label,
      child: PageScroll(
        children: [
          Surface(
            color: Palette.greenSurface,
            border: Palette.greenLine,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total spent',
                            style: textStyle(
                              13,
                              color: Palette.mint,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          MoneyText(
                            amount,
                            size: 35,
                            weight: FontWeight.w900,
                            fit: true,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            monthLabel(month),
                            style: textStyle(12, color: Palette.secondary),
                          ),
                        ],
                      ),
                    ),
                    Glyph(visual.icon, visual.color, size: 44, iconSize: 23),
                  ],
                ),
                const SizedBox(height: 11),
                if (budget == null)
                  TextButton(
                    onPressed: () => openPage<void>(
                      context,
                      BudgetForm(initialCategory: category),
                      form: true,
                    ),
                    child: const Text('Set a category budget'),
                  )
                else ...[
                  const Divider(height: 1, color: Palette.greenLine),
                  const SizedBox(height: 6),
                  DetailLine(
                    '${budget.period.label} budget',
                    masked(context, budget.limit),
                  ),
                  if (budget.period != BudgetPeriod.monthly)
                    DetailLine(
                      'Spent this ${budget.period.unit}',
                      masked(context, used),
                    ),
                  const SizedBox(height: 8),
                  BudgetStatus(limit: budget.limit, used: used),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => openPage<void>(
                        context,
                        BudgetDetails(id: budget.id, reference: reference),
                      ),
                      child: const Text('View budget goal'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 21),
          const SectionTitle('Spending trend'),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 5,
                  children: [
                    for (final period in BudgetPeriod.values)
                      SmallChip(
                        period.label,
                        selected: period == _range,
                        onTap: () => setState(() => _range = period),
                      ),
                  ],
                ),
                const SizedBox(height: 11),
                SpendingBars(
                  labels: history
                      .map(
                        (period) => switch (_range) {
                          BudgetPeriod.weekly => shortDate(period.start),
                          BudgetPeriod.monthly => shortMonth(period.start),
                          BudgetPeriod.yearly => period.start.year.toString(),
                        },
                      )
                      .toList(),
                  values: history
                      .map(
                        (period) => ledger.spending(period, category: category),
                      )
                      .toList(),
                  color: visual.color,
                ),
              ],
            ),
          ),
          const SizedBox(height: 21),
          const SectionTitle('Merchant breakdown'),
          if (merchantRows.isEmpty)
            const EmptyPanel(
              icon: Icons.storefront_outlined,
              title: 'No purchases this month',
              message: 'Merchants will appear here when spending is recorded in this category.',
            )
          else
            Surface(
              child: Column(
                children: [
                  for (final merchant in merchantRows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              merchant.name,
                              style: textStyle(13, weight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hidden
                                ? '••%'
                                : percentage(merchant.total / amount),
                            style: textStyle(
                              11,
                              color: Palette.secondary,
                              tabular: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: MoneyText(
                              merchant.total,
                              size: 13,
                              fit: true,
                              align: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (productRows.isNotEmpty) ...[
            const SizedBox(height: 21),
            const SectionTitle('Purchased items'),
            Surface(
              child: Column(
                children: [
                  for (final product in productRows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: textStyle(13, weight: FontWeight.w700),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${product.entries.length} ${product.entries.length == 1 ? 'purchase' : 'purchases'} · ${product.quantity} ${product.quantity == 1 ? 'unit' : 'units'}',
                                  style: textStyle(
                                    11,
                                    color: Palette.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: MoneyText(
                              product.total,
                              size: 13,
                              fit: true,
                              align: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 21),
          const SectionTitle('Category transactions'),
          if (groups.isEmpty)
            const EmptyPanel(
              icon: Icons.receipt_long_outlined,
              title: 'No category transactions',
              message: 'Transactions contributing to this category will appear here.',
            )
          else
            for (final group in groups.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text(
                        fullDate(group.key),
                        style: textStyle(12, color: Palette.secondary),
                      ),
                    ),
                    TransactionGroup(entries: group.value, category: category),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _MerchantTotal {
  _MerchantTotal(this.name);
  final String name;
  int total = 0;
}

class _ProductTotal {
  _ProductTotal(this.name);
  final String name;
  int total = 0;
  int quantity = 0;
  final entries = <String>{};
}
