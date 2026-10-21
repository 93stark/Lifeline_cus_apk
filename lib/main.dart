import 'package:flutter/material.dart';
import 'api.dart';
import 'screens/auth.dart';
import 'screens/home.dart';

const kPrimary = Color(0xFF0F766E);
const kAccent = Color(0xFFF59E0B);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.i.loadToken();
  runApp(const LifelineApp());
}

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

class LifelineApp extends StatefulWidget {
  const LifelineApp({super.key});
  @override
  State<LifelineApp> createState() => _LifelineAppState();
}

class _LifelineAppState extends State<LifelineApp> {
  bool loggedIn = Api.i.token != null;

  @override
  void initState() {
    super.initState();
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
      home: loggedIn
          ? HomeScreen(onLogout: () => setState(() => loggedIn = false))
          : AuthScreen(onDone: () => setState(() => loggedIn = true)),
    );
  }
}
