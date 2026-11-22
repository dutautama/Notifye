import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../data/repositories/meta_repository.dart';

class PrinterException implements Exception {
  PrinterException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PairedPrinter {
  const PairedPrinter(this.name, this.address);
  final String name;
  final String address;
}

/// Printer struk thermal Bluetooth (ESC/POS). Printer harus sudah di-pair
/// lewat Setelan Bluetooth HP.
class PrinterService {
  PrinterService(this._meta);
  final MetaRepository _meta;

  Future<void> _ensureReady() async {
    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      throw PrinterException(
        'Izin "Perangkat di sekitar" belum diberikan. Izinkan lalu coba lagi '
        '(Setelan HP → Aplikasi → UsahaKonten → Izin).',
      );
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw PrinterException('Bluetooth HP mati. Nyalakan Bluetooth lalu coba lagi.');
    }
  }

  Future<List<PairedPrinter>> pairedPrinters() async {
    await _ensureReady();
    final list = await PrintBluetoothThermal.pairedBluetooths;
    return [for (final b in list) PairedPrinter(b.name, b.macAdress)];
  }

  Future<PairedPrinter?> savedPrinter() async {
    final addr = await _meta.get(MetaRepository.printerAddress);
    if (addr == null) return null;
    return PairedPrinter(await _meta.get(MetaRepository.printerName) ?? addr, addr);
  }

  Future<void> savePrinter(PairedPrinter p) async {
    await _meta.set(MetaRepository.printerAddress, p.address);
    await _meta.set(MetaRepository.printerName, p.name);
  }

  /// Lebar kertas 58 atau 80 mm → karakter per baris 32 / 48.
  Future<int> paperWidthMm() async => int.tryParse(await _meta.get(MetaRepository.printerWidth) ?? '') ?? 58;
  Future<void> setPaperWidthMm(int mm) => _meta.set(MetaRepository.printerWidth, '$mm');
  Future<int> charsPerLine() async => await paperWidthMm() >= 80 ? 48 : 32;

  Future<void> printBytes(List<int> bytes) async {
    await _ensureReady();
    final printer = await savedPrinter();
    if (printer == null) {
      throw PrinterException('Printer belum dipilih. Buka Pengaturan → Printer Bluetooth.');
    }
    if (!await PrintBluetoothThermal.connectionStatus) {
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: printer.address);
      if (!ok) {
        throw PrinterException('Tidak bisa terhubung ke ${printer.name}. Pastikan printer menyala & dekat.');
      }
    }
    // Kirim per potongan agar buffer printer murah tidak meluap.
    const chunk = 512;
    for (var i = 0; i < bytes.length; i += chunk) {
      final end = i + chunk > bytes.length ? bytes.length : i + chunk;
      if (!await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end))) {
        throw PrinterException('Gagal mengirim data ke printer.');
      }
    }
  }

  Future<void> disconnect() => PrintBluetoothThermal.disconnect;
}
