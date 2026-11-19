import 'package:web/web.dart' as web;

const _storageKey = 'tally.ledger.v1';

Future<String?> readLedger() async =>
    web.window.localStorage.getItem(_storageKey);

Future<void> writeLedger(String data) async {
  web.window.localStorage.setItem(_storageKey, data);
}
