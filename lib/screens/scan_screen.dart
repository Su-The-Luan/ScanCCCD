import 'dart:async';
import 'dart:io'; 
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img; 
import 'package:smart_cccd/models/cccd_info.dart';
import 'package:smart_cccd/services/camera_service.dart';
import 'profile_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late CameraController _controller;
  bool _initialized = false;
  final GlobalKey _previewKey = GlobalKey();
  final CameraService _cameraService = CameraService();
  Timer? _timer;
  bool _isCapturing = false;
  bool _isProcessing = false;

  final double overlayW = 230;
  final double overlayH = 230;

  Size? _containerSize;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        return;
      }
      _controller = CameraController(cameras[0], ResolutionPreset.high);
      await _controller.initialize();
      final maxZoom = await _controller.getMaxZoomLevel();
      final zoomLevel = maxZoom > 2.0 ? 2.0 : maxZoom;  
      await _controller.setZoomLevel(zoomLevel);
      if (!mounted) return;
      setState(() {
        _initialized = true;
      });
      _startScanning();
    } catch (e) {
    }
  }

  void _startScanning() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) { 
      _onCapture();
    });
  }

  void _stopScanning() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _onCapture() async {
    if (!_initialized || _isCapturing || _containerSize == null) return;
    _isCapturing = true;
    try {
      final XFile file = await _controller.takePicture();

      final bytes = await file.readAsBytes();

      final image = img.decodeImage(bytes);
      if (image == null) return;

      final croppedImage = _cropToOverlay(image);
      if (croppedImage == null) return;

      final grayscaleImage = img.grayscale(croppedImage);

      final adjustedBytes = img.encodeJpg(grayscaleImage, quality: 80);  

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/adjusted_image.jpg');
      await tempFile.writeAsBytes(adjustedBytes);
      final adjustedXFile = XFile(tempFile.path);

      final codes = await _cameraService.scanQrFromXFile(adjustedXFile);

      await tempFile.delete();


      if (codes.isEmpty) {
        return;
      }

      setState(() {
        _isProcessing = true;
      });

      final payload = codes.first;

      try {
        final parts = payload.split('|');
        if (parts.length < 7) {
          throw Exception('Payload không đủ fields');
        }
        String formattedDob = parts[3].trim();
        if (formattedDob.length == 8) {
          formattedDob = '${formattedDob.substring(0, 2)}/${formattedDob.substring(2, 4)}/${formattedDob.substring(4)}';
        }
        final info = CccdInfo(
          idNumber: parts[0].trim(),
          oldIdNumber: parts[1].trim(),
          fullName: parts[2].trim(),
          dateOfBirth: formattedDob,
          gender: parts[4].trim(),
          nationality: "Việt Nam",
          permanentAddress: parts[5].trim(),
        );

        await Future.delayed(const Duration(seconds: 1));

        if (!mounted) return;
        _stopScanning();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProfileScreen(info: info)));
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    } finally {
      _isCapturing = false;
    }
  }

  img.Image? _cropToOverlay(img.Image image) {
    if (_containerSize == null) return null;

    final containerWidth = _containerSize!.width;
    final containerHeight = _containerSize!.height;

    final previewSize = _controller.value.previewSize;
    if (previewSize == null) return null;

    final scaleX = containerWidth / previewSize.width;
    final scaleY = containerHeight / previewSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY; 

    final offsetX = (containerWidth - previewSize.width * scale) / 2;
    final offsetY = (containerHeight - previewSize.height * scale) / 2;

    final overlayCenterX = containerWidth / 2;
    final overlayCenterY = containerHeight / 2;

    final previewCenterX = (overlayCenterX - offsetX) / scale;
    final previewCenterY = (overlayCenterY - offsetY) / scale;
    final previewWidthCrop = overlayW / scale;
    final previewHeightCrop = overlayH / scale;

    final imageScaleX = image.width / previewSize.width;
    final imageScaleY = image.height / previewSize.height;

    final imageLeft = ((previewCenterX - previewWidthCrop / 2) * imageScaleX).clamp(0, image.width.toDouble()).toInt();
    final imageTop = ((previewCenterY - previewHeightCrop / 2) * imageScaleY).clamp(0, image.height.toDouble()).toInt();
    final imageWidth = ((previewWidthCrop * imageScaleX).clamp(0, image.width - imageLeft).toInt());
    final imageHeight = ((previewHeightCrop * imageScaleY).clamp(0, image.height - imageTop).toInt());

    if (imageWidth <= 0 || imageHeight <= 0) return null;

    return img.copyCrop(image, x: imageLeft, y: imageTop, width: imageWidth, height: imageHeight);
  }

  @override
  void dispose() {
    _stopScanning();
    if (_initialized) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan CCCD'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                _containerSize = Size(constraints.maxWidth, constraints.maxHeight);   
                return Center(
                  child: Container(
                    key: _previewKey,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    color: Colors.black,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: CameraPreview(_controller),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _OverlayPainter(
                              overlayW: overlayW,
                              overlayH: overlayH,
                            ),
                          ),
                        ),
                        if (_isProcessing)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black54,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 50,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: const Text(
                              'Đưa thẻ CCCD vào khung để quét tự động',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black,
                                    offset: Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final double overlayW;
  final double overlayH;

  _OverlayPainter({
    required this.overlayW,
    required this.overlayH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(center: size.center(Offset.zero), width: overlayW, height: overlayH);

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(rect);
    path.fillType = PathFillType.evenOdd;
    final backgroundPaint = Paint()..color = Colors.black54;
    canvas.drawPath(path, backgroundPaint);

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(rect, borderPaint);

    final cornerPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    const double len = 24;

    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(len, 0), cornerPaint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, len), cornerPaint);

    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-len, 0), cornerPaint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, len), cornerPaint);

    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(len, 0), cornerPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -len), cornerPaint);

    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-len, 0), cornerPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -len), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return oldDelegate.overlayW != overlayW || oldDelegate.overlayH != overlayH;
  }
}
