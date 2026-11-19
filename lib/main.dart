import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/ledger.dart';
import 'data/storage.dart';
import 'ui/accounts.dart';
import 'ui/analysis.dart';
import 'ui/design.dart';
import 'ui/transactions.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TallyApp(ledger: Ledger(LocalLedgerStorage())));
}

class TallyApp extends StatefulWidget {
  const TallyApp({super.key, required this.ledger});
  final Ledger ledger;

  @override
  State<TallyApp> createState() => _TallyAppState();
}

class _TallyAppState extends State<TallyApp> {
  late Future<void> _loading = widget.ledger.load();

  @override
  void dispose() {
    widget.ledger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LedgerScope(
    ledger: widget.ledger,
    child: MaterialApp(
      title: 'Tally',
      debugShowCheckedModeBanner: false,
      theme: tallyTheme(),
      locale: const Locale('en', 'GB'),
      supportedLocales: const [Locale('en', 'GB')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(alwaysUse24HourFormat: true),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Palette.base,
              systemNavigationBarContrastEnforced: false,
            ),
            child: child!,
          ),
        );
      },
      home: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: EmptyPanel(
                        icon: Icons.error_outline_rounded,
                        title: 'Couldn’t open your ledger',
                        message: 'Your saved data could not be read. Try opening it again.',
                        action: 'Try again',
                        onAction: () => setState(() {
                          _loading = widget.ledger.load();
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Opening ledger',
                ),
              ),
            );
          }
          return const TallyHome();
        },
      ),
    ),
  );
}

class TallyHome extends StatefulWidget {
  const TallyHome({super.key});

  @override
  State<TallyHome> createState() => _TallyHomeState();
}

class _TallyHomeState extends State<TallyHome>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    (label: 'Transactions', icon: Icons.receipt_long_outlined),
    (label: 'Accounts', icon: Icons.account_balance_wallet_outlined),
    (label: 'Analysis', icon: Icons.bar_chart_rounded),
  ];
  int _selected = 0;
  late final _tabFade = _tabAnimation.drive(
    Tween<double>(begin: .86, end: 1).chain(CurveTween(curve: Curves.easeOut)),
  );

  @override
  void dispose() {
    _tabAnimation.dispose();
    super.dispose();
  }

  late final _tabAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    value: 1,
  );

  void _selectTab(int index) {
    if (_selected == index) return;
    FocusScope.of(context).unfocus();
    setState(() => _selected = index);
    if (!MediaQuery.disableAnimationsOf(context)) {
      _tabAnimation.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 590),
          child: FadeTransition(
            opacity: _tabFade,
            child: IndexedStack(
              index: _selected,
              children: [
                ExcludeFocus(
                  excluding: _selected != 0,
                  child: const TransactionsView(),
                ),
                ExcludeFocus(
                  excluding: _selected != 1,
                  child: const AccountsView(),
                ),
                ExcludeFocus(
                  excluding: _selected != 2,
                  child: const AnalysisView(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: Material(
      color: Palette.base,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Palette.line)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 590),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 5, 12, 3),
                child: Row(
                  children: [
                    for (var index = 0; index < _tabs.length; index++)
                      Expanded(
                        child: _TabButton(
                          label: _tabs[index].label,
                          icon: _tabs[index].icon,
                          selected: _selected == index,
                          onTap: () => _selectTab(index),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Palette.mint : Palette.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                width: 52,
                height: 28,
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: selected ? Palette.greenSurface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle(11, color: color, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
