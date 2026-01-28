import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_cccd/services/barcode_service.dart';

class CameraService {
  final BarcodeService _barcodeService = BarcodeService();

  Future<List<String>> scanQrFromXFile(XFile file) async {
    return await _barcodeService.scanFile(file.path);
  }

  void startAutoScan(CameraController controller, Function(List<String>) onCodesDetected) {
    controller.startImageStream((CameraImage image) {
      _processImage(image, controller, onCodesDetected);
    });
  }

  Future<void> _processImage(CameraImage image, CameraController controller, Function(List<String>) onCodesDetected) async {
    final input = _inputImageFromCameraImage(image, controller);
    if (input != null) {
      final codes = await _barcodeService.scanImage(input);
      if (codes.isNotEmpty) {
        onCodesDetected(codes);
      }
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraController controller) {
    final camera = controller.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation) ?? InputImageRotation.rotation0deg;
    }
    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation ?? InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
}
