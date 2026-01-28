import 'dart:io';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class BarcodeService {
  final _scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);

  Future<List<String>> scanFile(String path) async {
    final input = InputImage.fromFilePath(path);
    final barcodes = await _scanner.processImage(input);
    return barcodes.map((b) => b.rawValue ?? '').where((s) => s.isNotEmpty).toList();
  }

  Future<List<String>> scanImage(InputImage input) async {
    final barcodes = await _scanner.processImage(input);
    return barcodes.map((b) => b.rawValue ?? '').where((s) => s.isNotEmpty).toList();
  }

  void dispose() => _scanner.close();
}