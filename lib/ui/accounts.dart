import 'dart:math';

import 'package:flutter/material.dart';

import '../data/ledger.dart';
import '../data/models.dart';
import 'account_form.dart';
import 'charts.dart';
import 'design.dart';
import 'entry_form.dart';
import 'transactions.dart';

class AccountsView extends StatelessWidget {
  const AccountsView({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final accounts = [
      ...ledger.activeAccounts,
      ...ledger.accounts.where((account) => account.archived),
    ];
    void add() => openPage<String>(context, const AccountForm(), form: true);
    return Column(
      children: [
        MainHeader(title: 'Accounts', actionLabel: 'Add account', onAdd: add),
        Expanded(
          child: PageScroll(
            storageKey: const PageStorageKey('accounts'),
            top: 0,
            children: [
              _TotalBalance(ledger: ledger),
              const SizedBox(height: 21),
              SectionTitle(
                'Your accounts',
                action: accounts.isEmpty ? null : 'Manage',
                onAction: () => openPage<void>(context, const ManageAccounts()),
              ),
              if (accounts.isEmpty)
                EmptyPanel(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No accounts added',
                  message: 'Create an account to start tracking your balances.',
                  action: 'Add Account',
                  onAction: add,
                )
              else ...[
                for (final account in accounts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AccountCard(
                      account: account,
                      balance: ledger.balance(account),
                      onTap: () => openPage<void>(
                        context,
                        AccountDetails(id: account.id),
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                _DashedAdd(onTap: add),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalBalance extends StatelessWidget {
  const _TotalBalance({required this.ledger});
  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final span = DateSpan.month(ledger.now);
    final change = ledger.combinedChange(span);
    final count = ledger.includedAccounts.length;
    final colors = Theme.of(context).colorScheme;
    return Surface(
      color: Theme.of(context).colorScheme.primaryContainer,
      radius: 30,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SummaryHeading(
            'Total balance',
            Icons.account_balance_wallet_outlined,
            colors.onPrimaryContainer,
          ),
          const SizedBox(height: 4),
          MoneyText(
            ledger.totalBalance,
            size: 45,
            weight: FontWeight.w900,
            fit: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: changeColour(change).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ledger.hidden
                          ? Icons.visibility_off_outlined
                          : change < 0
                          ? Icons.trending_down_rounded
                          : change > 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_flat_rounded,
                      size: 15,
                      color: ledger.hidden
                          ? Palette.secondary
                          : changeColour(change),
                    ),
                    const SizedBox(width: 4),
                    MoneyText(
                      change,
                      color: ledger.hidden
                          ? Palette.secondary
                          : changeColour(change),
                      size: 12,
                      plus: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'This month',
                  style: textStyle(11, color: Palette.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            'Across $count ${count == 1 ? 'account' : 'accounts'}',
            style: textStyle(12, color: Palette.secondary),
          ),
        ],
      ),
    );
  }
}

class _DashedAdd extends StatelessWidget {
  const _DashedAdd({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DashedBorder(
      Theme.of(context).colorScheme.outlineVariant,
    ),
    child: TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 49),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      icon: const Icon(Icons.add_rounded, size: 20),
      label: const Text('Add new account'),
    ),
  );
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.5),
          const Radius.circular(13),
        ),
      );
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 9) {
        canvas.drawPath(
          metric.extractPath(distance, min(distance + 4.5, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorder oldDelegate) =>
      oldDelegate.color != color;
}

class ManageAccounts extends StatefulWidget {
  const ManageAccounts({super.key});

  @override
  State<ManageAccounts> createState() => _ManageAccountsState();
}

class _ManageAccountsState extends State<ManageAccounts> {
  ({bool archived, List<String> ids})? _pendingOrder;

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final active = ledger.activeAccounts;
    final archived = ledger.accounts
        .where((account) => account.archived)
        .toList();
    return Subpage(
      title: 'Manage accounts',
      actions: [
        IconButton(
          tooltip: 'Add account',
          icon: const Icon(Icons.add_rounded),
          onPressed: () =>
              openPage<String>(context, const AccountForm(), form: true),
        ),
      ],
      child: CustomScrollView(
        slivers: [
          if (active.length > 1 || archived.length > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Drag the handles to reorder your accounts.',
                  style: textStyle(13, color: Palette.secondary),
                ),
              ),
            ),
          _accountGroup(
            ledger,
            _displayOrder(active, archived: false),
            archived: false,
          ),
          _accountGroup(
            ledger,
            _displayOrder(archived, archived: true),
            archived: true,
          ),
        ],
      ),
    );
  }

  List<Account> _displayOrder(
    List<Account> accounts, {
    required bool archived,
  }) {
    final pending = _pendingOrder;
    if (pending == null || pending.archived != archived) return accounts;
    final byId = {for (final account in accounts) account.id: account};
    if (byId.length != pending.ids.length ||
        !pending.ids.every(byId.containsKey)) {
      return accounts;
    }
    return [for (final id in pending.ids) byId[id]!];
  }

  Widget _accountGroup(
    Ledger ledger,
    List<Account> accounts, {
    required bool archived,
  }) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
    sliver: SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: SectionTitle(
            archived ? 'Archived accounts' : 'Active accounts',
          ),
        ),
        if (accounts.isEmpty)
          SliverToBoxAdapter(
            child: Text(
              archived ? 'No archived accounts.' : 'No active accounts.',
              style: textStyle(13, color: Palette.secondary),
            ),
          )
        else
          SliverReorderableList(
            itemCount: accounts.length,
            onReorderItem: (from, to) =>
                _reorder(ledger, accounts, from, to, archived: archived),
            itemBuilder: (context, index) {
              final account = accounts[index];
              return Padding(
                key: ValueKey(account.id),
                padding: const EdgeInsets.only(bottom: 10),
                child: AccountCard(
                  account: account,
                  balance: ledger.balance(account),
                  onTap: () =>
                      openPage<void>(context, AccountDetails(id: account.id)),
                  trailing: accounts.length > 1
                      ? Tooltip(
                          message: 'Drag to reorder ${account.name}',
                          child: ReorderableDragStartListener(
                            index: index,
                            enabled: _pendingOrder == null,
                            child: const ColoredBox(
                              color: Colors.transparent,
                              child: SizedBox.square(
                                dimension: 44,
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  color: Palette.muted,
                                ),
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
      ],
    ),
  );

  Future<void> _reorder(
    Ledger ledger,
    List<Account> accounts,
    int from,
    int to, {
    required bool archived,
  }) async {
    if (_pendingOrder != null) return;
    final order = accounts.map((account) => account.id).toList();
    order.insert(to, order.removeAt(from));
    setState(() => _pendingOrder = (archived: archived, ids: order));
    try {
      await ledger.reorderAccounts(order, archived: archived);
    } catch (error) {
      if (mounted) feedback(context, actionError(error));
    } finally {
      if (mounted) setState(() => _pendingOrder = null);
    }
  }
}

enum _AccountAction { name, type, colour, icon, adjustment, inclusion, archive }

class AccountDetails extends StatefulWidget {
  const AccountDetails({super.key, required this.id});
  final String id;

  @override
  State<AccountDetails> createState() => _AccountDetailsState();
}

class _AccountDetailsState extends State<AccountDetails> {
  static const _ranges = <(String, int)>[
    ('1M', 1),
    ('3M', 3),
    ('6M', 6),
    ('1Y', 12),
    ('All', 0),
  ];
  int _range = 1;

  Future<void> _manage(Account account, Ledger ledger) async {
    final choice = await choose(context, 'Account settings', [
      const SheetOption(
        _AccountAction.name,
        'Edit account name',
        icon: Icons.edit_outlined,
      ),
      const SheetOption(
        _AccountAction.type,
        'Change account type',
        icon: Icons.account_balance_outlined,
      ),
      const SheetOption(
        _AccountAction.colour,
        'Change account colour',
        icon: Icons.palette_outlined,
      ),
      const SheetOption(
        _AccountAction.icon,
        'Change account icon',
        icon: Icons.interests_outlined,
      ),
      if (!account.archived)
        const SheetOption(
          _AccountAction.adjustment,
          'Adjust account balance',
          icon: Icons.tune_rounded,
        ),
      SheetOption(
        _AccountAction.inclusion,
        account.included
            ? 'Exclude from total balance'
            : 'Include in total balance',
        icon: Icons.calculate_outlined,
      ),
      SheetOption(
        _AccountAction.archive,
        account.archived ? 'Restore account' : 'Archive account',
        icon: account.archived
            ? Icons.unarchive_outlined
            : Icons.archive_outlined,
        color: Palette.amber,
      ),
    ]);
    if (!mounted || choice == null) return;
    try {
      switch (choice) {
        case _AccountAction.name ||
            _AccountAction.type ||
            _AccountAction.colour ||
            _AccountAction.icon:
          final focus = switch (choice) {
            _AccountAction.name => AccountField.name,
            _AccountAction.type => AccountField.type,
            _AccountAction.colour => AccountField.colour,
            _ => AccountField.icon,
          };
          await openPage<String>(
            context,
            AccountForm(existing: account, focus: focus),
            form: true,
          );
        case _AccountAction.adjustment:
          await openPage<void>(
            context,
            _AdjustmentPage(id: account.id),
            form: true,
          );
        case _AccountAction.inclusion:
          await ledger.putAccount(
            account.withStatus(included: !account.included),
          );
          if (mounted) {
            feedback(
              context,
              account.included
                  ? 'Account excluded from total'
                  : 'Account included in total',
            );
          }
        case _AccountAction.archive:
          if (!account.archived) {
            final confirmed = await confirmAction(
              context,
              title: 'Archive ${account.name}?',
              message: 'You can still view its history and restore the account later.',
              action: 'Archive account',
            );
            if (!mounted || !confirmed) return;
          }
          await ledger.setArchived(account.id, !account.archived);
          if (mounted) {
            feedback(
              context,
              account.archived ? 'Account restored' : 'Account archived',
            );
          }
      }
    } catch (error) {
      if (mounted) feedback(context, actionError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final account = ledger.account(widget.id);
    if (account == null) {
      return Subpage(
        title: 'Account details',
        child: PageScroll(
          children: const [
            EmptyPanel(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Account unavailable',
              message: 'This account could not be found.',
            ),
          ],
        ),
      );
    }
    final now = ledger.now;
    final activity = ledger.activity(
      DateSpan.month(now),
      accountId: account.id,
    );
    final net =
        activity.income -
        activity.expenses +
        activity.transfersIn -
        activity.transfersOut +
        activity.adjustments;
    final recent = ledger.entries
        .where((entry) => entry.involves(account.id))
        .toList();
    final start = _range == 0
        ? DateUtils.dateOnly(
            recent.isNotEmpty && recent.last.date.isBefore(account.opened)
                ? recent.last.date
                : account.opened,
          )
        : DateTime(now.year, now.month - _range + 1);
    final today = DateUtils.dateOnly(now);
    final calendarDays = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    final samples = max(1, min(48, calendarDays));
    final values = [
      for (var index = 0; index <= samples; index++)
        ledger.balance(
          account,
          before: DateTime(
            start.year,
            start.month,
            start.day + (index * calendarDays / samples).round() + 1,
          ),
        ),
    ];

    return Subpage(
      title: account.name,
      actions: [
        IconButton(
          tooltip: 'Account settings',
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () => _manage(account, ledger),
        ),
      ],
      child: PageScroll(
        children: [
          Surface(
            color: Theme.of(context).colorScheme.primaryContainer,
            radius: 30,
            child: Column(
              children: [
                Glyph(
                  accountSymbol(account.icon),
                  Color(account.colour),
                  size: 48,
                  iconSize: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  'Current balance',
                  style: textStyle(12, color: Palette.secondary),
                ),
                const SizedBox(height: 2),
                MoneyText(
                  ledger.balance(account),
                  size: 36,
                  weight: FontWeight.w900,
                  fit: true,
                  align: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  account.archived
                      ? '${account.type.label} · Archived'
                      : account.type.label,
                  style: textStyle(12, color: Palette.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          if (!account.archived) ...[
            Row(
              children: [
                for (final (index, type) in [
                  EntryType.expense,
                  EntryType.income,
                  EntryType.transfer,
                ].indexed) ...[
                  if (index != 0) const SizedBox(width: 8),
                  Expanded(
                    child: Surface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 11,
                      ),
                      radius: 13,
                      onTap: () => openPage<void>(
                        context,
                        EntryForm(type: type, accountId: account.id),
                        form: true,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            typeIcon(type),
                            size: 20,
                            color: typeColour(type),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            type.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textStyle(12, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 21),
          ],
          const SectionTitle('Account activity'),
          Surface(
            child: Column(
              children: [
                DetailLine(
                  'Income this month',
                  masked(context, activity.income, plus: true),
                  color: Palette.income,
                ),
                DetailLine(
                  'Expenses this month',
                  masked(context, -activity.expenses),
                  color: Palette.expense,
                ),
                DetailLine(
                  'Transfers in',
                  masked(context, activity.transfersIn, plus: true),
                  color: Palette.transfer,
                ),
                DetailLine(
                  'Transfers out',
                  masked(context, -activity.transfersOut),
                  color: Palette.transfer,
                ),
                if (activity.adjustments != 0)
                  DetailLine(
                    'Adjustments',
                    masked(context, activity.adjustments, plus: true),
                    color: Palette.amber,
                  ),
                const Divider(),
                DetailLine(
                  'Net change',
                  masked(context, net, plus: true),
                  color: changeColour(net),
                ),
              ],
            ),
          ),
          const SizedBox(height: 21),
          const SectionTitle('Balance history'),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 5,
                  runSpacing: 2,
                  children: [
                    for (final (label, months) in _ranges)
                      SmallChip(
                        label,
                        selected: _range == months,
                        onTap: () => setState(() => _range = months),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                BalanceChart(values: values, start: start, end: today),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionTitle(
            'Recent transactions',
            action: recent.isEmpty ? null : 'View all',
            onAction: () => openPage<void>(
              context,
              TransactionsView(accountId: account.id),
            ),
          ),
          if (recent.isEmpty)
            const EmptyPanel(
              icon: Icons.receipt_long_outlined,
              title: 'No account activity yet',
              message: 'Transactions involving this account will appear here.',
            )
          else
            TransactionGroup(entries: recent.take(5).toList()),
        ],
      ),
    );
  }
}

class _AdjustmentPage extends StatefulWidget {
  const _AdjustmentPage({required this.id});
  final String id;

  @override
  State<_AdjustmentPage> createState() => _AdjustmentPageState();
}

class _AdjustmentPageState extends State<_AdjustmentPage> {
  final _form = GlobalKey<FormState>();
  final _balance = TextEditingController();
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _balance.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save(Ledger ledger) async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ledger.adjust(
        widget.id,
        parseMoney(_balance.text, signed: true)!,
        _reason.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      feedback(context, 'Balance adjustment recorded');
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = actionError(error);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final current = ledger.account(widget.id);
    final balance = current == null ? 0 : ledger.balance(current);
    final adjusted = parseMoney(_balance.text, signed: true);
    return Subpage(
      title: 'Adjust balance',
      footer: PrimaryFooter(
        title: 'Record adjustment',
        onPressed: () => _save(ledger),
        loading: _saving,
      ),
      child: Form(
        key: _form,
        child: FormScroll(
          children: [
            Surface(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current?.name ?? 'Account',
                    style: textStyle(14, color: Palette.secondary),
                  ),
                  const SizedBox(height: 4),
                  MoneyText(balance, size: 32, fit: true),
                  const SizedBox(height: 4),
                  Text(
                    'Current balance',
                    style: textStyle(12, color: Palette.secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Label('Corrected Balance'),
            TextFormField(
              controller: _balance,
              enabled: !_saving,
              obscureText: ledger.hidden,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                prefixText: '£ ',
                hintText: '0.00',
              ),
              style: textStyle(14, tabular: true),
              validator: (value) =>
                  parseMoney(value ?? '', signed: true) == null
                  ? 'Enter a valid GBP amount'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 15),
            const Label('Reason for Adjustment'),
            TextFormField(
              controller: _reason,
              enabled: !_saving,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Reconciled with my statement',
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Enter a reason for the adjustment'
                  : null,
            ),
            const SizedBox(height: 15),
            Surface(
              child: DetailLine(
                'Adjustment to record',
                adjusted == null
                    ? 'Enter a balance'
                    : masked(context, adjusted - balance, plus: true),
                color: Palette.amber,
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
