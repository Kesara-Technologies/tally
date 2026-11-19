import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/ledger.dart';
import '../data/models.dart';

abstract final class Palette {
  static const background = Color(0xFF191E26);
  static const base = Color(0xFF101318);
  static const surface = Color(0xFF252C36);
  static const raised = Color(0xFF2B323D);
  static const text = Color(0xFFF4F6FA);
  static const secondary = Color(0xFFA0ACBA);
  static const muted = Color(0xFF929CAB);
  static const mint = Color(0xFF9FE6BC);
  static const income = Color(0xFF70DDA7);
  static const expense = Color(0xFFF38E90);
  static const transfer = Color(0xFF91BFFA);
  static const amber = Color(0xFFE5B479);
  static const line = Color(0xFF3A434F);
  static const greenSurface = Color(0xFF213731);
  static const greenLine = Color(0xFF365047);
  static const purple = Color(0xFFB2A6F7);
  static const pink = Color(0xFFF1A8C0);
}

TextStyle textStyle(
  double size, {
  Color color = Palette.text,
  FontWeight weight = FontWeight.w400,
  double? spacing,
  bool tabular = false,
  double? height,
}) => TextStyle(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: spacing,
  height: height,
  fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
);

ThemeData tallyTheme() {
  final theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Lato',
    scaffoldBackgroundColor: Palette.background,
    colorScheme: const ColorScheme.dark(
      surface: Palette.surface,
      primary: Palette.mint,
      onPrimary: Palette.base,
      secondary: Palette.transfer,
      error: Palette.expense,
      onSurface: Palette.text,
      onSurfaceVariant: Palette.secondary,
      outline: Palette.line,
    ),
    dividerColor: Palette.line,
    splashFactory: InkRipple.splashFactory,
  );
  final rounded = BorderRadius.circular(12);
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: rounded,
    borderSide: BorderSide(color: color),
  );
  return theme.copyWith(
    dividerTheme: const DividerThemeData(color: Palette.line, thickness: 1),
    textTheme: theme.textTheme.apply(
      bodyColor: Palette.text,
      displayColor: Palette.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.surface,
      hintStyle: textStyle(13, color: Palette.muted),
      errorStyle: textStyle(11, color: Palette.expense),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: border(Palette.line),
      enabledBorder: border(Palette.line),
      focusedBorder: border(Palette.mint),
      errorBorder: border(Palette.expense),
      focusedErrorBorder: border(Palette.expense),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.background,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Palette.raised,
      contentTextStyle: TextStyle(color: Palette.text),
      behavior: SnackBarBehavior.floating,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.mint,
        foregroundColor: Palette.base,
        disabledBackgroundColor: Palette.raised,
        disabledForegroundColor: Palette.muted,
        shape: RoundedRectangleBorder(borderRadius: rounded),
        minimumSize: const Size(0, 48),
        textStyle: textStyle(14, weight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.mint,
        side: const BorderSide(color: Palette.line),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: rounded),
        textStyle: textStyle(14, weight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.mint,
        textStyle: textStyle(13, weight: FontWeight.w700),
      ),
    ),
  );
}

class LedgerScope extends InheritedNotifier<Ledger> {
  const LedgerScope({super.key, required Ledger ledger, required super.child})
    : super(notifier: ledger);

  static Ledger of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LedgerScope>()!.notifier!;
}

Future<T?> openPage<T>(
  BuildContext context,
  Widget page, {
  bool form = false,
}) => Navigator.of(context)
    .push<T>(MaterialPageRoute(builder: (_) => page, fullscreenDialog: form));

void feedback(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
}

String actionError(Object error) => error is LedgerException
    ? error.message
    : 'Something went wrong. Try again.';

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = true,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Palette.surface,
          title: Text(title),
          content: Text(
            message,
            style: textStyle(14, color: Palette.secondary, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: Palette.expense)
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}

({IconData icon, Color color}) categoryVisual(
  Category category,
) => switch (category) {
  Category.groceries => (
    icon: Icons.shopping_cart_outlined,
    color: Palette.mint,
  ),
  Category.eatingOut => (icon: Icons.coffee_outlined, color: Palette.amber),
  Category.shopping => (
    icon: Icons.shopping_bag_outlined,
    color: Palette.purple,
  ),
  Category.transport => (icon: Icons.train_outlined, color: Palette.transfer),
  Category.bills => (
    icon: Icons.receipt_long_outlined,
    color: Color(0xFF85C6BA),
  ),
  Category.entertainment => (
    icon: Icons.confirmation_number_outlined,
    color: Palette.pink,
  ),
  Category.subscriptions => (
    icon: Icons.subscriptions_outlined,
    color: Color(0xFFD0A7EF),
  ),
  Category.health => (
    icon: Icons.favorite_border_rounded,
    color: Palette.expense,
  ),
  Category.education => (icon: Icons.school_outlined, color: Color(0xFFADCDE7)),
  Category.household => (icon: Icons.home_outlined, color: Color(0xFFD6CA96)),
  Category.other => (icon: Icons.category_outlined, color: Palette.secondary),
  Category.salary => (icon: Icons.south_west_rounded, color: Palette.income),
  Category.freelance => (
    icon: Icons.laptop_mac_outlined,
    color: Palette.income,
  ),
  Category.business => (
    icon: Icons.work_outline_rounded,
    color: Palette.income,
  ),
  Category.gifts => (icon: Icons.card_giftcard_rounded, color: Palette.income),
  Category.refunds => (icon: Icons.replay_rounded, color: Palette.income),
  Category.interest => (icon: Icons.percent_rounded, color: Palette.income),
  Category.otherIncome => (
    icon: Icons.add_circle_outline_rounded,
    color: Palette.income,
  ),
};

