import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/shoot_plan.dart';
import '../route_observer.dart';
import '../services/session_store.dart';
import 'done_screen.dart';
import 'specs_screen.dart';
import 'wizard_screen.dart';

class PastShootsScreen extends StatefulWidget {
  const PastShootsScreen({super.key});

  @override
  State<PastShootsScreen> createState() => _PastShootsScreenState();
}

class _PastShootsScreenState extends State<PastShootsScreen> with RouteAware {
  late Future<List<PastSession>> _past;

  @override
  void initState() {
    super.initState();
    _past = SessionStore.listPastSessions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _reload();
  }

  Future<void> _reload() async {
    final next = SessionStore.listPastSessions();
    setState(() {
      _past = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Past shoots')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<PastSession>>(
          future: _past,
          builder: (context, snap) {
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Could not read past shoots.\n${snap.error}'),
                  ),
                ],
              );
            }
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No shoots yet.'),
                  ),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                for (final s in items) ...[
                  PastShootCard(
                    session: s,
                    onTap: () => openPastAction(context, s, 'open').then((_) {
                      if (mounted) _reload();
                    }),
                    onPhotos: () =>
                        openPastAction(context, s, 'photos').then((_) {
                      if (mounted) _reload();
                    }),
                    onSpecs: () =>
                        openPastAction(context, s, 'specs').then((_) {
                      if (mounted) _reload();
                    }),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<void> openPastAction(
  BuildContext context,
  PastSession s,
  String action,
) async {
  final store = await SessionStore.openExisting(s.name);
  if (store == null || !context.mounted) return;
  switch (action) {
    case 'photos':
      final captures = await store.existingCaptures();
      if (!context.mounted) return;
      final steps = buildWizard(
        category: store.category,
        config: store.config ?? const ShootConfig(),
        spareHasRim: store.spareHasRim,
        etNotes: store.dezentNotes,
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WizardScreen(
            store: store,
            steps: steps,
            initialCaptures: captures,
          ),
        ),
      );
    case 'specs':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SpecsScreen(store: store)),
      );
    default:
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DoneScreen(store: store)),
      );
  }
}

class PastShootCard extends StatelessWidget {
  const PastShootCard({
    super.key,
    required this.session,
    required this.onTap,
    required this.onPhotos,
    required this.onSpecs,
  });

  final PastSession session;
  final VoidCallback onTap;
  final VoidCallback onPhotos;
  final VoidCallback onSpecs;

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

    return Material(
      color: const Color(0xFF1C1F28),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: session.thumbPath == null
                      ? ColoredBox(
                          color: Colors.white10,
                          child: Icon(
                            Icons.photo_library_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : Image.file(
                          File(session.thumbPath!),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Photos',
                onPressed: onPhotos,
                icon: const Icon(Icons.photo_library),
              ),
              IconButton(
                tooltip: 'Specs',
                onPressed: onSpecs,
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
