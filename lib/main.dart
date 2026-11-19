import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
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

class _TallyAppState extends State<TallyApp> with WidgetsBindingObserver {
  static const _systemColours = MethodChannel('tally/system-colours');
  late Future<void> _loading = widget.ledger.load();
  Color? _systemAccent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshSystemColours();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshSystemColours();
  }

  Future<void> _refreshSystemColours() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final argb = await _systemColours.invokeMethod<int>('getAccent');
      final accent = argb == null ? null : Color(argb);
      if (mounted && accent != _systemAccent) {
        setState(() => _systemAccent = accent);
      }
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.ledger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LedgerScope(
    ledger: widget.ledger,
    child: MaterialApp(
      title: 'Tally',
      debugShowCheckedModeBanner: false,
      theme: tallyTheme(seedColor: _systemAccent),
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
              systemNavigationBarColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerLowest,
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
  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long_rounded),
      label: 'Transactions',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet_rounded),
      label: 'Accounts',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_rounded),
      label: 'Analysis',
    ),
  ];
  static const _tabSpring = SpringDescription(
    mass: 1,
    stiffness: 440,
    damping: 36,
  );

  int _selected = 0;
  late final _tabAnimation = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  @override
  void dispose() {
    _tabAnimation.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_selected == index) return;
    FocusScope.of(context).unfocus();
    setState(() => _selected = index);
    if (MediaQuery.disableAnimationsOf(context)) {
      _tabAnimation.value = 1;
    } else {
      _tabAnimation.value = 0;
      _tabAnimation.animateWith(SpringSimulation(_tabSpring, 0, 1, 0));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 590),
          child: AnimatedBuilder(
            animation: _tabAnimation,
            builder: (context, child) {
              final progress = _tabAnimation.value;
              return Transform.translate(
                offset: Offset(0, (1 - progress) * 8),
                child: Opacity(
                  opacity: (.82 + progress * .18).clamp(0, 1),
                  child: child,
                ),
              );
            },
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
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 590),
          child: NavigationBar(
            selectedIndex: _selected,
            onDestinationSelected: _selectTab,
            animationDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            destinations: _destinations,
          ),
        ),
      ),
    ),
  );
}
