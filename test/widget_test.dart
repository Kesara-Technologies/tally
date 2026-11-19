import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:budget_app/data/ledger.dart';
import 'package:budget_app/data/ledger_snapshot.dart';
import 'package:budget_app/data/legacy_demo.dart';
import 'package:budget_app/data/models.dart';
import 'package:budget_app/data/storage.dart';
import 'package:budget_app/main.dart';
import 'package:budget_app/ui/budgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStorage implements LedgerStorage {
  String? data;
  bool failWrites = false;
  Future<void>? writeDelay;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String data) async {
    final delay = writeDelay;
    if (delay != null) await delay;
    if (failWrites) throw StateError('Storage unavailable');
    this.data = data;
  }
}

class BackupPicker extends FilePickerPlatform {
  Uint8List? saved;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    expect(fileName, endsWith('.json'));
    expect(mimeType, 'application/json');
    saved = bytes;
    return Uri.file('/backup/$fileName');
  }

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => saved == null ? null : BackupFile(saved!);
}

final class BackupFile extends PlatformFile {
  BackupFile(this.bytes);

  final Uint8List bytes;

  @override
  String get name => 'tally-backup.json';

  @override
  Uri get uri => Uri.file('/backup/$name');

  @override
  Never get xFile => throw UnsupportedError('Use readAsBytes');

  @override
  int lengthSync() => bytes.length;