IconData accountSymbol(AccountIcon icon) => switch (icon) {
  AccountIcon.wallet => Icons.account_balance_wallet_outlined,
  AccountIcon.bank => Icons.account_balance_outlined,
  AccountIcon.savings => Icons.savings_outlined,
  AccountIcon.card => Icons.credit_card_rounded,
  AccountIcon.cash => Icons.payments_outlined,
  AccountIcon.investment => Icons.show_chart_rounded,
};

Color typeColour(EntryType type) => switch (type) {
  EntryType.expense => Palette.expense,
  EntryType.income => Palette.income,
  EntryType.transfer => Palette.transfer,
  EntryType.adjustment => Palette.amber,
};

IconData typeIcon(EntryType type) => switch (type) {
  EntryType.expense => Icons.north_east_rounded,
  EntryType.income => Icons.south_west_rounded,
  EntryType.transfer => Icons.swap_horiz_rounded,
  EntryType.adjustment => Icons.tune_rounded,
};

Color changeColour(int value) => value < 0
    ? Palette.expense
    : value > 0
    ? Palette.income
    : Palette.secondary;
Color budgetColour(double fraction) => fraction >= 1
    ? Palette.expense
    : fraction >= .75
    ? Palette.amber
    : Palette.income;

String masked(BuildContext context, int value, {bool plus = false}) =>
    LedgerScope.of(context).hidden ? '£••••.••' : money(value, plus: plus);

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.value, {
    super.key,
    this.size = 14,
    this.color = Palette.text,
    this.plus = false,
    this.weight = FontWeight.w700,
    this.align,
    this.fit = false,
  });
  final int value;
  final double size;
  final Color color;
  final bool plus;
  final FontWeight weight;
  final TextAlign? align;
  final bool fit;

  @override
  Widget build(BuildContext context) {
    final hidden = LedgerScope.of(context).hidden;
    final display = hidden ? '£••••.••' : money(value, plus: plus);
    final text = Text(
      display,
      semanticsLabel: hidden ? 'Amount hidden' : null,
      maxLines: 1,
      textAlign: align,
      style: textStyle(
        size,
        color: color,
        weight: weight,
        tabular: true,
        spacing: size >= 28 ? -1 : -.15,
      ),
    );
    if (!fit) return text;
    final alignment = switch (align) {
      TextAlign.right || TextAlign.end => Alignment.centerRight,
      TextAlign.center => Alignment.center,
      _ => Alignment.centerLeft,
    };
    return FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: text);
  }
}

class Glyph extends StatelessWidget {
  const Glyph(
    this.icon,
    this.color, {
    super.key,
    this.size = 42,
    this.iconSize = 20,
    this.radius = 12,
  });
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(radius),
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: color, size: iconSize),
  );
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Palette.surface,
    this.border = Palette.line,
    this.radius = 17,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color border;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    clipBehavior: Clip.antiAlias,
    shape: null,
    child: Ink(
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: onTap == null,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class MainHeader extends StatelessWidget {
  const MainHeader({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onAdd,
  });
  final String title;
  final String actionLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.stacked_bar_chart_rounded,
                      color: Palette.mint,
                      size: 17,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'TALLY',
                      style: textStyle(
                        10,
                        spacing: 2.4,
                        color: Palette.mint,
                        weight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle(28, weight: FontWeight.w900, spacing: -.7),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: ledger.hidden ? 'Show amounts' : 'Hide amounts',
            color: Palette.secondary,
            iconSize: 20,
            onPressed: () async {
              try {
                await ledger.togglePrivacy();
              } catch (error) {
                if (context.mounted) feedback(context, actionError(error));
              }
            },
            icon: Icon(
              ledger.hidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: actionLabel,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(46),
              backgroundColor: Palette.mint,
              foregroundColor: Palette.base,
            ),
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 24),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: textStyle(17, weight: FontWeight.w700, spacing: -.2),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(left: 10),
              minimumSize: const Size(48, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(action!),
          ),
      ],
    ),
  );
}

class Subpage extends StatelessWidget {
  const Subpage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.footer,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final fixedFooter = footer != null && !keyboardVisible;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(title, style: textStyle(17, weight: FontWeight.w700)),
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        bottom: !fixedFooter,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 590),
            child: Column(
              children: [
                Expanded(child: child),
                if (keyboardVisible && footer != null) footer!,
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: fixedFooter
          ? SafeArea(
              top: false,
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 590),
                  child: footer!,
                ),
              ),
            )
          : null,
    );
  }
}

