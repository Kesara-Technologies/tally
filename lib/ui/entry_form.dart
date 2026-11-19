import 'package:flutter/material.dart';

import '../data/ledger.dart';
import '../data/models.dart';
import 'account_form.dart';
import 'design.dart';
import 'transactions.dart' show DetailLine;

class EntryForm extends StatefulWidget {
  const EntryForm({
    super.key,
    this.type = EntryType.expense,
    this.accountId,
    this.existing,
  });
  final EntryType type;
  final String? accountId;
  final Entry? existing;

  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  final _form = GlobalKey<FormState>();
  late EntryType _type = widget.existing?.type ?? widget.type;
  late final TextEditingController _amount = TextEditingController(
    text: widget.existing == null ? '' : moneyInput(widget.existing!.amount),
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.type == EntryType.transfer
        ? ''
        : widget.existing?.name,
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.existing?.notes,
  );
  late final List<_ItemDraft> _items = [
    for (final item in widget.existing?.items ?? const <PurchaseItem>[])
      _ItemDraft(item),
  ];
  final _amountFocus = FocusNode();
  late bool _itemised = _items.isNotEmpty;
  late bool _includeInCashFlow = widget.existing?.includeInCashFlow ?? true;
  late Category? _category = widget.existing?.category;
  String? _account;
  String? _destination;
  DateTime? _date;
  bool _dateChanged = false;
  bool _initialised = false;
  bool _saving = false;
  bool _submitted = false;
  String? _saveError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    final ledger = LedgerScope.of(context);
    _date = widget.existing?.date ?? ledger.now;
    _account =
        widget.existing?.accountId ??
        widget.accountId ??
        ledger.activeAccounts.firstOrNull?.id;
    _destination = widget.existing?.destinationId;
    _initialised = true;
  }

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    _name.dispose();
    _notes.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  bool get _isAdjustment => _type == EntryType.adjustment;
  int? get _value => parseMoney(_amount.text, signed: _isAdjustment);
  int get _subtotal => _itemised && _type == EntryType.expense
      ? _items.fold(0, (total, item) => total + item.lineTotal)
      : 0;

  List<Account> _usableAccounts(Ledger ledger) => ledger.accounts
      .where(
        (account) =>
            !account.archived || widget.existing?.involves(account.id) == true,
      )
      .toList();

  Future<void> _selectAccount(Ledger ledger, {bool destination = false}) async {
    FocusScope.of(context).unfocus();
    final accounts = _usableAccounts(ledger)
        .where((account) => !destination || account.id != _account);
    final selected = await choose(
      context,
      destination ? 'Choose destination' : 'Choose account',
      [
        for (final account in accounts)
          SheetOption(
            account.id,
            account.name,
            detail: account.type.label,
            icon: accountSymbol(account.icon),
            color: Color(account.colour),
          ),
      ],
      selected: destination ? _destination : _account,
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (destination) {
        _destination = selected;
      } else {
        if (selected == _destination) _destination = _account;
        _account = selected;
      }
    });
  }

  Future<void> _createAccount(Ledger ledger) async {
    final created = await openPage<String>(
      context,
      const AccountForm(),
      form: true,
    );
    if (mounted && created != null) {
      setState(() {
        if (_account == null || ledger.account(_account) == null) {
          _account = created;
        } else if (_type == EntryType.transfer) {
          _destination = created;
        }
      });
    }
  }

  void _changeType(EntryType type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _category = null;
      _destination = null;
      _saveError = null;
    });
  }

  Future<void> _selectDate(Ledger ledger) async {
    FocusScope.of(context).unfocus();
    final now = ledger.now;
    final current = _date!;
    final chosen = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDate: current.isAfter(now) ? now : current,
    );
    if (!mounted || chosen == null) return;
    setState(() {
      final resolved = DateTime(
        chosen.year,
        chosen.month,
        chosen.day,
        current.hour,
        current.minute,
      );
      _date = resolved.isAfter(ledger.now) ? ledger.now : resolved;
      _dateChanged = true;
    });
  }

  Future<void> _selectTime() async {
    FocusScope.of(context).unfocus();
    final date = _date!;
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(date),
    );
    if (!mounted || chosen == null) return;
    setState(() {
      _date = DateTime(
        date.year,
        date.month,
        date.day,
        chosen.hour,
        chosen.minute,
      );
      _dateChanged = true;
    });
  }

  Future<void> _save(Ledger ledger) async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _saveError = null;
    });
    final valid = _form.currentState!.validate();
    final value = _value;
    if (!valid ||
        value == null ||
        (_isAdjustment ? value == 0 : value <= 0) ||
        _account == null ||
        ledger.account(_account) == null ||
        (_type == EntryType.transfer &&
            (_destination == null || _destination == _account)) ||
        (_type != EntryType.transfer && !_isAdjustment && _category == null) ||
        _subtotal > value && !_isAdjustment) {
      setState(
        () => _saveError = 'Check the highlighted fields before saving.',
      );
      return;
    }

    final existing = widget.existing;
    final entry = Entry(
      id: existing?.id ?? ledger.newId(),
      type: _type,
      name: _type == EntryType.transfer
          ? 'Account transfer'
          : _isAdjustment
          ? 'Balance adjustment'
          : _name.text.trim(),
      amount: value,
      accountId: _account!,
      destinationId: _type == EntryType.transfer ? _destination : null,
      category: _category,
      date: existing == null && !_dateChanged ? ledger.now : _date!,
      notes: _notes.text.trim(),
      includeInCashFlow: _type != EntryType.income || _includeInCashFlow,
      items: _itemised && _type == EntryType.expense
          ? [
              for (final item in _items)
                if (item.validValue != null) item.validValue!,
            ]
          : const [],
    );
    setState(() => _saving = true);
    try {
      await ledger.putEntry(entry);
      if (!mounted) return;
      Navigator.pop(context);
      feedback(
        context,
        existing != null
            ? 'Transaction updated'
            : switch (_type) {
                EntryType.expense => 'Expense added',
                EntryType.income => 'Income added',
                EntryType.transfer => 'Transfer completed',
                EntryType.adjustment => 'Adjustment saved',
              },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = actionError(error);
      });
    }
  }

  Widget _fieldGap() => const SizedBox(height: 15);

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final color = typeColour(_type);
    final colors = Theme.of(context).colorScheme;
    final editing = widget.existing != null;
    final amountStyle = textStyle(
      35,
      color: color,
      weight: FontWeight.w900,
      spacing: -1,
      tabular: true,
    );
    final display = _amount.text.isEmpty ? '0.00' : _amount.text;
    final measured = TextPainter(
      text: TextSpan(
        text: ledger.hidden && _amount.text.isNotEmpty
            ? '•' * display.length
            : display,
        style: amountStyle.copyWith(
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final amountWidth = (measured.width + 8).clamp(68.0, 250.0);
    measured.dispose();
    final account = ledger.account(_account);
    final destination = ledger.account(_destination);
    final value = _value ?? 0;
    final amountError = !_submitted
        ? null
        : _isAdjustment && value == 0
        ? 'Enter a non-zero amount'
        : !_isAdjustment && value <= 0
        ? 'Enter an amount above zero'
        : null;
    final itemOverflow = _subtotal > value && !_isAdjustment;
    final available = _usableAccounts(ledger);
    final canChooseSource = available.isNotEmpty;
    final canChooseDestination = available.any((item) => item.id != _account);
    final visual = _category == null ? null : categoryVisual(_category!);

    return Subpage(
      title: editing ? 'Edit Transaction' : 'Add Transaction',
      footer: PrimaryFooter(
        title: editing ? 'Save Changes' : 'Save ${_type.label}',
        loading: _saving,
        onPressed: () => _save(ledger),
      ),
      child: Form(
        key: _form,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: FormScroll(
          children: [
            Surface(
              color: Color.alphaBlend(
                color.withValues(alpha: .13),
                colors.surfaceContainer,
              ),
              border: amountError == null ? null : Palette.expense,
              radius: 30,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                children: [
                  Text(
                    _isAdjustment ? 'Adjustment amount' : 'Amount',
                    style: textStyle(
                      12,
                      color: Palette.secondary,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isAdjustment
                            ? '£'
                            : switch (_type) {
                                EntryType.expense => '−£',
                                EntryType.income => '+£',
                                _ => '£',
                              },
                        style: textStyle(
                          35,
                          color: color,
                          weight: FontWeight.w900,
                          spacing: -1,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: SizedBox(
                          width: amountWidth,
                          child: TextFormField(
                            controller: _amount,
                            focusNode: _amountFocus,
                            enabled: !_saving,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                              signed: _isAdjustment,
                            ),
                            textInputAction: TextInputAction.next,
                            obscureText: ledger.hidden,
                            style: amountStyle,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              hintText: '0.00',
                              hintStyle: textStyle(
                                35,
                                color: color.withValues(alpha: .63),
                                weight: FontWeight.w900,
                                spacing: -1,
                                tabular: true,
                              ),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: colors.primary),
                              ),
                              focusedErrorBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Palette.expense),
                              ),
                              errorBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Palette.expense),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    amountError ?? 'British pounds (GBP)',
                    style: textStyle(
                      11,
                      color: amountError == null
                          ? Palette.secondary
                          : Palette.expense,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isAdjustment) ...[
              const SizedBox(height: 14),
              _EntryTypeSelector(
                type: _type,
                onChanged: _saving ? null : _changeType,
              ),
            ],
            const SizedBox(height: 20),
            if (_type != EntryType.transfer && !_isAdjustment) ...[
              Label(
                _type == EntryType.expense
                    ? 'Merchant / Description'
                    : 'Source / Description',
              ),
              TextFormField(
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style: textStyle(14),
                decoration: InputDecoration(
                  hintText: _type == EntryType.expense
                      ? 'e.g. Tesco'
                      : 'e.g. Salary',
                ),
                validator: (input) =>
                    (input ?? '').trim().isEmpty ? 'Enter a description' : null,
              ),
              _fieldGap(),
              SelectField(
                label: 'Category',
                value: _category?.label ?? 'Choose category',
                leading: visual == null
                    ? const Icon(
                        Icons.category_outlined,
                        size: 19,
                        color: Palette.secondary,
                      )
                    : Icon(visual.icon, size: 19, color: visual.color),
                error: _submitted && _category == null
                    ? 'Choose a category'
                    : null,
                onTap: _saving
                    ? null
                    : () async {
                        FocusScope.of(context).unfocus();
                        final chosen = await chooseCategory(
                          context,
                          type: _type,
                          selected: _category,
                        );
                        if (mounted && chosen != null) {
                          setState(() => _category = chosen);
                        }
                      },
              ),
              _fieldGap(),
            ],
            SelectField(
              label: _type == EntryType.transfer
                  ? 'From account'
                  : _type == EntryType.income
                  ? 'Receiving account'
                  : 'Account',
              value: account?.name ?? 'Choose account',
              leading: _AccountFieldIcon(account),
              error: _submitted && account == null ? 'Choose an account' : null,
              onTap: _saving || _isAdjustment || !canChooseSource
                  ? null
                  : () => _selectAccount(ledger),
            ),
            if (_type == EntryType.transfer) ...[
              _fieldGap(),
              SelectField(
                label: 'To account',
                value: destination?.name ?? 'Choose destination',
                leading: _AccountFieldIcon(destination),
                error: _submitted && destination == null
                    ? 'Choose a destination account'
                    : null,
                onTap: _saving || !canChooseDestination
                    ? null
                    : () => _selectAccount(ledger, destination: true),
              ),
            ],
            if (!_isAdjustment &&
                (available.isEmpty ||
                    (_type == EntryType.transfer && available.length < 2))) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : () => _createAccount(ledger),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add an account'),
                ),
              ),
              if (_type == EntryType.transfer)
                Text(
                  'Transfers need two different accounts.',
                  style: textStyle(12, color: Palette.secondary),
                ),
            ],
            if (_type == EntryType.income) ...[
              _fieldGap(),
              Surface(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  title: Text(
                    'Include in net cash flow',
                    style: textStyle(14, weight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _includeInCashFlow
                        ? 'Counts toward the monthly cash-flow summary.'
                        : 'Still added to the receiving account.',
                    style: textStyle(12, color: Palette.secondary),
                  ),
                  value: _includeInCashFlow,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _includeInCashFlow = value),
                ),
              ),
            ],
            if (!_isAdjustment) ...[
              _fieldGap(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: SelectField(
                      label: 'Date',
                      value: fullDate(_date!),
                      trailing: Icons.calendar_today_outlined,
                      onTap: _saving ? null : () => _selectDate(ledger),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    flex: 2,
                    child: SelectField(
                      label: 'Time',
                      value: timeLabel(_date!),
                      trailing: Icons.schedule_rounded,
                      onTap: _saving ? null : _selectTime,
                    ),
                  ),
                ],
              ),
            ],
            _fieldGap(),
            Label(_isAdjustment ? 'Reason' : 'Notes (optional)'),
            TextFormField(
              controller: _notes,
              enabled: !_saving,
              minLines: 2,
              maxLines: 4,
              style: textStyle(14),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _isAdjustment
                    ? 'Why was the balance adjusted?'
                    : 'Add a note',
              ),
              validator: (input) =>
                  _isAdjustment && (input ?? '').trim().isEmpty
                  ? 'Enter a reason'
                  : null,
            ),
            if (_type == EntryType.expense) ...[
              const SizedBox(height: 16),
              Surface(
                padding: const EdgeInsets.fromLTRB(13, 5, 13, 5),
                child: Row(
                  children: [
                    Glyph(
                      Icons.list_alt_outlined,
                      colors.primary,
                      size: 35,
                      iconSize: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Itemised Expenses',
                            style: textStyle(14, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Break down your purchase',
                            style: textStyle(11, color: Palette.secondary),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      label: 'Itemised Expenses',
                      child: Switch(
                        value: _itemised,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _itemised = value),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                alignment: Alignment.topCenter,
                child: !_itemised
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_items.isEmpty)
                              EmptyPanel(
                                icon: Icons.list_alt_outlined,
                                title: 'No items added',
                                message: 'Add individual items to see exactly where your money goes.',
                                action: 'Add Item',
                                onAction: _saving
                                    ? null
                                    : () => setState(
                                        () => _items.add(_ItemDraft()),
                                      ),
                              ),
                            for (final item in _items)
                              Padding(
                                key: ObjectKey(item),
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _ItemEditor(
                                  item: item,
                                  index: _items.indexOf(item) + 1,
                                  enabled: !_saving,
                                  parent: _category,
                                  onChange: () => setState(() {}),
                                  onRemove: () {
                                    setState(() => _items.remove(item));
                                    WidgetsBinding.instance
                                        .addPostFrameCallback(
                                          (_) => item.dispose(),
                                        );
                                  },
                                ),
                              ),
                            if (_items.isNotEmpty) ...[
                              OutlinedButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => setState(
                                        () => _items.add(_ItemDraft()),
                                      ),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add another item'),
                              ),
                              const SizedBox(height: 8),
                              Surface(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 8,
                                ),
                                border: itemOverflow
                                    ? Palette.expense
                                    : colors.outlineVariant,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DetailLine(
                                      'Items subtotal',
                                      masked(context, _subtotal),
                                    ),
                                    DetailLine(
                                      'Unitemised amount',
                                      masked(context, value - _subtotal),
                                      color: itemOverflow
                                          ? Palette.expense
                                          : Palette.text,
                                    ),
                                    if (itemOverflow)
                                      Text(
                                        'Item subtotal cannot exceed the transaction amount.',
                                        style: textStyle(
                                          11,
                                          color: Palette.expense,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
            const SizedBox(height: 16),
            Surface(
              color: colors.primaryContainer,
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(typeIcon(_type), size: 18, color: color),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Balance impact',
                          style: textStyle(12, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _impact(context, value, account, destination),
                          style: textStyle(
                            12,
                            color: Palette.secondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(
                  _saveError!,
                  style: textStyle(12, color: Palette.expense),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _impact(
    BuildContext context,
    int value,
    Account? account,
    Account? destination,
  ) {
    if (account == null ||
        (value == 0 && _isAdjustment) ||
        (value <= 0 && !_isAdjustment)) {
      return 'Enter an amount and choose an account to see the effect.';
    }
    final amount = masked(context, value.abs());
    return switch (_type) {
      EntryType.expense => '$amount will be deducted from ${account.name}.',
      EntryType.income => '$amount will be added to ${account.name}.',
      EntryType.transfer =>
        destination == null
            ? 'Choose a destination account.'
            : '$amount will move from ${account.name} to ${destination.name}. Spending totals stay the same.',
      EntryType.adjustment =>
        '$amount will be ${value < 0 ? 'deducted from' : 'added to'} ${account.name} as a balance adjustment.',
    };
  }
}

class _EntryTypeSelector extends StatelessWidget {
  const _EntryTypeSelector({required this.type, required this.onChanged});
  final EntryType type;
  final ValueChanged<EntryType>? onChanged;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 230);
    return Surface(
      radius: 24,
      padding: const EdgeInsets.all(5),
      child: Row(
        spacing: 4,
        children: [
          for (final candidate in [
            EntryType.expense,
            EntryType.income,
            EntryType.transfer,
          ])
            Expanded(child: _option(context, candidate, duration)),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, EntryType candidate, Duration duration) {
    final colors = Theme.of(context).colorScheme;
    final selected = candidate == type;
    final tone = typeColour(candidate);
    final color = selected ? tone : Palette.secondary;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(selected ? 22 : 12),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? Color.alphaBlend(
                tone.withValues(alpha: .13),
                colors.surfaceContainerHigh,
              )
            : colors.surfaceContainer,
        shape: shape,
        animationDuration: duration,
        child: InkWell(
          customBorder: shape,
          onTap: onChanged == null ? null : () => onChanged!(candidate),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(typeIcon(candidate), size: 15, color: color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      candidate.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle(
                        13,
                        color: color,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountFieldIcon extends StatelessWidget {
  const _AccountFieldIcon(this.account);
  final Account? account;
  @override
  Widget build(BuildContext context) => Icon(
    account == null
        ? Icons.account_balance_wallet_outlined
        : accountSymbol(account!.icon),
    size: 19,
    color: account == null ? Palette.secondary : Color(account!.colour),
  );
}

class _ItemDraft {
  _ItemDraft([PurchaseItem? item])
    : name = TextEditingController(text: item?.name),
      price = TextEditingController(
        text: item == null ? '' : moneyInput(item.unitPrice),
      ),
      count = TextEditingController(text: (item?.quantity ?? 1).toString()),
      category = item?.category;

  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController count;
  Category? category;

  int? get unitPrice => parseMoney(price.text);
  int? get quantity => int.tryParse(count.text);
  bool get validPrice => (unitPrice ?? 0) > 0;
  bool get validQuantity => (quantity ?? 0) > 0 && quantity! <= 9999;
  int get lineTotal => validPrice && validQuantity ? unitPrice! * quantity! : 0;
  PurchaseItem? get validValue =>
      name.text.trim().isEmpty || !validPrice || !validQuantity
      ? null
      : PurchaseItem(name.text.trim(), unitPrice!, quantity!, category);

  void dispose() {
    name.dispose();
    price.dispose();
    count.dispose();
  }
}

class _ItemEditor extends StatelessWidget {
  const _ItemEditor({
    required this.item,
    required this.index,
    required this.enabled,
    required this.parent,
    required this.onChange,
    required this.onRemove,
  });
  final _ItemDraft item;
  final int index;
  final bool enabled;
  final Category? parent;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final category = item.category ?? parent;
    return Surface(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Item $index',
                  style: textStyle(13, weight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Remove item $index',
                onPressed: enabled ? onRemove : null,
                icon: const Icon(
                  Icons.remove_circle_outline_rounded,
                  color: Palette.expense,
                  size: 20,
                ),
              ),
            ],
          ),
          TextFormField(
            controller: item.name,
            enabled: enabled,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            style: textStyle(13),
            decoration: const InputDecoration(hintText: 'Item name'),
            onChanged: (_) => onChange(),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Enter an item name' : null,
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: item.price,
                  enabled: enabled,
                  obscureText: LedgerScope.of(context).hidden,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  style: textStyle(13, tabular: true),
                  decoration: const InputDecoration(
                    labelText: 'Unit price',
                    prefixText: '£',
                  ),
                  validator: (_) =>
                      item.validPrice ? null : 'Enter a valid price',
                  onChanged: (_) => onChange(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: item.count,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  style: textStyle(13, tabular: true),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  validator: (_) => item.validQuantity ? null : 'Enter 1–9,999',
                  onChanged: (_) => onChange(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(right: 6),
                  ),
                  icon: Icon(
                    category == null
                        ? Icons.category_outlined
                        : categoryVisual(category).icon,
                    size: 16,
                  ),
                  label: Text(
                    item.category != null
                        ? item.category!.label
                        : category == null
                        ? 'Inherit category'
                        : 'Inherit ${category.label}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: !enabled
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          final result = await choose(
                            context,
                            'Item category',
                            [
                              SheetOption(
                                '',
                                'Inherit transaction category',
                                detail: parent?.label,
                              ),
                              for (final category in Category.forType(
                                EntryType.expense,
                              ))
                                SheetOption(
                                  category.name,
                                  category.label,
                                  icon: categoryVisual(category).icon,
                                  color: categoryVisual(category).color,
                                ),
                            ],
                            selected: item.category?.name ?? '',
                          );
                          if (context.mounted && result != null) {
                            item.category = result.isEmpty
                                ? null
                                : Category.values.byName(result);
                            onChange();
                          }
                        },
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Line total',
                    style: textStyle(10, color: Palette.secondary),
                  ),
                  MoneyText(item.lineTotal, size: 13),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
