import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../vision/bolt_pattern.dart';
import '../widgets/bolt_pattern_overlay.dart';

/// Live overlay: center bore and the evenly spaced bolt holes around it.
class BoltPatternScreen extends StatefulWidget {
  const BoltPatternScreen({super.key});

  @override
  State<BoltPatternScreen> createState() => _BoltPatternScreenState();
}

class _BoltPatternScreenState extends State<BoltPatternScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  String? _error;
  BoltPattern? _pattern;
  var _busy = false;
  final _hold = BoltPatternHold();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive) {
      _busy = false;
      controller?.dispose();
      _controller = null;
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _open();
    }
  }

  Future<void> _open() async {
    try {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        if (mounted) setState(() => _error = 'Camera permission is required');
        return;
      }
      final all = await availableCameras();
      final back =
          all.where((c) => c.lensDirection == CameraLensDirection.back);
      final description = back.isNotEmpty ? back.first : all.firstOrNull;
      if (description == null) {
        if (mounted) setState(() => _error = 'No cameras found');
        return;
      }
      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      await controller.startImageStream(_onFrame);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _onFrame(CameraImage image) {
    if (_busy) return;
    final controller = _controller;
    if (controller == null) return;
    _busy = true;
    final sensor = controller.description.sensorOrientation;
    analyzeCameraFrame(image, sensor).then((pattern) {
      _busy = false;
      if (!mounted) return;
      final shown = _hold.push(pattern);
      if (identical(shown, _pattern)) return;
      setState(() => _pattern = shown);
    }).catchError((_) {
      _busy = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final pattern = _pattern;
    final caption = pattern == null
        ? 'Put the bore on the dot. Keep the bolt holes inside the circle.'
        : pattern.hasBolts
            ? '${pattern.boltCount} bolts'
            : 'Center bore';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Bolt pattern')),
      body: _error != null
          ? Center(child: Text(_error!, textAlign: TextAlign.center))
          : controller == null || !controller.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 1080,
                        child: CameraPreview(
                          controller,
                          child: CustomPaint(
                            painter: BoltPatternOverlayPainter(pattern),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 28,
                      child: Text(
                        caption,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
