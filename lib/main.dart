import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'screens/splash.dart';
import 'theme.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    // Show the error on screen instead of a blank page, so problems are visible.
    ErrorWidget.builder = (details) => Material(
          color: Colors.white,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Text('Error: ${details.exceptionAsString()}',
                    style: const TextStyle(color: Colors.red, fontSize: 14)),
              ),
            ),
          ),
        );
    runApp(const LifelineApp());
  }, (error, stack) {});
}

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

class LifelineApp extends StatefulWidget {
  const LifelineApp({super.key});
  @override
  State<LifelineApp> createState() => _LifelineAppState();
}

class _LifelineAppState extends State<LifelineApp> {
  bool ready = false;
  bool loggedIn = false;

  Future<void> _boot() async {
    // Load the saved login and keep the opening screen visible for a few seconds.
    await Future.wait([
      Api.i.loadToken().timeout(const Duration(seconds: 5), onTimeout: () {}).catchError((_) {}),
      Future<void>.delayed(const Duration(milliseconds: 2800)),
    ]);
    if (mounted) {
      setState(() {
        loggedIn = Api.i.token != null;
        ready = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _boot();
    Api.i.onUnauthorized = () {
      Api.i.saveToken(null);
      if (mounted) setState(() => loggedIn = false);
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lifeline',
      debugShowCheckedModeBanner: false,
      navigatorKey: navKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary, primary: kPrimary, secondary: kAccent),
        scaffoldBackgroundColor: kBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: kDark,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: kPrimary.withOpacity(0.14),
          labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
                fontSize: 12,
                fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
                color: s.contains(WidgetState.selected) ? kPrimary : Colors.black54,
              )),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD5DEE8))),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kPrimary,
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: !ready
          ? const SplashScreen()
          : loggedIn
              ? HomeScreen(onLogout: () => setState(() => loggedIn = false))
              : AuthScreen(onDone: () => setState(() => loggedIn = true)),
    );
  }
}
