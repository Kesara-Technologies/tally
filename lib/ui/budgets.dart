import 'package:flutter/material.dart';

import '../data/ledger.dart';
import '../data/models.dart';
import 'design.dart';
import 'transactions.dart' show DetailLine;

class BudgetForm extends StatefulWidget {
  const BudgetForm({super.key, this.existing, this.initialCategory});
  final Budget? existing;
  final Category? initialCategory;

  @override
  State<BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<BudgetForm> {
  final _form = GlobalKey<FormState>();
  late bool _categoryLimit =
      (widget.existing?.category ?? widget.initialCategory) != null;
  late Category? _category =
      widget.existing?.category ?? widget.initialCategory;
  late BudgetPeriod _period = widget.existing?.period ?? BudgetPeriod.monthly;
  late final _amount = TextEditingController(
    text: widget.existing == null ? '' : moneyInput(widget.existing!.limit),
  );
  bool _saving = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save(Ledger ledger) async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_form.currentState!.validate() ||
        (_categoryLimit && _category == null)) {
      return;
    }
    setState(() => _saving = true);
    try {
      final id = widget.existing?.id ?? ledger.newId();
      await ledger.putBudget(
        Budget(
          id,
          parseMoney(_amount.text)!,
          _period,
          _categoryLimit ? _category : null,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      feedback(
        context,
        widget.existing == null ? 'Budget created' : 'Budget updated',
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = actionError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final amount = parseMoney(_amount.text);
    final preview = amount == null || amount <= 0
        ? 'Enter a limit to preview your goal.'
        : 'Spend no more than ${masked(context, amount)} ${_categoryLimit ? 'on ${_category?.label ?? 'the selected category'}' : 'in total'} each ${_period.unit}.';
    return Subpage(
      title: widget.existing == null
          ? 'Create Budget Goal'
          : 'Edit Budget Goal',
      footer: PrimaryFooter(
        title: widget.existing == null ? 'Create Goal' : 'Save Changes',
        loading: _saving,
        onPressed: () => _save(ledger),
      ),
      child: Form(
        key: _form,
        child: FormScroll(
          children: [
            const Label('Goal Type'),
            Surface(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: RadioGroup<bool>(
                groupValue: _categoryLimit,
                onChanged: (value) =>
                    setState(() => _categoryLimit = value ?? false),
                child: Column(
                  children: [
                    RadioListTile(
                      value: false,
                      enabled: !_saving,
                      title: Text(
                        'Overall spending limit',
                        style: textStyle(14, weight: FontWeight.w700),
                      ),
                      secondary: const Icon(
                        Icons.track_changes_rounded,
                        color: Palette.mint,
                        size: 20,
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    RadioListTile(
                      value: true,
                      enabled: !_saving,
                      title: Text(
                        'Category spending limit',
                        style: textStyle(14, weight: FontWeight.w700),
                      ),
                      secondary: const Icon(
                        Icons.category_outlined,
                        color: Palette.mint,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_categoryLimit) ...[
              const SizedBox(height: 15),
              SelectField(
                label: 'Category',
                value: _category?.label ?? 'Choose category',
                error: _submitted && _category == null
                    ? 'Choose a category'
                    : null,
                onTap: _saving
                    ? null
                    : () async {
                        FocusScope.of(context).unfocus();
                        final chosen = await chooseCategory(
                          context,
                          type: EntryType.expense,
                          selected: _category,
                        );
                        if (mounted && chosen != null) {
                          setState(() => _category = chosen);
                        }
                      },
              ),
            ],
            const SizedBox(height: 15),
            const Label('Budget Amount'),
            TextFormField(
              controller: _amount,
              enabled: !_saving,
              obscureText: ledger.hidden,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: textStyle(16, tabular: true, weight: FontWeight.w700),
              decoration: const InputDecoration(
                prefixText: '£ ',
                hintText: '300.00',
              ),
              validator: (value) => (parseMoney(value ?? '') ?? 0) <= 0
                  ? 'Enter a budget greater than zero'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 15),
            SelectField(
              label: 'Budget Period',
              value: _period.label,
              leading: const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: Palette.mint,
              ),
              onTap: _saving
                  ? null
                  : () async {
                      FocusScope.of(context).unfocus();
                      final chosen = await choose(context, 'Budget period', [
                        for (final period in BudgetPeriod.values)
                          SheetOption(period, period.label),
                      ], selected: _period);
                      if (mounted && chosen != null) {
                        setState(() => _period = chosen);
                      }
                    },
            ),
            const SizedBox(height: 17),
            Surface(
              color: Palette.greenSurface,
              border: Palette.greenLine,
              child: Row(
                children: [
                  const Glyph(
                    Icons.track_changes_rounded,
                    Palette.mint,
                    size: 37,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Goal summary',
                          style: textStyle(14, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          preview,
                          style: textStyle(
                            12,
                            color: Palette.secondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: textStyle(12, color: Palette.expense),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String budgetRemaining(
  BuildContext context,
  int limit,
  int used, {
  String remainingLabel = 'remaining',
}) {
  final remaining = limit - used;
  final value = masked(context, remaining.abs());
  return remaining < 0 ? '$value over budget' : '$value $remainingLabel';
}

class BudgetStatus extends StatelessWidget {
  const BudgetStatus({super.key, required this.limit, required this.used});
  final int limit;
  final int used;

  @override
  Widget build(BuildContext context) {
    final hidden = LedgerScope.of(context).hidden;
    final fraction = used / limit;
    final color = hidden ? Palette.secondary : budgetColour(fraction);
    return Column(
      children: [
        ProgressTrack(fraction),
        const SizedBox(height: 9),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                hidden ? 'Usage hidden' : '${percentage(fraction)} used',
                style: textStyle(
                  11,
                  color: color,
                  weight: FontWeight.w700,
                  tabular: true,
                ),
              ),
            ),
            Expanded(
              child: Text(
                hidden ? '£••••.••' : budgetRemaining(context, limit, used),
                textAlign: TextAlign.right,
                style: textStyle(
                  11,
                  color: color,
                  weight: FontWeight.w700,
                  tabular: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    required this.budget,
    required this.used,
    required this.onTap,
  });
  final Budget budget;
  final int used;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = budget.category;
    final visual = category == null
        ? (icon: Icons.track_changes_rounded, color: Palette.mint)
        : categoryVisual(category);
    final hidden = LedgerScope.of(context).hidden;
    return Surface(
      onTap: onTap,
      radius: 15,
      padding: const EdgeInsets.all(13),
      child: Column(
        children: [
          Row(
            children: [
              Glyph(visual.icon, visual.color, size: 36, iconSize: 18),
              const SizedBox(width: 9),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.name,
                      style: textStyle(14, weight: FontWeight.w700),
                    ),
                    Text(
                      budget.period.label,
                      style: textStyle(11, color: Palette.secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                flex: 4,
                child: Text(
                  hidden
                      ? '£••••.•• / £••••.••'
                      : '${money(used)} / ${money(budget.limit)}',
                  textAlign: TextAlign.right,
                  style: textStyle(12, color: Palette.secondary, tabular: true),
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: Palette.muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          BudgetStatus(limit: budget.limit, used: used),
        ],
      ),
    );
  }
}

class BudgetManagement extends StatelessWidget {
  const BudgetManagement({super.key, required this.reference});
  final DateTime reference;

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    void add() => openPage<void>(context, const BudgetForm(), form: true);
    return Subpage(
      title: 'Budget Goals',
      actions: [
        IconButton(
          tooltip: 'Create budget goal',
          onPressed: add,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      child: PageScroll(
        children: [
          if (ledger.budgets.isEmpty)
            EmptyPanel(
              icon: Icons.track_changes_rounded,
              title: 'No budgets created',
              message: 'Set a spending goal to stay on top of your finances.',
              action: 'Create Budget',
              onAction: add,
            )
          else
            for (final overall in [true, false]) ...[
              SectionTitle(overall ? 'Overall Budget' : 'Category Budgets'),
              if (!ledger.budgets.any(
                (budget) => (budget.category == null) == overall,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    overall
                        ? 'No overall budgets yet.'
                        : 'No category budgets yet.',
                    style: textStyle(13, color: Palette.secondary),
                  ),
                ),
              for (final budget in ledger.budgets.where(
                (budget) => (budget.category == null) == overall,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BudgetCard(
                    budget: budget,
                    used: ledger.budgetUsage(budget, reference),
                    onTap: () => openPage<void>(
                      context,
                      BudgetDetails(id: budget.id, reference: reference),
                    ),
                  ),
                ),
              if (overall) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class BudgetDetails extends StatefulWidget {
  const BudgetDetails({super.key, required this.id, required this.reference});
  final String id;
  final DateTime reference;

  @override
  State<BudgetDetails> createState() => _BudgetDetailsState();
}

class _BudgetDetailsState extends State<BudgetDetails> {
  bool _deleting = false;

  Future<void> _delete(Ledger ledger) async {
    final approved = await confirmAction(
      context,
      title: 'Delete budget goal?',
      message: 'The goal and its limit will be removed. Your transactions will still appear in the ledger.',
      action: 'Delete budget',
    );
    if (!mounted || !approved) return;
    setState(() => _deleting = true);
    try {
      await ledger.deleteBudget(widget.id);
      if (!mounted) return;
      Navigator.pop(context);
      feedback(context, 'Budget deleted');
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      feedback(context, actionError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final budget = ledger.budget(widget.id);
    if (budget == null) {
      return Subpage(
        title: 'Budget details',
        child: PageScroll(
          children: const [
            EmptyPanel(
              icon: Icons.track_changes_rounded,
              title: 'Budget unavailable',
              message: 'This budget has been removed.',
            ),
          ],
        ),
      );
    }
    final used = ledger.budgetUsage(budget, widget.reference);
    final span = budget.period.span(widget.reference);
    final lastDay = DateTime(span.end.year, span.end.month, span.end.day - 1);
    final category = budget.category;
    final visual = category == null
        ? (icon: Icons.track_changes_rounded, color: Palette.mint)
        : categoryVisual(category);
    return Subpage(
      title: 'Budget details',
      child: PageScroll(
        children: [
          Surface(
            color: Palette.greenSurface,
            border: Palette.greenLine,
            child: Column(
              children: [
                Glyph(visual.icon, visual.color, size: 51, iconSize: 25),
                const SizedBox(height: 9),
                Text(
                  budget.name,
                  textAlign: TextAlign.center,
                  style: textStyle(18, weight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                MoneyText(
                  used,
                  size: 34,
                  weight: FontWeight.w900,
                  fit: true,
                  align: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Text(
                  'of ${masked(context, budget.limit)}',
                  style: textStyle(12, color: Palette.secondary),
                ),
                const SizedBox(height: 15),
                BudgetStatus(limit: budget.limit, used: used),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Goal details'),
          Surface(
            child: Column(
              children: [
                DetailLine('Period', budget.period.label),
                DetailLine(
                  'Dates',
                  '${shortDate(span.start)} – ${fullDate(lastDay)}',
                ),
                DetailLine('Budget limit', masked(context, budget.limit)),
                DetailLine('Spent', masked(context, used)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _deleting
                ? null
                : () => openPage<void>(
                    context,
                    BudgetForm(existing: budget),
                    form: true,
                  ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit Budget'),
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
            label: const Text('Delete Budget'),
          ),
        ],
      ),
    );
  }
}
