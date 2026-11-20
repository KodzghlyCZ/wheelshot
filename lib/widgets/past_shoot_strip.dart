import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/session_store.dart';

/// Home preview: three thumbnails, then a grid button when more exist.
class PastShootStrip extends StatelessWidget {
  const PastShootStrip({
    super.key,
    required this.sessions,
    required this.onThumb,
    required this.onShowAll,
  });

  static const previewCount = 3;

  final List<PastSession> sessions;
  final ValueChanged<PastSession> onThumb;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final shown = sessions.take(previewCount).toList();
    final extra = sessions.length > previewCount;
    final count = shown.length + (extra ? 1 : 0);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final side = count == 0
            ? 0.0
            : math.min(
                92.0,
                (constraints.maxWidth - gap * (count - 1)) / count,
              );
        return Row(
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              _Thumb(
                session: shown[i],
                side: side,
                onTap: () => onThumb(shown[i]),
              ),
            ],
            if (extra) ...[
              const SizedBox(width: gap),
              _AllButton(side: side, onTap: onShowAll),
            ],
          ],
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.session,
    required this.side,
    required this.onTap,
  });

  final PastSession session;
  final double side;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final path = session.thumbPath;
    return Tooltip(
      message: session.name,
      child: Material(
        color: const Color(0xFF1C1F28),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('past-thumb-${session.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: side,
              height: side,
              child: path == null
                  ? Icon(
                      Icons.photo_library_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : Image.file(File(path), fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }
}

class _AllButton extends StatelessWidget {
  const _AllButton({required this.side, required this.onTap});

  final double side;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1C1F28),
      borderRadius: BorderRadius.circular(14),
      child: Tooltip(
        message: 'All shoots',
        child: InkWell(
          key: const ValueKey('past-all'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: side,
            height: side,
            child: const Icon(Icons.grid_view_rounded, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

/// Sheet opened from a home thumbnail.
class PastEditSheet extends StatelessWidget {
  const PastEditSheet({super.key, required this.session});

  final PastSession session;

  @override
  Widget build(BuildContext context) {
    final when = session.modified == null
        ? null
        : DateFormat('d.M.yyyy HH:mm').format(session.modified!.toLocal());
    final subtitle = [
      if (session.title != null && session.title!.isNotEmpty) session.title!,
      '${session.photoCount} photo${session.photoCount == 1 ? '' : 's'}',
      if (when != null) when,
    ].join(' · ');

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              session.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                    ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Photos'),
            onTap: () => Navigator.pop(context, 'photos'),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Specs'),
            onTap: () => Navigator.pop(context, 'specs'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Open'),
            onTap: () => Navigator.pop(context, 'open'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
