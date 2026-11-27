import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

import '../data/rim_catalog.dart';
import '../models/shoot_plan.dart';
import '../models/spec_draft.dart';
import '../services/session_store.dart';
import '../vision/bolt_pattern.dart';
import '../vision/dot_ocr.dart';
import '../widgets/bolt_pattern_overlay.dart';
import '../widgets/confirm_leave.dart';
import '../widgets/dot_aim_overlay.dart';
import '../widgets/shoot_dials.dart';
import 'specs_screen.dart';

class WizardScreen extends StatefulWidget {
  const WizardScreen({
    super.key,
    required this.store,
    required this.steps,
    this.initialCaptures,
    this.reviewAfterCapture = true,
  });

  final SessionStore store;
  final List<ShotStep> steps;

  /// stepId → jpg path for photos that already exist (edit mode).
  final Map<String, String>? initialCaptures;

  /// Kept so existing callers compile. The step itself is the review.
  final bool reviewAfterCapture;

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen>
    with WidgetsBindingObserver {
  late List<ShotStep> _steps;
  late SpecDraft _draft;
  int _index = 0;
  final Map<String, String> _captured = {};
  final Map<String, DeviceOrientation> _shotHold = {};
  final Set<String> _keptWithoutPhoto = {};
  Offset? _focusUi;
  Timer? _focusHide;
  int _camSensor = 90;
  bool _camFront = false;
  final Set<String> _hubFrozen = {};
  bool _extrasMode = false;
  int _extraCount = 0;
  bool _capturing = false;
  NativeDeviceOrientation _sensor = NativeDeviceOrientation.portraitUp;
  int _snappedIndex = -1;
  String? _etAtStep;

  CameraController? _controller;
  String? _cameraError;
  BoltPattern? _pattern;
  final _hold = BoltPatternHold();
  final _dotOcr = DotOcr();
  final _dotHold = DotDateHold();
  DotDate? _dotDate;
  var _streamBusy = false;
  var _torchOn = false;

  ShotStep get _step => _steps[_index];
  bool get _isLastRequired =>
      !_extrasMode && _index >= widget.steps.length - 1;
  bool get _inExtras => _extrasMode;
  bool get _hasPhoto => _captured.containsKey(_step.id);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    _steps = List.of(widget.steps);
    final initial = widget.initialCaptures;
    if (initial != null) _captured.addAll(initial);
    final counts = _specCounts();
    _draft = SpecDraft.empty(tireCount: counts.$1, rimCount: counts.$2);
    for (final step in _steps) {
      if (step.dials == ShotDials.hub && _captured.containsKey(step.id)) {
        _hubFrozen.add(step.id);
      }
    }
    _loadSpecs();
    _openCamera();
  }

  (int, int) _specCounts() {
    final cat = widget.store.category;
    if (cat == ShootCategory.spare) {
      return (1, widget.store.spareHasRim ? 1 : 0);
    }
    final cfg = widget.store.config?.forCategory(cat);
    final tires = cat.includesTire ? (cfg?.tireTypes ?? 1) : 0;
    final rims = cat.includesRim ? (cfg?.rimTypes ?? 1) : 0;
    return (tires, rims);
  }

  Future<void> _loadSpecs() async {
    final saved = await widget.store.loadSpecs();
    if (saved == null || !mounted) return;
    setState(() => _draft.applySaved(saved));
  }

