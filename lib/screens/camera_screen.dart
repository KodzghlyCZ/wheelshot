import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

import '../models/shoot_plan.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.step});

  final ShotStep step;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  CameraController? _controller;
  bool _ready = false;
  bool _capturing = false;
  bool _switching = false;
  String? _error;
  bool _torchOn = false;
  Offset? _focusUi;
  Timer? _focusHide;
  /// Sensor tilt while Activity stays portrait — drives hint/guide + JPEG EXIF.
  NativeDeviceOrientation _sensorOrientation =
      NativeDeviceOrientation.portraitUp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    _init();
  }

  Future<void> _init({int? preferIndex}) async {
    try {
      final all = await availableCameras();
      // Stock-camera style: only rear lenses (wide / ultra / tele…), never front.
      final back = all
          .where((c) => c.lensDirection == CameraLensDirection.back)
          .toList();
      final cameras = back.isNotEmpty ? back : all;
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No cameras found');
        return;
      }
      _cameras = cameras;
      var index = preferIndex ?? 0;
      if (index < 0 || index >= cameras.length) index = 0;
      await _openCamera(index);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _openCamera(int index) async {
    final old = _controller;
    _controller = null;
    _ready = false;
    if (mounted) setState(() {});

    await old?.dispose();

    final description = _cameras[index];
    final controller = CameraController(
      description,
      // Full sensor still (4:3 on Pixel), not the plugin's 16:9 video crop.
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    await controller.setFocusMode(FocusMode.auto);
    await controller.setExposureMode(ExposureMode.auto);
    // Activity is portrait-locked; we stamp EXIF from the sensor at capture.
    try {
      await controller.unlockCaptureOrientation();
    } catch (_) {}

    if (widget.step.preferTorch) {
      try {
        await controller.setFlashMode(FlashMode.torch);
        _torchOn = true;
      } catch (_) {
        _torchOn = false;
      }
    } else {
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}
      _torchOn = false;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }
    debugPrint(
      'WheelShot preview ${controller.value.previewSize} '
      'aspect ${controller.value.aspectRatio.toStringAsFixed(3)}',
    );
    setState(() {
      _controller = controller;
      _cameraIndex = index;
      _ready = true;
      _switching = false;
      _error = null;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _switching || _capturing) return;
    setState(() => _switching = true);
    final next = (_cameraIndex + 1) % _cameras.length;
    try {
      await _openCamera(next);
    } catch (e) {
      if (mounted) {
        setState(() {
          _switching = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _onTapFocus(TapDownDetails details, Size previewSize) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    if (previewSize.width <= 0 || previewSize.height <= 0) return;

    final local = details.localPosition;
    final xp = (local.dx / previewSize.width).clamp(0.0, 1.0);
    final yp = (local.dy / previewSize.height).clamp(0.0, 1.0);

    HapticFeedback.selectionClick();
    setState(() => _focusUi = local);
    _focusHide?.cancel();
    _focusHide = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _focusUi = null);
    });

    try {
      await c.setFocusMode(FocusMode.auto);
      await c.setFocusPoint(Offset(xp, yp));
      await c.setExposurePoint(Offset(xp, yp));
    } catch (_) {}
  }

  Future<void> _toggleTorch() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      if (_torchOn) {
        await c.setFlashMode(FlashMode.off);
        setState(() => _torchOn = false);
      } else {
        await c.setFlashMode(FlashMode.torch);
        setState(() => _torchOn = true);
      }
    } catch (_) {}
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      try {
        await c.setFocusMode(FocusMode.locked);
      } catch (_) {}
      // Stamp JPEG/EXIF from sensor tilt (Activity stays portrait).
      try {
        await c.lockCaptureOrientation(
          _deviceOrientation(_sensorOrientation),
        );
      } catch (_) {}
      final file = await c.takePicture();
      try {
        await c.unlockCaptureOrientation();
      } catch (_) {}
      try {
        await c.setFocusMode(FocusMode.auto);
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pop(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      if (state == AppLifecycleState.resumed) {
        _init(preferIndex: _cameraIndex);
      }
      return;
    }
    if (state == AppLifecycleState.inactive) {
      c.dispose();
      _controller = null;
      _ready = false;
    } else if (state == AppLifecycleState.resumed) {
      _init(preferIndex: _cameraIndex);
    }
  }

  @override
  void dispose() {
    _focusHide?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  String get _cameraLabel {
    if (_cameras.isEmpty) return '';
    final cam = _cameras[_cameraIndex];
    // Camera2 id is usually in [CameraDescription.name] (e.g. "0", "2", "3").
    // Preview size is in sensor orientation: 1920×1440 is 4:3, 1280×720 is 16:9.
    final preview = _controller?.value.previewSize;
    final size = preview == null
        ? ''
        : ' · ${preview.width.toInt()}×${preview.height.toInt()}';
    return 'Lens ${_cameraIndex + 1}/${_cameras.length} · ${cam.name}$size';
  }

  /// Quarter-turns (CW) so a bottom-aligned child lands on the gravity-bottom
  /// edge of the portrait Activity.
  ///
  /// landscapeLeft (earpiece left / USB right) → ground is Activity LEFT → 3
  /// landscapeRight (earpiece right / USB left) → ground is Activity RIGHT → 1
  int _chromeTurns(NativeDeviceOrientation o) => switch (o) {
        NativeDeviceOrientation.landscapeLeft => 3,
        NativeDeviceOrientation.portraitDown => 2,
        NativeDeviceOrientation.landscapeRight => 1,
        _ => 0,
      };

  DeviceOrientation _deviceOrientation(NativeDeviceOrientation o) =>
      switch (o) {
        NativeDeviceOrientation.landscapeLeft =>
          DeviceOrientation.landscapeLeft,
        NativeDeviceOrientation.landscapeRight =>
          DeviceOrientation.landscapeRight,
        NativeDeviceOrientation.portraitDown =>
          DeviceOrientation.portraitDown,
        _ => DeviceOrientation.portraitUp,
      };

  @override
  Widget build(BuildContext context) {
    final topBar = Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          Expanded(
            child: Text(
              widget.step.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    final controls = _CaptureControls(
      torchOn: _torchOn,
      capturing: _capturing,
      switching: _switching,
      cameraCount: _cameras.length,
      cameraIndex: _cameraIndex,
      cameraLabel: _cameraLabel,
      onTorch: _toggleTorch,
      onCapture: _capture,
      onSwitch: _switchCamera,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: NativeDeviceOrientationReader(
        useSensor: true,
        builder: (context) {
          final next = NativeDeviceOrientationReader.orientation(context);
          if (next != _sensorOrientation) {
            // ignore: avoid_print
            print('WheelShot orientation $next');
          }
          _sensorOrientation = next;
          final turns = _chromeTurns(_sensorOrientation);

          return SafeArea(
            child: Column(
              children: [
                topBar,
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_error != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else if (!_ready ||
                          _controller == null ||
                          _switching)
                        const Center(child: CircularProgressIndicator())
                      else
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: _ContainPreview(
                            controller: _controller!,
                            focusUi: _focusUi,
                            guide: widget.step.guide,
                            chromeTurns: turns,
                            onTapFocus: _onTapFocus,
                            onFocusUi: (o) =>
                                setState(() => _focusUi = o),
                          ),
                        ),
                      // Gravity chrome: rotate a full-bleed layer so
                      // Alignment.bottomCenter is always the physical bottom.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Transform.rotate(
                            angle: turns * math.pi / 2,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  12,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.sizeOf(context)
                                            .shortestSide *
                                        0.88,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        widget.step.hint,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          height: 1.25,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                controls,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Flash | shutter | switch under the viewport (app stays portrait).
class _CaptureControls extends StatelessWidget {
  const _CaptureControls({
    required this.torchOn,
    required this.capturing,
    required this.switching,
    required this.cameraCount,
    required this.cameraIndex,
    required this.cameraLabel,
    required this.onTorch,
    required this.onCapture,
    required this.onSwitch,
  });

  final bool torchOn;
  final bool capturing;
  final bool switching;
  final int cameraCount;
  final int cameraIndex;
  final String cameraLabel;
  final VoidCallback onTorch;
  final VoidCallback onCapture;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(
            width: 72,
            child: IconButton(
              onPressed: onTorch,
              iconSize: 28,
              icon: Icon(
                torchOn ? Icons.flash_on : Icons.flash_off,
                color: torchOn ? Colors.amber : Colors.white,
              ),
            ),
          ),
          GestureDetector(
            onTap: capturing ? null : onCapture,
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              padding: const EdgeInsets.all(5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: capturing
                      ? Colors.white38
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip:
                      cameraCount > 1 ? cameraLabel : 'Only one rear lens',
                  onPressed:
                      (cameraCount > 1 && !switching) ? onSwitch : null,
                  iconSize: 28,
                  icon: Icon(
                    Icons.cameraswitch,
                    color:
                        cameraCount > 1 ? Colors.white : Colors.white38,
                  ),
                ),
                if (cameraCount > 1)
                  Text(
                    '${cameraIndex + 1}/$cameraCount',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Letterbox the camera preview without forcing a second aspect ratio
/// (forcing sensor aspect on top of [CameraPreview] squashes the image).
class _ContainPreview extends StatelessWidget {
  const _ContainPreview({
    required this.controller,
    required this.focusUi,
    required this.guide,
    required this.chromeTurns,
    required this.onTapFocus,
    required this.onFocusUi,
  });

  final CameraController controller;
  final Offset? focusUi;
  final ShotGuide guide;
  final int chromeTurns;
  final Future<void> Function(TapDownDetails details, Size previewSize)
      onTapFocus;
  final ValueChanged<Offset?> onFocusUi;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: _PreviewStack(
              controller: controller,
              focusUi: focusUi,
              guide: guide,
              chromeTurns: chromeTurns,
              onTapFocus: onTapFocus,
              onFocusUi: onFocusUi,
            ),
          ),
        );
      },
    );
  }
}

class _PreviewStack extends StatelessWidget {
  const _PreviewStack({
    required this.controller,
    required this.focusUi,
    required this.guide,
    required this.chromeTurns,
    required this.onTapFocus,
    required this.onFocusUi,
  });

  final CameraController controller;
  final Offset? focusUi;
  final ShotGuide guide;
  final int chromeTurns;
  final Future<void> Function(TapDownDetails details, Size previewSize)
      onTapFocus;
  final ValueChanged<Offset?> onFocusUi;

  @override
  Widget build(BuildContext context) {
    // Give CameraPreview a finite width so its AspectRatio can resolve.
    // Height follows the plugin’s own aspect (do not invert / override).
    const previewWidth = 1080.0;
    final angle = chromeTurns * math.pi / 2;
    return SizedBox(
      width: previewWidth,
      child: Builder(
        builder: (previewContext) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final box = previewContext.findRenderObject() as RenderBox?;
              final size = (box != null && box.hasSize)
                  ? box.size
                  : Size(
                      previewWidth,
                      previewWidth / controller.value.aspectRatio,
                    );
              onFocusUi(details.localPosition);
              onTapFocus(details, size);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                CameraPreview(controller),
                // Guide + focus reticle follow gravity; preview stays fixed.
                Positioned.fill(
                  child: IgnorePointer(
                    child: Transform.rotate(
                      angle: angle,
                      child: CustomPaint(painter: _GuidePainter(guide)),
                    ),
                  ),
                ),
                if (focusUi != null)
                  Positioned(
                    left: focusUi!.dx - 36,
                    top: focusUi!.dy - 36,
                    child: IgnorePointer(
                      child: Transform.rotate(
                        angle: angle,
                        child: const _FocusReticle(),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FocusReticle extends StatelessWidget {
  const _FocusReticle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: CustomPaint(painter: _FocusReticlePainter()),
    );
  }
}

class _FocusReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const inset = 4.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    canvas.drawRect(rect, stroke);
    const tick = 10.0;
    final midX = size.width / 2;
    final midY = size.height / 2;
    canvas.drawLine(Offset(midX, inset), Offset(midX, inset + tick), stroke);
    canvas.drawLine(
      Offset(midX, size.height - inset),
      Offset(midX, size.height - inset - tick),
      stroke,
    );
    canvas.drawLine(Offset(inset, midY), Offset(inset + tick, midY), stroke);
    canvas.drawLine(
      Offset(size.width - inset, midY),
      Offset(size.width - inset - tick, midY),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.guide);

  final ShotGuide guide;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (guide) {
      case ShotGuide.overallFrame:
        // Square crop guide — marketplaces use square thumbnails.
        final side = math.min(size.width, size.height) * 0.82;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: side,
              height: side,
            ),
            const Radius.circular(18),
          ),
          stroke,
        );
      case ShotGuide.treadSurface:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: size.width * 0.86,
              height: size.width * 0.86,
            ),
            const Radius.circular(12),
          ),
          stroke,
        );
      case ShotGuide.dotCloseup:
      case ShotGuide.rimStamp:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: size.width * 0.55,
              height: size.width * 0.28,
            ),
            const Radius.circular(10),
          ),
          stroke,
        );
      case ShotGuide.sidewallSize:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: size.width * 0.88,
              height: size.width * 0.22,
            ),
            const Radius.circular(10),
          ),
          stroke,
        );
      case ShotGuide.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _GuidePainter oldDelegate) =>
      oldDelegate.guide != guide;
}