  @override
  Future<int> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

final testNow = DateTime(2026, 11, 18, 15, 42);

MemoryStorage populatedStorage({
  DateTime? date,
  bool legacyDemo = false,
  bool changed = false,
}) {
  final original = demoLedger(date ?? testNow);
  final accounts = [...original.accounts];
  if (changed) accounts[0] = accounts.first.withStatus(archived: true);
  return MemoryStorage()
    ..data = jsonEncode({
      'version': 1,
      'accounts': accounts,
      'entries': original.entries,
      'budgets': original.budgets,
      'hidden': false,
      if (legacyDemo) 'demo': true,
    });
}

Future<void> launch(
  WidgetTester tester,
  Ledger ledger, {
  double width = 390,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(TallyApp(ledger: ledger));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('three linked tabs support item search and persistent privacy', (
    tester,
  ) async {
    final storage = populatedStorage();
    await launch(tester, Ledger(storage, clock: () => testNow));
    expect(find.text('−£482.65'), findsOneWidget);
    expect(find.text('£2,932.65'), findsOneWidget);

    final search = find.widgetWithText(TextField, 'Search transactions...');
    await tester.enterText(search, 'washing-up liquid');
    await tester.pumpAndSettle();
    expect(find.text('Tesco'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);
    await tap(tester, find.text('Tesco'));
    expect(find.text('Transaction details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Washing-up liquid'), 150);
    expect(find.text('Washing-up liquid'), findsOneWidget);
    await tap(tester, find.byTooltip('Back'));
    await tap(tester, find.byTooltip('Clear search'));

    await tap(tester, find.text('Accounts'));
    expect(find.text('£5,763.20'), findsOneWidget);
    await tap(tester, find.text('Monzo'));
    expect(find.text('£463.20'), findsOneWidget);
    await tap(tester, find.byTooltip('Back'));

    await tap(tester, find.text('Analysis'));
    expect(find.text('Monthly spending'), findsOneWidget);
    expect(find.text('£2,932.65'), findsWidgets);
    await tap(tester, find.byTooltip('Previous month'));
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('£1,420.00'), findsWidgets);
    await tap(tester, find.byTooltip('Hide amounts'));
    expect(find.text('£1,420.00'), findsNothing);
    expect(find.text('£••••.••'), findsWidgets);

    final restored = Ledger(storage, clock: () => testNow);
    await restored.load();
    expect(restored.hidden, isTrue);
    restored.dispose();
  });

  testWidgets(
    'a narrow-screen itemised expense can be saved, edited and deleted',
    (tester) async {
      final ledger = Ledger(populatedStorage(), clock: () => testNow);
      await launch(tester, ledger, width: 320);
      final oldBalance = ledger.balance(ledger.account('monzo')!);
      await tap(tester, find.byTooltip('Add transaction'));
      expect(find.text('Add Transaction'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, '0.00'),
        '12.34',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. Tesco'),
        'Corner shop',
      );
      await tap(tester, find.text('Choose category'));
      await tap(tester, find.text('Groceries'));
      await tap(tester, find.byType(Switch));
      await tap(tester, find.text('Add Item'));
      final itemName = find.widgetWithText(TextFormField, 'Item name');
      await tester.ensureVisible(itemName);
      await tester.enterText(itemName, 'Dish soap');
      final price = find.widgetWithText(TextFormField, 'Unit price');
      await tester.ensureVisible(price);
      await tester.enterText(price, '2.34');
      await tap(tester, find.text('Inherit Groceries'));
      await tester.scrollUntilVisible(
        find.text('Household'),
        100,
        scrollable: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        ),
      );
      await tap(tester, find.text('Household'));
      await tap(tester, find.text('Save Expense'));

      expect(ledger.balance(ledger.account('monzo')!), oldBalance - 1234);
      expect(
        ledger.entries.where((entry) => entry.name == 'Corner shop'),
        hasLength(1),
      );
      final entry = ledger.entries.firstWhere(
        (entry) => entry.name == 'Corner shop',
      );
      expect(entry.allocations, {
        Category.household: 234,
        Category.groceries: 1000,
      });
      await tap(tester, find.text('Corner shop'));
      await tester.scrollUntilVisible(find.text('Edit Transaction'), 200);
      await tap(tester, find.text('Edit Transaction'));
      await tester.enterText(
        find.widgetWithText(TextFormField, '12.34'),
        '14.34',
      );
      await tap(tester, find.text('Save Changes'));
      expect(ledger.balance(ledger.account('monzo')!), oldBalance - 1434);
      expect(ledger.entry(entry.id)!.allocations[Category.groceries], 1200);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await tester.scrollUntilVisible(find.text('Delete Transaction'), 200);
      await tap(tester, find.text('Delete Transaction'));
      await tap(tester, find.text('Delete transaction'));
      expect(ledger.balance(ledger.account('monzo')!), oldBalance);
      expect(find.text('Corner shop'), findsNothing);
    },
  );

  testWidgets('a new installation starts empty and can create an account', (
    tester,
  ) async {
    final ledger = Ledger(MemoryStorage(), clock: () => testNow);
    await launch(tester, ledger);
    expect(find.text('No transactions yet'), findsOneWidget);
    expect(find.text('DEMO'), findsNothing);
    await tap(tester, find.text('Accounts'));
    expect(find.text('No accounts added'), findsOneWidget);
    await tap(tester, find.text('Add Account'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g. Monzo'),
      'Holiday cash',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '0.00'),
      '250.50',
    );
    await tap(tester, find.text('Create Account'));
    expect(ledger.accounts.single.name, 'Holiday cash');
    expect(ledger.totalBalance, 25050);
    await tap(tester, find.text('Analysis'));
    expect(find.text('No spending data yet'), findsOneWidget);
  });

  testWidgets('budget goals support creation, period changes and deletion', (
    tester,
  ) async {
    final ledger = Ledger(populatedStorage(), clock: () => testNow);
    await launch(tester, ledger);
    await tap(tester, find.text('Analysis'));
    await tap(tester, find.byTooltip('Create budget goal'));
    await tester.enterText(find.widgetWithText(TextFormField, '300.00'), '275');
    await tap(tester, find.text('Monthly'));
    await tap(tester, find.text('Weekly'));
    await tap(tester, find.text('Create Goal'));
    final created = ledger.budgets.singleWhere(
      (budget) => budget.period == BudgetPeriod.weekly,
    );
    expect(created.limit, 27500);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.scrollUntilVisible(find.text('See all'), 220);
    await tap(tester, find.text('See all'));
    await tap(
      tester,
      find.ancestor(of: find.text('Weekly'), matching: find.byType(BudgetCard)),
    );
    await tap(tester, find.text('Edit Budget'));
    await tap(tester, find.text('Weekly'));
    await tap(tester, find.text('Yearly'));
    await tap(tester, find.text('Save Changes'));
    expect(ledger.budget(created.id)?.period, BudgetPeriod.yearly);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tap(tester, find.text('Delete Budget'));
    await tap(tester, find.text('Delete budget'));
    expect(ledger.budget(created.id), isNull);
  });

  test('transfer, item reallocation, edits, adjustments and deletion share one ledger', () async {
    final storage = populatedStorage();
    final ledger = Ledger(storage, clock: () => testNow);
    await ledger.load();
    final month = DateSpan.month(testNow);
    final wealth = ledger.totalBalance;
    final expenses = ledger.spending(month);
    final grocery = ledger.spending(month, category: Category.groceries);
    final household = ledger.spending(month, category: Category.household);
    final monzo = ledger.account('monzo')!;
    final monzoBalance = ledger.balance(monzo);
    final barclays = ledger.account('barclays')!;
    final bankBalance = ledger.balance(barclays);
    final income = ledger.activity(month).income;

    final transfer = Entry(
      id: 'transfer-test',
      type: EntryType.transfer,
      name: 'Transfer',
      amount: 20000,
      accountId: monzo.id,
      destinationId: barclays.id,
      date: testNow,
    );
    await ledger.putEntry(transfer);
    expect(ledger.balance(monzo), monzoBalance - 20000);
    expect(ledger.balance(barclays), bankBalance + 20000);
    expect(ledger.totalBalance, wealth);
    expect(ledger.spending(month), expenses);
    expect(ledger.activity(month).income, income);
    expect(
      ledger.entries.where((entry) => entry.id == transfer.id),
      hasLength(1),
    );
    expect(ledger.activity(month, accountId: monzo.id).transfersOut, 20000);

    Entry expense(int amount) => Entry(
      id: 'expense-test',
      type: EntryType.expense,
      name: 'Market',
      amount: amount,
      accountId: monzo.id,
      date: testNow,
      category: Category.groceries,
      items: const [
        PurchaseItem('Cleaner', 300, 2, Category.household),
        PurchaseItem('Milk', 150, 1),
      ],
    );
    await ledger.putEntry(expense(1200));
    expect(ledger.spending(month, category: Category.groceries), grocery + 600);
    expect(
      ledger.spending(month, category: Category.household),
      household + 600,
    );
    expect(
      ledger.breakdown(month).values.fold(0, (sum, amount) => sum + amount),
      expenses + 1200,
    );
    expect(ledger.balance(monzo), monzoBalance - 21200);
    await expectLater(
      ledger.putEntry(expense(400)),
      throwsA(isA<LedgerException>()),
    );
    expect(ledger.balance(monzo), monzoBalance - 21200);

    await ledger.putEntry(expense(1000));
    expect(ledger.spending(month, category: Category.groceries), grocery + 400);
    expect(
      ledger.spending(month, category: Category.household),
      household + 600,
    );
    final goal = ledger.preferredBudget(Category.household);
    expect(goal, isNull);
    await ledger.putBudget(
      const Budget('cleaning', 7000, BudgetPeriod.weekly, Category.household),
    );
    final weekly = ledger.budget('cleaning')!;
    expect(ledger.budgetUsage(weekly, testNow), 890);
    await ledger.deleteEntry('expense-test');
    await ledger.deleteEntry('transfer-test');
    expect(ledger.balance(monzo), monzoBalance);
    expect(ledger.spending(month), expenses);

    await ledger.adjust(monzo.id, monzoBalance + 275, 'Statement corrected');
    expect(ledger.balance(monzo), monzoBalance + 275);
    expect(
      ledger.entries
          .firstWhere((entry) => entry.type == EntryType.adjustment)
          .notes,
      'Statement corrected',
    );
    expect(ledger.activity(month).income, income);
    expect(ledger.spending(month), expenses);
    await ledger.setArchived(monzo.id, true);
    expect(ledger.account(monzo.id)!.archived, isTrue);
    expect(ledger.entries.any((entry) => entry.involves(monzo.id)), isTrue);
    final reopened = Ledger(storage, clock: () => testNow);
    await reopened.load();
    expect(reopened.balance(reopened.account(monzo.id)!), monzoBalance + 275);
    expect(reopened.budget('cleaning')?.period, BudgetPeriod.weekly);
    reopened.dispose();
    ledger.dispose();
  });

  test(
    'a failed write leaves state intact and the next write can succeed',
    () async {
      final storage = populatedStorage();
      final ledger = Ledger(storage, clock: () => testNow);
      await ledger.load();
      final balance = ledger.totalBalance;
      storage.failWrites = true;
      await expectLater(
        ledger.togglePrivacy(),
        throwsA(isA<LedgerException>()),
      );
      expect(ledger.hidden, isFalse);
      expect(ledger.totalBalance, balance);
      storage.failWrites = false;
      await ledger.togglePrivacy();
      expect(ledger.hidden, isTrue);
      ledger.dispose();
    },
  );

  testWidgets('archived accounts follow all active accounts', (tester) async {
    final ledger = Ledger(populatedStorage(), clock: () => testNow);
    await launch(tester, ledger);
    await tap(tester, find.text('Accounts'));

    final monzo = find.text('Monzo');
    final savings = find.text('Savings');
    expect(
      tester.getTopLeft(monzo).dy,
      lessThan(tester.getTopLeft(savings).dy),
    );

    await ledger.setArchived('monzo', true);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(monzo).dy,
      greaterThan(tester.getTopLeft(savings).dy),
    );

    await ledger.setArchived('monzo', false);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(monzo).dy,
      lessThan(tester.getTopLeft(savings).dy),
    );
  });

  testWidgets(
    'dropped accounts stay in their new position while their order saves',
    (tester) async {
      final storage = populatedStorage();
      final ledger = Ledger(storage, clock: () => testNow);
      await launch(tester, ledger);
      await ledger.setArchived('barclays', true);
      await tester.pumpAndSettle();

      await tap(tester, find.text('Accounts'));
      await tap(tester, find.text('Manage'));
      final savings = find.byTooltip('Drag to reorder Savings');
      final monzo = find.byTooltip('Drag to reorder Monzo');
      final save = Completer<void>();
      storage.writeDelay = save.future;
      final drag = await tester.startGesture(tester.getCenter(savings));
      await drag.moveBy(const Offset(0, -24));
      await tester.pump(const Duration(milliseconds: 250));
      await drag.moveTo(tester.getCenter(monzo) + const Offset(0, 12));
      await tester.pump(const Duration(milliseconds: 250));
      await drag.up();
      await tester.pumpAndSettle();

      expect(ledger.activeAccounts.map((account) => account.id), [
        'monzo',
        'savings',
      ]);
      expect(
        tester.getTopLeft(savings).dy,
        lessThan(tester.getTopLeft(monzo).dy),
      );
      save.complete();
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(savings).dy,
        lessThan(tester.getTopLeft(monzo).dy),
      );

      await tap(tester, find.byTooltip('Back'));
      final labels = ['Savings', 'Monzo', 'Barclays'];
      final positions = labels
          .map((name) => tester.getTopLeft(find.text(name)).dy)
          .toList();
      expect(positions, orderedEquals([...positions]..sort()));

      final reopened = Ledger(storage, clock: () => testNow);
      await reopened.load();
      expect(reopened.activeAccounts.map((account) => account.id), [
        'savings',
        'monzo',
      ]);
      expect(reopened.account('barclays')?.archived, isTrue);
      reopened.dispose();
    },
  );

  test('an untouched legacy demo is cleared on upgrade', () async {
    final storage = populatedStorage(
      date: DateTime(2026, 11, 1, 8, 15),
      legacyDemo: true,
    );
    final ledger = Ledger(storage, clock: () => testNow);
    await ledger.load();

    expect(ledger.accounts, isEmpty);
    expect(ledger.entries, isEmpty);
    expect(ledger.budgets, isEmpty);
    expect(jsonDecode(storage.data!), isNot(contains('demo')));
    ledger.dispose();
  });

  test('a legacy ledger with user changes is preserved on upgrade', () async {
    final storage = populatedStorage(legacyDemo: true, changed: true);
    final original = storage.data;
    final ledger = Ledger(storage, clock: () => testNow);
    await ledger.load();

    expect(ledger.account('monzo')?.archived, isTrue);
    expect(ledger.entries, isNotEmpty);
    expect(ledger.budgets, isNotEmpty);
    expect(storage.data, original);
    ledger.dispose();
  });

  testWidgets('exports and restores a complete ledger from Analysis', (
    tester,
  ) async {
    final previousPicker = FilePickerPlatform.instance;
    final picker = BackupPicker();
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = previousPicker);

    final storage = populatedStorage();
    final ledger = Ledger(storage, clock: () => testNow);
    await launch(tester, ledger);
    await ledger.setArchived('savings', true);
    await ledger.adjust('monzo', 42000, 'Statement reconciled');
    await ledger.togglePrivacy();
    final original = ledger.exportBackup();

    await tap(tester, find.text('Analysis'));
    final export = find.text('Export backup');
    final restore = find.text('Restore backup');
    await tester.scrollUntilVisible(export, 220);
    await tap(tester, export);
    expect(picker.saved, original);
    expect(find.text('Backup exported'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await ledger.setArchived('savings', false);
    await ledger.deleteEntry('sample-2');
    await ledger.togglePrivacy();
    final modified = ledger.exportBackup();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(restore, 220);
    await tester.pumpAndSettle();
    await tap(tester, restore);
    expect(find.text('Restore this backup?'), findsOneWidget);
    await tap(tester, find.text('Cancel'));
    expect(ledger.exportBackup(), modified);

    await tap(tester, restore);
    await tap(
      tester,
      find.descendant(of: find.byType(AlertDialog), matching: restore),
    );
    expect(find.text('Backup restored'), findsOneWidget);
    expect(ledger.exportBackup(), original);

    final reopened = Ledger(storage, clock: () => testNow);
    await reopened.load();
    expect(reopened.exportBackup(), original);
    reopened.dispose();
  });

  test('invalid and incompatible backup files are rejected', () async {
    final ledger = Ledger(populatedStorage(), clock: () => testNow);
    await ledger.load();
    final original = ledger.exportBackup();
    final data = jsonDecode(utf8.decode(original)) as Map<String, dynamic>;

    expect(
      () => LedgerSnapshot.fromBackup(utf8.encode('not a backup')),
      throwsFormatException,
    );
    expect(
      () => LedgerSnapshot.fromBackup(
        utf8.encode(jsonEncode({...data, 'version': 9})),
      ),
      throwsFormatException,
    );
    final entries = data['entries'] as List;
    final first = entries.first as Map;
    first['account'] = 'missing-account';
    expect(
      () => LedgerSnapshot.fromBackup(utf8.encode(jsonEncode(data))),
      throwsFormatException,
    );
    expect(ledger.exportBackup(), original);
    ledger.dispose();
  });

  test('failed backup restore preserves the saved ledger', () async {
    final storage = populatedStorage();
    final ledger = Ledger(storage, clock: () => testNow);
    await ledger.load();
    final before = storage.data;
    final emptyBackup = LedgerSnapshot.fromBackup(
      (const LedgerSnapshot(
        accounts: [],
        entries: [],
        budgets: [],
        hidden: false,
      )).toBackup(),
    );
    storage.failWrites = true;
    await expectLater(
      ledger.restoreBackup(emptyBackup),
      throwsA(isA<LedgerException>()),
    );
    expect(ledger.accounts, hasLength(3));
    expect(storage.data, before);
    storage.failWrites = false;
    await ledger.restoreBackup(emptyBackup);
    expect(ledger.accounts, isEmpty);
    ledger.dispose();
  });

  testWidgets('income can be excluded from net cash flow and included later', (
    tester,
  ) async {
    final storage = populatedStorage();
    final ledger = Ledger(storage, clock: () => testNow);
    await launch(tester, ledger);
    final baseline = ledger.monthlyCashFlow(testNow);
    final account = ledger.account('monzo')!;
    final balance = ledger.balance(account);

    await tap(tester, find.byTooltip('Add transaction'));
    await tap(tester, find.text('Income'));
    await tester.enterText(find.widgetWithText(TextFormField, '0.00'), '25.00');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g. Salary'),
      'Reimbursed travel',
    );
    await tap(tester, find.text('Choose category'));
    await tap(tester, find.text('Refunds'));
    final option = find.widgetWithText(
      SwitchListTile,
      'Include in net cash flow',
    );
    expect(tester.widget<SwitchListTile>(option).value, isTrue);
    await tap(tester, option);
    await tap(tester, find.text('Save Income'));

    final entry = ledger.entries.firstWhere(
      (entry) => entry.name == 'Reimbursed travel',
    );
    final flow = ledger.monthlyCashFlow(testNow);
    expect(entry.includeInCashFlow, isFalse);
    expect(flow.income, baseline.income);
    expect(flow.excludedIncome, 2500);
    expect(flow.trend, baseline.trend);
    expect(find.text('−£482.65'), findsOneWidget);
    expect(ledger.balance(account), balance + 2500);
    expect(
      ledger.activity(DateSpan.month(testNow), accountId: account.id).income,
      2500,
    );
    final backup = LedgerSnapshot.fromBackup(ledger.exportBackup());
    expect(
      backup.entries
          .firstWhere((item) => item.id == entry.id)
          .includeInCashFlow,
      isFalse,
    );

    final reopened = Ledger(storage, clock: () => testNow);
    await reopened.load();
    expect(reopened.entry(entry.id)?.includeInCashFlow, isFalse);
    reopened.dispose();

    await tap(tester, find.text('Reimbursed travel'));
    expect(find.text('Excluded'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.scrollUntilVisible(find.text('Edit Transaction'), 180);
    await tester.pumpAndSettle();
    await tap(tester, find.text('Edit Transaction'));
    expect(tester.widget<SwitchListTile>(option).value, isFalse);
    await tap(tester, option);
    await tap(tester, find.text('Save Changes'));

    expect(ledger.monthlyCashFlow(testNow).income, baseline.income + 2500);
    expect(ledger.balance(account), balance + 2500);
    expect(find.text('Included'), findsOneWidget);
  });

  test('GBP input validates grouping and preserves exact pennies', () {
    expect(parseMoney('£2,450.05'), 245005);
    expect(parseMoney('−£0.01', signed: true), -1);
    expect(parseMoney('.25'), 25);
    expect(parseMoney('2,45.05'), isNull);
    expect(parseMoney('0.001'), isNull);
    expect(parseMoney('-1.00'), isNull);
    expect(money(-123456789), '−£1,234,567.89');
  });
}
