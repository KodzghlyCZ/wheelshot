import 'package:flutter/material.dart';

import '../route_observer.dart';
import '../models/shoot_plan.dart';
import '../services/session_store.dart';
import '../widgets/past_shoot_strip.dart';
import 'past_shoots_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
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

  /// Setup is replaced by the wizard, so the push from home completes
  /// before the shoot is finished. Reload when this route is shown again.
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

  Future<void> _editMenu(PastSession s) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => PastEditSheet(session: s),
    );
    if (action == null || !mounted) return;
    await openPastAction(context, s, action);
    if (mounted) _reload();
  }

  Future<void> _showAll() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PastShootsScreen()),
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
            physics: const AlwaysScrollableScrollPhysics(),
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
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Could not read past shoots.\n${snap.error}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white54,
                            ),
                      ),
                    );
                  }
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
                  return PastShootStrip(
                    sessions: items,
                    onThumb: _editMenu,
                    onShowAll: _showAll,
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
                child:
                    Icon(_icon, color: Theme.of(context).colorScheme.primary),
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
