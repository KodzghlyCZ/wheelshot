import 'dart:io';

import 'package:flutter/material.dart';

import '../models/shoot_plan.dart';
import '../services/session_store.dart';
import '../widgets/confirm_leave.dart';
import 'camera_screen.dart';
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

  /// Show "Looks good" / "Retake" after each shot instead of auto-advancing.
  final bool reviewAfterCapture;

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  late List<ShotStep> _steps;
  int _index = 0;
  final Map<String, String> _captured = {};
  bool _extrasMode = false;
  int _extraCount = 0;
  bool _awaitingReview = false;

  ShotStep get _step => _steps[_index];
  bool get _isLastRequired =>
      !_extrasMode && _index >= widget.steps.length - 1;
  bool get _inExtras => _extrasMode;

  @override
  void initState() {
    super.initState();
    _steps = List.of(widget.steps);
    final initial = widget.initialCaptures;
    if (initial != null) _captured.addAll(initial);
  }

  void _goSpecs() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SpecsScreen(store: widget.store),
      ),
    );
  }

  void _enterExtras() {
    // Start after any extra_NN photos that already exist (edit mode).
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
  }

  Future<void> _shoot() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CameraScreen(step: _step),
        fullscreenDialog: true,
      ),
    );
    if (path == null || !mounted) return;

    final file = await widget.store.saveCapture(
      stepId: _step.id,
      sourcePath: path,
    );
    await FileImage(file).evict();
    if (!mounted) return;
    setState(() {
      _captured[_step.id] = file.path;
      _awaitingReview = widget.reviewAfterCapture;
    });
    if (widget.reviewAfterCapture) return;
    _advance();
  }

  void _approve() {
    setState(() => _awaitingReview = false);
    _advance();
  }

  Future<void> _retake() async {
    final id = _step.id;
    final path = _captured[id];
    if (path != null) {
      await FileImage(File(path)).evict();
      try {
        await File(path).delete();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _captured.remove(id);
      _awaitingReview = false;
    });
    await _shoot();
  }

  void _advance() {
    if (_inExtras) {
      // Queue next extra slot so another shoot is one tap away.
      setState(() {
        _extraCount++;
        _steps = [..._steps, extraShotStep(_extraCount)];
        _index = _steps.length - 1;
      });
      return;
    }

    if (_isLastRequired) {
      _enterExtras();
    } else {
      setState(() => _index++);
    }
  }

  void _skipOrDone() {
    if (_inExtras) {
      _goSpecs();
      return;
    }
    if (_isLastRequired) {
      _enterExtras();
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requiredTotal = widget.steps.length;
    final preview = _captured[_step.id];
    final progress = _inExtras
        ? 1.0
        : (_index + 1) / requiredTotal.clamp(1, 999);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await leaveToHome(context);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.store.sessionName),
        actions: [
          TextButton(
            onPressed: () => leaveToHome(context),
            child: const Text('Exit'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    _inExtras
                        ? 'Extra photos'
                        : 'Step ${_index + 1} / $requiredTotal',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white60,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    _inExtras
                        ? 'optional'
                        : '${(progress * 100).round()}%',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _step.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                _step.hint,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1F28),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: preview != null
                      ? Image.file(File(preview), fit: BoxFit.cover)
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _guideLabel(_step.guide),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: Colors.white38),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              if (_awaitingReview && preview != null) ...[
                FilledButton.icon(
                  onPressed: _approve,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E9E5B),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.thumb_up),
                  label: const Text('Looks good'),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: _retake,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake'),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: _shoot,
                  icon: const Icon(Icons.photo_camera),
                  label: Text(
                    _inExtras
                        ? (preview == null ? 'Open camera' : 'Shoot another')
                        : (preview == null ? 'Open camera' : 'Retake'),
                  ),
                ),
                const SizedBox(height: 10),
                if (_inExtras) ...[
                  FilledButton.tonal(
                    onPressed: _goSpecs,
                    child: const Text('Done'),
                  ),
                ] else if (preview != null && !_isLastRequired)
                  FilledButton.tonal(
                    onPressed: () => setState(() => _index++),
                    child: const Text('Next shot'),
                  )
                else if (preview != null && _isLastRequired)
                  FilledButton.tonal(
                    onPressed: _enterExtras,
                    child: const Text('Continue'),
                  )
                else
                  TextButton(
                    onPressed: _skipOrDone,
                    child: const Text('Skip this shot'),
                  ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  String _guideLabel(ShotGuide g) => switch (g) {
        ShotGuide.overallFrame => 'Frame the whole item / set',
        ShotGuide.treadSurface => 'Fill frame with tread',
        ShotGuide.dotCloseup => 'DOT oval · 4 digits',
        ShotGuide.sidewallSize => 'Size line must be sharp',
        ShotGuide.rimStamp => 'Stamp / casting marks',
        ShotGuide.none => 'Ready when you are',
      };
}
