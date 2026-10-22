import 'package:flutter/material.dart';

// Colours taken from the Lifeline logo (steel blue + silver) with a warm orange accent.
const kPrimary = Color(0xFF1F5F99);
const kDark = Color(0xFF0B2A4A);
const kAccent = Color(0xFFFF9800);
const kBg = Color(0xFFF2F6FA);

const kGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kDark, kPrimary],
);

/// The round Lifeline logo.
class LogoMark extends StatelessWidget {
  final double size;
  final bool glow;
  const LogoMark({super.key, this.size = 40, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: glow
            ? [BoxShadow(color: Colors.white.withOpacity(0.35), blurRadius: size * 0.35, spreadRadius: size * 0.02)]
            : [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Image.asset('assets/logo.png', width: size, height: size, fit: BoxFit.contain),
    );
  }
}
