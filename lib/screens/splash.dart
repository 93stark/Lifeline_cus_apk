import 'package:flutter/material.dart';
import '../theme.dart';

/// Opening screen shown for a few seconds when the app starts.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
  late final Animation<double> logo = CurvedAnimation(parent: c, curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack));
  late final Animation<double> logoFade = CurvedAnimation(parent: c, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
  late final Animation<double> title = CurvedAnimation(parent: c, curve: const Interval(0.35, 0.75, curve: Curves.easeOut));
  late final Animation<double> tag = CurvedAnimation(parent: c, curve: const Interval(0.55, 1.0, curve: Curves.easeOut));

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kDark, Color(0xFF14497A), kPrimary]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              ScaleTransition(
                scale: Tween<double>(begin: 0.6, end: 1).animate(logo),
                child: FadeTransition(
                  opacity: logoFade,
                  child: const LogoMark(size: 170, glow: true),
                ),
              ),
              const SizedBox(height: 26),
              FadeTransition(
                opacity: title,
                child: const Text('LIFELINE',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 6)),
              ),
              const SizedBox(height: 14),
              FadeTransition(
                opacity: tag,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(children: [
                    const Text(
                      'Your trusted platform and our verified technicians',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16, height: 1.4, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(20)),
                      child: const Text('Lifeline App',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ),
                  ]),
                ),
              ),
              const Spacer(flex: 3),
              const SizedBox(
                  height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70)),
              const SizedBox(height: 14),
              const Text('Verified • Local • Fast', style: TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }
}
