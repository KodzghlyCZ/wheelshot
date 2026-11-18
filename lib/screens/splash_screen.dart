import 'package:flutter/material.dart';

import 'home_screen.dart';

/// Launch screen: bounce-in Karlos, then zoom+fade into the app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _exit;
  late final Animation<double> _bounce;
  late final Animation<double> _enterFade;
  late final Animation<double> _zoom;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _bounce = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _enter, curve: Curves.elasticOut),
    );
    _enterFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _zoom = Tween<double>(begin: 1.0, end: 2.15).animate(
      CurvedAnimation(parent: _exit, curve: Curves.easeInCubic),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exit, curve: Curves.easeIn),
    );

    _play();
  }

  Future<void> _play() async {
    await _enter.forward();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    await _exit.forward();
    if (!mounted) return;
    _goHome();
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _enter.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF12141A);
    return Scaffold(
      backgroundColor: ink,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_enter, _exit]),
          builder: (context, _) {
            final scale = _bounce.value * _zoom.value;
            final opacity = _enterFade.value * _exitFade.value;
            final textOpacity = _enterFade.value * (1.0 - _exit.value);

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: scale,
                          child: Image.asset(
                            'assets/brand/karlos.png',
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Opacity(
                      opacity: textOpacity.clamp(0.0, 1.0),
                      child: Text(
                        'Sponsored by Karlos',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                  color: Colors.white,
                                ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
