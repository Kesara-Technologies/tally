import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<File> _ledgerFile() async {
  final directory = await getApplicationSupportDirectory();
  return File('${directory.path}${Platform.pathSeparator}tally-ledger.json');
}

Future<String?> readLedger() async {
  final file = await _ledgerFile();
  return await file.exists() ? file.readAsString() : null;
}

Future<void> writeLedger(String data) async {
  final file = await _ledgerFile();
  await file.parent.create(recursive: true);
  final pending = File('${file.path}.pending');
  await pending.writeAsString(data, flush: true);
  await pending.rename(file.path);
}
