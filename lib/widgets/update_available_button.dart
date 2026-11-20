import 'package:flutter/material.dart';

import '../services/app_update.dart';

/// Top-right control shown only when GitHub has a newer build.
class UpdateAvailableButton extends StatelessWidget {
  const UpdateAvailableButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const dot = Color(0xFFE85D04);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('update-available'),
      tooltip: 'Update',
      onPressed: onPressed,
      icon: const Badge(
        smallSize: 8,
        backgroundColor: dot,
        child: Icon(Icons.system_update_alt),
      ),
    );
  }
}

/// Download and hand the APK to the system installer.
class UpdateOfferSheet extends StatefulWidget {
  const UpdateOfferSheet({super.key, required this.offer});

  final AppUpdateOffer offer;

  @override
  State<UpdateOfferSheet> createState() => _UpdateOfferSheetState();
}

class _UpdateOfferSheetState extends State<UpdateOfferSheet> {
  var _downloading = false;
  double? _progress;
  String? _note;

  Future<void> _download() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _note = null;
    });
    try {
      final file = await AppUpdate.download(widget.offer, (progress) {
        if (!mounted) return;
        setState(() => _progress = progress);
      });
      await AppUpdate.install(file);
      if (!mounted) return;
      setState(() => _note = 'Confirm the install on the next screen.');
    } on InstallPermissionNeeded {
      if (!mounted) return;
      setState(() {
        _note = 'Allow WheelShot to install apps, then tap Download again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _note = 'Update failed. $e');
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Update ${widget.offer.label}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'A newer WheelShot is on GitHub.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                  ),
            ),
            if (_note != null) ...[
              const SizedBox(height: 8),
              Text(_note!),
            ],
            if (_downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _downloading ? null : _download,
              child:
                  Text(_downloading ? 'Downloading…' : 'Download and install'),
            ),
          ],
        ),
      ),
    );
  }
}