class PageScroll extends StatelessWidget {
  const PageScroll({
    super.key,
    required this.children,
    this.storageKey,
    this.top = 4,
  });
  final List<Widget> children;
  final PageStorageKey<String>? storageKey;
  final double top;

  @override
  Widget build(BuildContext context) => ListView(
    key: storageKey,
    padding: EdgeInsets.fromLTRB(20, top, 20, 28),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    children: children,
  );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Surface(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        Glyph(icon, Palette.mint, size: 46),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textStyle(16, weight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: textStyle(13, color: Palette.secondary, height: 1.4),
        ),
        if (action != null) ...[
          const SizedBox(height: 14),
          FilledButton(onPressed: onAction, child: Text(action!)),
        ],
      ],
    ),
  );
}

class Label extends StatelessWidget {
  const Label(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: textStyle(13, weight: FontWeight.w700)),
  );
}

class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
    this.error,
    this.trailing = Icons.expand_more_rounded,
  });
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? leading;
  final String? error;
  final IconData trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Label(label),
      Surface(
        onTap: onTap,
        radius: 12,
        border: error == null ? Palette.line : Palette.expense,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 13),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: Text(
                value,
                style: textStyle(
                  14,
                  color: onTap == null ? Palette.muted : Palette.text,
                ),
              ),
            ),
            Icon(trailing, size: 19, color: Palette.secondary),
          ],
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 5),
          child: Text(error!, style: textStyle(11, color: Palette.expense)),
        ),
    ],
  );
}

class SheetOption<T> {
  const SheetOption(
    this.value,
    this.label, {
    this.detail,
    this.icon,
    this.color = Palette.mint,
  });
  final T value;
  final String label;
  final String? detail;
  final IconData? icon;
  final Color color;
}

Future<T?> choose<T>(
  BuildContext context,
  String title,
  List<SheetOption<T>> options, {
  T? selected,
}) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 590),
  builder: (context) => SafeArea(
    top: false,
    child: SizedBox(
      height: (options.length * 56.0 + 64).clamp(
        142.0,
        MediaQuery.sizeOf(context).height * .73,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(title, style: textStyle(19, weight: FontWeight.w900)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemBuilder: (context, index) {
                final option = options[index];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  selected: selected == option.value,
                  selectedColor: Palette.mint,
                  selectedTileColor: Palette.greenSurface,
                  leading: option.icon == null
                      ? null
                      : Glyph(
                          option.icon!,
                          option.color,
                          size: 34,
                          iconSize: 17,
                        ),
                  dense: true,
                  title: Text(
                    option.label,
                    style: textStyle(
                      14,
                      weight: FontWeight.w700,
                      color: selected == option.value
                          ? Palette.mint
                          : Palette.text,
                    ),
                  ),
                  subtitle: option.detail == null
                      ? null
                      : Text(
                          option.detail!,
                          style: textStyle(12, color: Palette.secondary),
                        ),
                  trailing: selected == option.value
                      ? const Icon(Icons.check_rounded, size: 19)
                      : null,
                  onTap: () => Navigator.pop(context, option.value),
                );
              },
            ),
          ),
        ],
      ),
    ),
  ),
);

Future<Category?> chooseCategory(
  BuildContext context, {
  required EntryType type,
  Category? selected,
}) => choose(context, 'Choose category', [
  for (final category in Category.forType(type))
    SheetOption(
      category,
      category.label,
      icon: categoryVisual(category).icon,
      color: categoryVisual(category).color,
    ),
], selected: selected);

class PrimaryFooter extends StatelessWidget {
  const PrimaryFooter({
    super.key,
    required this.title,
    this.onPressed,
    this.loading = false,
  });
  final String title;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox.square(
                dimension: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: 'Saving',
                ),
              )
            : Text(title),
      ),
    ),
  );
}

class ProgressTrack extends StatelessWidget {
  const ProgressTrack(this.fraction, {super.key, this.height = 7});
  final double fraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hidden = LedgerScope.of(context).hidden;
    final progress = fraction.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: hidden
          ? Semantics(
              label: 'Budget progress hidden',
              child: ColoredBox(
                color: Palette.line,
                child: SizedBox(width: double.infinity, height: height),
              ),
            )
          : TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) => LinearProgressIndicator(
                value: value,
                minHeight: height,
                color: budgetColour(fraction),
                backgroundColor: Palette.line,
                semanticsLabel: 'Budget progress',
                semanticsValue: percentage(progress),
              ),
            ),
    );
  }
}

class SmallChip extends StatelessWidget {
  const SmallChip(
    this.label, {
    super.key,
    required this.selected,
    required this.onTap,
    this.horizontalPadding = 14,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? Palette.mint : Palette.surface,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 8,
              ),
              child: Text(
                label,
                style: textStyle(
                  12,
                  weight: FontWeight.w700,
                  color: selected ? Palette.base : Palette.secondary,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class FormScroll extends StatelessWidget {
  const FormScroll({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}
