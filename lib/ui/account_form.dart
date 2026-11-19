import 'package:flutter/material.dart';

import '../data/models.dart';
import 'design.dart';

enum AccountField { name, type, colour, icon }

const accountColours = <(String, int)>[
  ('Mint', 0xFF9FE6BC),
  ('Coral', 0xFFF38E90),
  ('Blue', 0xFF91BFFA),
  ('Indigo', 0xFFB2A6F7),
  ('Amber', 0xFFE5B479),
  ('Pink', 0xFFF1A8C0),
];

class AccountForm extends StatefulWidget {
  const AccountForm({super.key, this.existing, this.focus});
  final Account? existing;
  final AccountField? focus;

  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  final _form = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _typeKey = GlobalKey();
  final _colourKey = GlobalKey();
  final _iconKey = GlobalKey();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _opening = TextEditingController(
    text: widget.existing == null
        ? '0.00'
        : moneyInput(widget.existing!.opening),
  );
  late AccountType _type = widget.existing?.type ?? AccountType.current;
  late int _colour = widget.existing?.colour ?? accountColours.first.$2;
  late AccountIcon _icon = widget.existing?.icon ?? AccountIcon.wallet;
  late bool _included = widget.existing?.included ?? true;
  bool _saving = false;
  String? _error;
  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.focus == AccountField.name) _nameFocus.requestFocus();
      final target = switch (widget.focus) {
        AccountField.type => _typeKey.currentContext,
        AccountField.colour => _colourKey.currentContext,
        AccountField.icon => _iconKey.currentContext,
        _ => null,
      };
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: .15,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final ledger = LedgerScope.of(context);
    final existing = widget.existing;
    final account = Account(
      id: existing?.id ?? ledger.newId(),
      name: _name.text.trim(),
      type: _type,
      opening: existing?.opening ?? parseMoney(_opening.text, signed: true)!,
      opened: existing?.opened ?? ledger.now,
      colour: _colour,
      icon: _icon,
      included: _included,
      archived: existing?.archived ?? false,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ledger.putAccount(account);
      if (!mounted) return;
      Navigator.pop(context, account.id);
      feedback(context, _editing ? 'Account updated' : 'Account created');
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
    final existing = widget.existing;
    final balance = existing == null
        ? parseMoney(_opening.text, signed: true) ?? 0
        : ledger.balance(existing);
    return Subpage(
      title: _editing ? 'Edit Account' : 'Add Account',
      footer: PrimaryFooter(
        title: _editing ? 'Save Changes' : 'Create Account',
        loading: _saving,
        onPressed: _save,
      ),
      child: Form(
        key: _form,
        child: FormScroll(
          children: [
            const Label('Account Name'),
            TextFormField(
              controller: _name,
              focusNode: _nameFocus,
              enabled: !_saving,
              style: textStyle(14),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. Monzo'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Enter an account name' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 15),
            SelectField(
              key: _typeKey,
              label: 'Account Type',
              value: _type.label,
              leading: Icon(
                accountSymbol(_icon),
                size: 19,
                color: Color(_colour),
              ),
              onTap: _saving
                  ? null
                  : () async {
                      FocusScope.of(context).unfocus();
                      final chosen = await choose(context, 'Account type', [
                        for (final type in AccountType.values)
                          SheetOption(type, type.label),
                      ], selected: _type);
                      if (mounted && chosen != null) {
                        setState(() => _type = chosen);
                      }
                    },
            ),
            const SizedBox(height: 15),
            if (!_editing) ...[
              const Label('Opening Balance'),
              TextFormField(
                controller: _opening,
                enabled: !_saving,
                obscureText: ledger.hidden,
                style: textStyle(14, tabular: true),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  prefixText: '£ ',
                ),
                validator: (value) =>
                    parseMoney(value ?? '', signed: true) == null
                    ? 'Enter a valid GBP amount'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 15),
            ],
            const Label('Currency'),
            const Surface(
              radius: 12,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.currency_pound_rounded,
                    size: 18,
                    color: Palette.mint,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'British pound (GBP)',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Label('Account Colour', key: _colourKey),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (name, value) in accountColours)
                  Semantics(
                    button: true,
                    selected: _colour == value,
                    label: name,
                    child: Tooltip(
                      message: name,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _saving
                            ? null
                            : () => setState(() => _colour = value),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Palette.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _colour == value
                                  ? Color(value)
                                  : Palette.line,
                            ),
                          ),
                          child: Container(
                            width: 23,
                            height: 23,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Color(value),
                              shape: BoxShape.circle,
                            ),
                            child: _colour == value
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Palette.base,
                                    size: 17,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 15),
            Label('Account Icon', key: _iconKey),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final icon in AccountIcon.values)
                  Semantics(
                    button: true,
                    selected: _icon == icon,
                    child: Tooltip(
                      message: icon.name,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _saving
                            ? null
                            : () => setState(() => _icon = icon),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _icon == icon
                                ? Palette.greenSurface
                                : Palette.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _icon == icon
                                  ? Palette.mint
                                  : Palette.line,
                            ),
                          ),
                          child: Icon(
                            accountSymbol(icon),
                            size: 20,
                            color: _icon == icon
                                ? Palette.mint
                                : Palette.secondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 17),
            Surface(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Include in Total Balance',
                          style: textStyle(14, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Count this account in the Accounts overview.',
                          style: textStyle(11, color: Palette.secondary),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: 'Include in Total Balance',
                    child: Switch(
                      value: _included,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _included = value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionTitle('Account preview'),
            AccountCard(
              account: Account(
                id: '',
                name: _name.text.trim().isEmpty
                    ? 'Account name'
                    : _name.text.trim(),
                type: _type,
                opening: 0,
                opened: ledger.now,
                colour: _colour,
                icon: _icon,
                included: _included,
                archived: existing?.archived ?? false,
              ),
              balance: balance,
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

class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.account,
    required this.balance,
    this.onTap,
    this.trailing,
  });
  final Account account;
  final int balance;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Surface(
    onTap: onTap,
    padding: const EdgeInsets.all(13),
    radius: 16,
    child: Row(
      children: [
        Glyph(
          accountSymbol(account.icon),
          Color(account.colour),
          size: 45,
          iconSize: 22,
        ),
        const SizedBox(width: 11),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle(15, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                account.type.label,
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
              MoneyText(balance, size: 16, fit: true, align: TextAlign.right),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: account.archived ? Palette.muted : Palette.income,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      account.archived ? 'Archived' : 'Active',
                      maxLines: 1,
                      style: textStyle(10, color: Palette.secondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onTap != null || trailing != null) ...[
          const SizedBox(width: 5),
          trailing ??
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: Palette.muted,
              ),
        ],
      ],
    ),
  );
}