  @override
  void dispose() {
    _focusHide?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _dotOcr.dispose();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive) {
      _streamBusy = false;
      controller?.dispose();
      _controller = null;
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _openCamera();
    }
  }

  Future<void> _openCamera() async {
    try {
      final all = await availableCameras();
      final back = all
          .where((c) => c.lensDirection == CameraLensDirection.back)
          .toList();
      final description = back.isNotEmpty ? back.first : all.firstOrNull;
      if (description == null) {
        if (mounted) setState(() => _cameraError = 'No cameras found');
        return;
      }
      _camSensor = description.sensorOrientation;
      _camFront = description.lensDirection == CameraLensDirection.front;
      final controller = CameraController(
        description,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      try {
        await controller.unlockCaptureOrientation();
      } catch (_) {}
      try {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _cameraError = null;
      });
      await _syncCamera();
    } catch (e) {
      if (mounted) setState(() => _cameraError = e.toString());
    }
  }

  Future<void> _syncCamera() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final needStream =
        _step.dials == ShotDials.hub || _step.dials == ShotDials.dot;
    try {
      if (needStream && !c.value.isStreamingImages) {
        await c.startImageStream(_onStreamFrame);
      } else if (!needStream && c.value.isStreamingImages) {
        await c.stopImageStream();
        _pattern = null;
        _dotDate = null;
        _dotHold.push(null);
      }
    } catch (_) {}
    try {
      if (_step.preferTorch) {
        await c.setFlashMode(FlashMode.torch);
        _torchOn = true;
      } else {
        await c.setFlashMode(FlashMode.off);
        _torchOn = false;
      }
    } catch (_) {
      _torchOn = false;
    }
    if (mounted) setState(() {});
  }

  void _onStreamFrame(CameraImage image) {
    if (_streamBusy) return;
    if (_step.dials == ShotDials.hub) {
      _onHubFrame(image);
    } else if (_step.dials == ShotDials.dot) {
      _onDotFrame(image);
    }
  }

  void _onHubFrame(CameraImage image) {
    if (_step.dials != ShotDials.hub) return;
    final controller = _controller;
    if (controller == null) return;
    _streamBusy = true;
    analyzeCameraFrame(image, controller.description.sensorOrientation)
        .then((pattern) {
      if (!mounted || _step.dials != ShotDials.hub) return;
      final shown = _hold.push(pattern);
      final frozen = _hubFrozen.contains(_step.id);
      final count = shown?.boltCount ?? 0;
      final rim = _rimFor(_step);
      final writeBolts = !frozen &&
          rim != null &&
          !rim.pcdLockedToText &&
          kPcdBoltCounts.contains(count) &&
          rim.pcdBolts != count;
      if (identical(shown, _pattern) && !writeBolts) return;
      setState(() {
        _pattern = shown;
        if (writeBolts) rim.pcdBolts = count;
      });
    }).whenComplete(() {
      _streamBusy = false;
    });
  }

  void _onDotFrame(CameraImage image) {
    if (_step.dials != ShotDials.dot || _hasPhoto) return;
    final controller = _controller;
    if (controller == null) return;
    _streamBusy = true;
    _dotOcr
        .analyze(
      image,
      sensorOrientation: controller.description.sensorOrientation,
    )
        .then((found) {
      if (!mounted || _step.dials != ShotDials.dot) return;
      final shown = _dotHold.push(found);
      var wrote = false;
      if (shown != null) {
        final i = _step.specIndex;
        if (i >= 0 && i < _draft.tires.length) {
          final t = _draft.tires[i];
          if (t.dotWeek != shown.week || t.dotYear != shown.year) {
            t.dotWeek = shown.week;
            t.dotYear = shown.year;
            wrote = true;
          }
        }
      }
      if (identical(shown, _dotDate) && !wrote) return;
      setState(() => _dotDate = shown);
    }).whenComplete(() {
      _streamBusy = false;
    });
  }

  RimDraft? _rimFor(ShotStep step) {
    final i = step.specIndex;
    if (i < 0 || i >= _draft.rims.length) return null;
    return _draft.rims[i];
  }

  Future<void> _persist() async {
    try {
      await widget.store.saveSpecs(_draft.toSpecs());
    } catch (_) {}
  }

  Future<void> _goSpecs() async {
    await _persist();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SpecsScreen(store: widget.store),
      ),
    );
  }

  void _enterExtras() {
    var next = 1;
    for (final id in _captured.keys) {
      final m = RegExp(r'^extra_(\d+)$').firstMatch(id);
      if (m != null) {
        final n = int.parse(m.group(1)!);
        if (n >= next) next = n + 1;
      }
    }
    setState(() {
      _extrasMode = true;
      _extraCount = next;
      _steps = [...widget.steps, extraShotStep(next)];
      _index = _steps.length - 1;
    });
    _syncCamera();
  }

  Future<void> _take() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      try {
        await c.lockCaptureOrientation(_captureOrientation(_sensor));
      } catch (_) {}
      final file = await c.takePicture();
      try {
        await c.unlockCaptureOrientation();
      } catch (_) {}
      final saved = await widget.store.saveCapture(
        stepId: _step.id,
        sourcePath: file.path,
      );
      await FileImage(saved).evict();
      if (!mounted) return;
      setState(() {
        _captured[_step.id] = saved.path;
        _shotHold[_step.id] = _captureOrientation(_sensor);
        _keptWithoutPhoto.remove(_step.id);
        if (_step.dials == ShotDials.hub) _hubFrozen.add(_step.id);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _deletePhotoFile(String id) async {
    final path = _captured[id];
    if (path == null) return;
    await FileImage(File(path)).evict();
    try {
      await File(path).delete();
    } catch (_) {}
    _captured.remove(id);
    _shotHold.remove(id);
  }

  Future<void> _retry() async {
    final id = _step.id;
    await _deletePhotoFile(id);
    _hubFrozen.remove(id);
    _keptWithoutPhoto.remove(id);
    if (!mounted) return;
    setState(() {});
  }

  /// Drop the file and keep the dials. Next can move on with no photo.
  Future<void> _trash() async {
    final id = _step.id;
    await _deletePhotoFile(id);
    _keptWithoutPhoto.add(id);
    if (!mounted) return;
    setState(() {});
  }

  void _ensureSnap() {
    if (_snappedIndex == _index) return;
    _snappedIndex = _index;
    _etAtStep =
        _step.dials == ShotDials.et ? _rimFor(_step)?.etOut : null;
  }

  Future<void> _next() async {
    _ensureSnap();
    commitStep(_draft, _step);
    await _persist();
    if (!mounted) return;
    if (_inExtras) {
      setState(() {
        _extraCount++;
        _steps = [..._steps, extraShotStep(_extraCount)];
        _index = _steps.length - 1;
      });
      await _syncCamera();
      return;
    }
    if (_isLastRequired) {
      _enterExtras();
      return;
    }
    setState(() => _index++);
    await _syncCamera();
  }

  Future<void> _skip() async {
    if (_inExtras) {
      await _goSpecs();
      return;
    }
    _ensureSnap();
    _keptWithoutPhoto.remove(_step.id);
    if (_hasPhoto) await _deletePhotoFile(_step.id);
    _hubFrozen.remove(_step.id);
    discardStep(_draft, _step, restoreEt: _etAtStep);
    await _persist();
    if (!mounted) return;
    if (_isLastRequired) {
      _enterExtras();
      return;
    }
    setState(() => _index++);
    await _syncCamera();
  }

  Future<void> _tapFocus(TapDownDetails details, Size size) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing || _hasPhoto) return;
    if (size.width <= 0 || size.height <= 0) return;
    final local = details.localPosition;
    final xp = (local.dx / size.width).clamp(0.0, 1.0);
    final yp = (local.dy / size.height).clamp(0.0, 1.0);
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

  /// Turns so a label stays readable. Portrait stays with the locked UI.
  /// Landscape is the opposite of the gravity-dock used on the old camera
  /// screen, which left these labels upside down.
  int _chromeTurns(NativeDeviceOrientation o) => switch (o) {
        NativeDeviceOrientation.landscapeLeft => 1,
        NativeDeviceOrientation.landscapeRight => 3,
        _ => 0,
      };

  DeviceOrientation _captureOrientation(NativeDeviceOrientation o) =>
      switch (o) {
        NativeDeviceOrientation.landscapeLeft =>
          DeviceOrientation.landscapeLeft,
        NativeDeviceOrientation.landscapeRight =>
          DeviceOrientation.landscapeRight,
        _ => DeviceOrientation.portraitUp,
      };

  @override
  Widget build(BuildContext context) {
    final requiredTotal = widget.steps.length;
    final progress =
        _inExtras ? 1.0 : (_index + 1) / requiredTotal.clamp(1, 999);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await leaveToHome(context);
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 44,
          title: Text(
            _inExtras
                ? 'Extra'
                : '${_index + 1} / $requiredTotal · ${_step.title}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          actions: [
            if (_inExtras)
              TextButton(onPressed: _goSpecs, child: const Text('Done')),
            TextButton(
              onPressed: () => leaveToHome(context),
              child: const Text('Exit'),
            ),
          ],
        ),
        body: NativeDeviceOrientationReader(
          useSensor: true,
          builder: (context) {
            _sensor = NativeDeviceOrientationReader.orientation(context);
            final turns = _hasPhoto ? 0 : _chromeTurns(_sensor);
            final showDials = turns == 0 && _step.dials != ShotDials.none;
            final treadCap = widget.store.config
                    ?.forCategory(widget.store.category)
                    .maxTreadDepthsPerType ??
                4;
            return SafeArea(
              child: Column(
                children: [
                  LinearProgressIndicator(value: progress, minHeight: 3),
                  Expanded(child: _preview()),
                  if (showDials)
                    ShootDialArea(
                      stepId: _step.id,
                      child: ShootDialBody(
                        step: _step,
                        draft: _draft,
                        onChanged: () => setState(() {}),
                        maxTreadDepths: treadCap,
                      ),
                    ),
                  _actions(turns),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _preview() {
    final photo = _captured[_step.id];
    return LayoutBuilder(
      builder: (context, constraints) {
        final c = _controller;
        final sensor =
            (c != null && c.value.isInitialized) ? c.value.aspectRatio : 4 / 3;
        final widthOverHeight = 1 / sensor;
        var w = constraints.maxWidth;
        var h = w / widthOverHeight;
        if (h > constraints.maxHeight) {
          h = constraints.maxHeight;
          w = h * widthOverHeight;
        }
        final hub = _step.dials == ShotDials.hub && photo == null;
        final dot = _step.dials == ShotDials.dot && photo == null;
        Widget child;
        if (photo != null) {
          child = _ShotPhoto(
            path: photo,
            hold: _shotHold[_step.id],
            sensor: _camSensor,
            front: _camFront,
          );
        } else if (_cameraError != null) {
          child = Center(child: Text(_cameraError!));
        } else if (c == null || !c.value.isInitialized) {
          child = const Center(child: CircularProgressIndicator());
        } else {
          child = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _tapFocus(details, Size(w, h)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(c),
                if (hub)
                  CustomPaint(painter: BoltPatternOverlayPainter(_pattern)),
                if (dot)
                  CustomPaint(painter: DotAimOverlayPainter(_dotDate)),
                if (_focusUi != null)
                  Positioned(
                    left: _focusUi!.dx - 36,
                    top: _focusUi!.dy - 36,
                    child: const IgnorePointer(child: _FocusReticle()),
                  ),
                Positioned(
                  left: 4,
                  top: 4,
                  child: IconButton(
                    tooltip: _torchOn ? 'Torch off' : 'Torch on',
                    onPressed: _toggleTorch,
                    icon: Icon(
                      _torchOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 8,
                  child: Text(
                    _step.hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 6)],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: w, height: h, child: child),
        );
      },
    );
  }

  Widget _actions(int turns) {
    final busy = _capturing;
    final keepValues = _keptWithoutPhoto.contains(_step.id);
    final items = _hasPhoto
        ? [
            _Act('Next', Icons.arrow_forward, busy ? null : _next, filled: true),
            _Act('Retry', Icons.refresh, busy ? null : _retry),
            _Act(
              _inExtras ? 'Done' : 'Skip',
              _inExtras ? Icons.check : Icons.skip_next,
              busy ? null : _skip,
            ),
            _Act('Trash', Icons.delete_outline, busy ? null : _trash),
          ]
        : [
            _Act(
              'Take a photo',
              Icons.photo_camera,
              busy ? null : _take,
              filled: true,
            ),
            if (keepValues)
              _Act('Next', Icons.arrow_forward, busy ? null : _next, filled: true),
            _Act(
              _inExtras ? 'Done' : 'Skip',
              _inExtras ? Icons.check : Icons.skip_next,
              busy ? null : _skip,
            ),
          ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final style = Theme.of(context).textTheme.labelLarge ??
              const TextStyle(fontSize: 14);
          var longest = 0.0;
          for (final item in items) {
            final painter = TextPainter(
              text: TextSpan(text: item.label, style: style),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout();
            if (painter.width > longest) longest = painter.width;
          }
          final slotW =
              (constraints.maxWidth - 8 * (items.length - 1)) / items.length;
          final rotated = turns != 0;
          final textFits =
              longest + 40 <= slotW && (!rotated || (longest + 36) <= 168);
          final barH = !rotated
              ? null
              : textFits
                  ? longest + 36
                  : 64.0;
          return SizedBox(
            height: barH,
            child: Row(
              crossAxisAlignment: rotated
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: rotated
                        ? RotatedBox(
                            quarterTurns: turns,
                            child: textFits
                                ? _textButton(items[i])
                                : _iconButton(items[i]),
                          )
                        : textFits
                            ? _textButton(items[i])
                            : _iconButton(items[i]),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _textButton(_Act item) {
    if (item.filled) {
      return FilledButton.icon(
        onPressed: item.onPressed,
        icon: Icon(item.icon),
        label: Text(item.label),
      );
    }
    return FilledButton.tonalIcon(
      onPressed: item.onPressed,
      icon: Icon(item.icon),
      label: Text(item.label),
    );
  }

  Widget _iconButton(_Act item) {
    return IconButton(
      tooltip: item.label,
      onPressed: item.onPressed,
      icon: Icon(item.icon),
    );
  }
}

class _Act {
  const _Act(this.label, this.icon, this.onPressed, {this.filled = false});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;
}

/// Captured frame inside the portrait preview slot.
/// Opens at full width. Pinch out shows the rest of a tall frame.
class _ShotPhoto extends StatefulWidget {
  const _ShotPhoto({
    required this.path,
    required this.hold,
    required this.sensor,
    required this.front,
  });

  final String path;
  final DeviceOrientation? hold;
  final int sensor;
  final bool front;

  @override
  State<_ShotPhoto> createState() => _ShotPhotoState();
}

class _ShotPhotoState extends State<_ShotPhoto> {
  final _transform = TransformationController();
  ui.Image? _image;
  var _turns = 0;
  var _framedFor = '';

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(_ShotPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _image?.dispose();
      _image = null;
      _turns = 0;
      _framedFor = '';
      _decode();
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      final hold = widget.hold;
      final expected = hold == null
          ? 0
          : _photoQuarterTurns(hold, widget.sensor, widget.front);
      final swaps = expected.isOdd;
      final decodedPortrait = frame.image.height > frame.image.width;
      final turns = (swaps && decodedPortrait) || (!swaps && !decodedPortrait)
          ? (expected == 2 ? expected : 0)
          : expected;
      setState(() {
        _image?.dispose();
        _image = frame.image;
        _turns = turns;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null || image.width == 0 || image.height == 0) {
      return const Center(child: CircularProgressIndicator());
    }
    final dispW = _turns.isOdd ? image.height.toDouble() : image.width.toDouble();
    final dispH = _turns.isOdd ? image.width.toDouble() : image.height.toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxW = constraints.maxWidth;
        final boxH = constraints.maxHeight;
        if (boxW <= 0 || boxH <= 0 || dispW <= 0 || dispH <= 0) {
          return const SizedBox.shrink();
        }
        final childH = boxW * dispH / dispW;
        final seeAll = childH <= boxH ? 1.0 : boxH / childH;
        final fillHeight = childH <= 0 ? 1.0 : boxH / childH;
        final frameKey = '${widget.path}:${boxW.round()}x${boxH.round()}';
        if (_framedFor != frameKey) {
          _framedFor = frameKey;
          final dy = (boxH - childH) / 2;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _transform.value = Matrix4.translationValues(0, dy, 0);
          });
        }
        return ClipRect(
          child: InteractiveViewer(
            transformationController: _transform,
            constrained: false,
            alignment: Alignment.center,
            minScale: seeAll,
            maxScale: fillHeight < 1 ? 1 : fillHeight,
            child: SizedBox(
              width: boxW,
              height: childH,
              child: FittedBox(
                fit: BoxFit.fill,
                child: RotatedBox(
                  quarterTurns: _turns,
                  child: RawImage(
                    image: image,
                    width: image.width.toDouble(),
                    height: image.height.toDouble(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Same JPEG orientation the Android camera plugin writes.
int _photoQuarterTurns(DeviceOrientation device, int sensor, bool front) {
  final angle = switch (device) {
    DeviceOrientation.portraitUp => 90,
    DeviceOrientation.portraitDown => 270,
    DeviceOrientation.landscapeLeft => front ? 180 : 0,
    DeviceOrientation.landscapeRight => front ? 0 : 180,
  };
  return ((angle + sensor + 270) % 360) ~/ 90;
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
    canvas.drawRect(
      Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
      stroke,
    );
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
