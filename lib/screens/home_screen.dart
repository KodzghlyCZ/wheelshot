import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/shoot_plan.dart';
import '../services/session_store.dart';
import 'done_screen.dart';
import 'setup_screen.dart';
import 'specs_screen.dart';
import 'wizard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<PastSession>> _past;

  @override
  void initState() {
    super.initState();
    _past = SessionStore.listPastSessions();
  }

  Future<void> _reload() async {
    setState(() => _past = SessionStore.listPastSessions());
    await _past;
  }

  Future<void> _openPast(PastSession s) async {
    final store = await SessionStore.openExisting(s.name);
    if (store == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DoneScreen(store: store)),
    );
    if (mounted) _reload();
  }

  Future<void> _editPhotos(PastSession s) async {
    final store = await SessionStore.openExisting(s.name);
    if (store == null || !mounted) return;
    final captures = await store.existingCaptures();
    if (!mounted) return;
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
    if (mounted) _reload();
  }

  Future<void> _editSpecs(PastSession s) async {
    final store = await SessionStore.openExisting(s.name);
    if (store == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SpecsScreen(store: store)),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            children: [
              Text(
                'WheelShot',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Guided photos for tires & rims. Pick what you’re shooting.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 28),
              for (final cat in ShootCategory.values) ...[
                _CategoryCard(
                  category: cat,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SetupScreen(category: cat),
                      ),
                    );
                    if (mounted) _reload();
                  },
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              Text(
                'Past shoots',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<PastSession>>(
                future: _past,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No shoots yet — finish a wizard and they’ll show up here.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white54,
                            ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final s in items) ...[
                        _PastCard(
                          session: s,
                          onTap: () => _openPast(s),
                          onPhotos: () => _editPhotos(s),
                          onSpecs: () => _editSpecs(s),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PastCard extends StatelessWidget {
  const _PastCard({
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final ShootCategory category;
  final VoidCallback onTap;

  IconData get _icon => switch (category) {
        ShootCategory.wheelSet => Icons.directions_car_filled_outlined,
        ShootCategory.rimsOnly => Icons.album_outlined,
        ShootCategory.tiresOnly => Icons.donut_large,
        ShootCategory.spare => Icons.miscellaneous_services_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1C1F28),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
