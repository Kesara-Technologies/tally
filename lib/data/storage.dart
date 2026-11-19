import 'storage_native.dart'
    if (dart.library.js_interop) 'storage_web.dart'
    as platform;

abstract interface class LedgerStorage {
  Future<String?> read();
  Future<void> write(String data);
}

class LocalLedgerStorage implements LedgerStorage {
  @override
  Future<String?> read() => platform.readLedger();

  @override
  Future<void> write(String data) => platform.writeLedger(data);
}
