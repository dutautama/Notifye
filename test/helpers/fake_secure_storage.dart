import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Penyimpanan palsu di memori untuk menguji PinService tanpa perangkat.
class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({required String key, AppleOptions? iOptions, AndroidOptions? aOptions,
          LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions,
          WindowsOptions? wOptions}) async =>
      data[key];

  @override
  Future<void> write({required String key, required String? value, AppleOptions? iOptions,
      AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions,
      AppleOptions? mOptions, WindowsOptions? wOptions}) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({required String key, AppleOptions? iOptions, AndroidOptions? aOptions,
          LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions,
          WindowsOptions? wOptions}) async =>
      data.remove(key);
}

