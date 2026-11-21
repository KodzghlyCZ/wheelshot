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
  AppUpdateDownload? _job;

  @override
  void initState() {
    super.initState();
    final active = AppUpdate.activeDownload;
    if (active != null &&
        active.offer.versionCode == widget.offer.versionCode &&
        active.offer.apkUrl == widget.offer.apkUrl) {
      _attach(active);
    }
  }

  @override
  void dispose() {
    _job?.removeListener(_onJob);
    super.dispose();
  }

  void _attach(AppUpdateDownload job) {
    _job?.removeListener(_onJob);
    _job = job;
    _job!.addListener(_onJob);
  }

  void _onJob() {
    if (mounted) setState(() {});
  }

  void _download() {
    _attach(AppUpdate.beginDownload(widget.offer));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final busy = job?.busy == true;
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
              'A newer WheelShot is on GitHub. You can leave the app while it downloads.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                  ),
            ),
            if (job?.note != null) ...[
              const SizedBox(height: 8),
              Text(job!.note!),
            ],
            if (busy) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: job?.progress),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : _download,
              child: Text(busy ? 'Downloading…' : 'Download and install'),
            ),
          ],
        ),
      ),
    );
  }
}
