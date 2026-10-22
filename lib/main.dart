import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'screens/auth.dart';
import 'screens/home.dart';

const kPrimary = Color(0xFF0F766E);
const kAccent = Color(0xFFF59E0B);

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
    try {
      await Api.i.loadToken().timeout(const Duration(seconds: 5));
    } catch (_) {}
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
        scaffoldBackgroundColor: const Color(0xFFF4F7F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      home: !ready
          ? const Scaffold(
              backgroundColor: kPrimary,
              body: Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          : loggedIn
          ? HomeScreen(onLogout: () => setState(() => loggedIn = false))
          : AuthScreen(onDone: () => setState(() => loggedIn = true)),
    );
  }
}
