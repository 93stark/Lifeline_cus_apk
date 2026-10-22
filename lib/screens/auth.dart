import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets/booking_card.dart' show openUrl;

class AuthScreen extends StatefulWidget {
  final VoidCallback onDone;
  const AuthScreen({super.key, required this.onDone});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool signup = false, busy = false, hidePin = true;
  String? error = Api.i.pendingMsg;
  final name = TextEditingController();
  final mobile = TextEditingController();
  final location = TextEditingController();
  final pin = TextEditingController();

  String normMobile(String v) {
    var d = v.replaceAll(RegExp(r'\D'), '');
    if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
    if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
    return d;
  }

  void forgotPin() {
    final m = normMobile(mobile.text);
    final msg = Uri.encodeComponent(
        'Hello Lifeline, I forgot my PIN. Please reset it.${m.length == 10 ? ' My registered mobile: $m' : ''}');
    openUrl('https://wa.me/917797493140?text=$msg');
  }

  Future<void> submit() async {
    final m = normMobile(mobile.text);
    final p = pin.text.trim();
    String? e;
    if (signup && name.text.trim().length < 2) {
      e = 'Please enter your full name';
    } else if (!RegExp(r'^[6-9]\d{9}$').hasMatch(m)) {
      e = 'Enter a valid 10-digit mobile number';
    } else if (signup && location.text.trim().isEmpty) {
      e = 'Please enter your location / address';
    } else if (!RegExp(r'^\d{4}$').hasMatch(p)) {
      e = signup ? 'Set a 4-digit PIN (used to log in later)' : 'Enter your 4-digit PIN';
    }
    if (e != null) {
      setState(() => error = e);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = signup
          ? await Api.i.signup(name.text.trim(), m, location.text.trim(), p)
          : await Api.i.login(m, p);
      final tk = r['token'];
      if (tk is! String || tk.isEmpty) {
        setState(() => error = 'Login reply had no token: ${r.keys.join(', ')}');
        return;
      }
      Api.i.pendingMsg = null;
      await Api.i.saveToken(tk);
      widget.onDone();
    } on ApiError catch (x) {
      setState(() => error = x.message);
    } catch (x) {
      setState(() => error = 'Unexpected error: $x');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + (kb ? 10 : 26), 20, kb ? 14 : 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kDark, kPrimary]),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
            ),
            child: Column(children: [
              LogoMark(size: kb ? 56 : 110, glow: true),
              SizedBox(height: kb ? 6 : 14),
              const Text('LIFELINE',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 4)),
              if (!kb) ...const [
                SizedBox(height: 6),
                Text('Your trusted platform and our verified technicians',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13.5)),
              ],
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<bool>(
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: kPrimary,
                          selectedForegroundColor: Colors.white,
                          backgroundColor: Colors.white,
                        ),
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: false, label: Text('Login')),
                          ButtonSegment(value: true, label: Text('Create account')),
                        ],
                        selected: {signup},
                        onSelectionChanged: (v) => setState(() {
                          signup = v.first;
                          error = null;
                        }),
                      ),
                      const SizedBox(height: 18),
                      if (signup) ...[
                        TextField(
                          controller: name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Full name *', prefixIcon: Icon(Icons.person_outline)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: mobile,
                        keyboardType: TextInputType.phone,
                        maxLength: 13,
                        decoration: const InputDecoration(
                            labelText: 'Mobile number *', prefixIcon: Icon(Icons.phone_outlined), counterText: ''),
                      ),
                      const SizedBox(height: 12),
                      if (signup) ...[
                        TextField(
                          controller: location,
                          decoration: const InputDecoration(
                              labelText: 'Location *',
                              hintText: 'Area / city, e.g. Purulia',
                              prefixIcon: Icon(Icons.place_outlined)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: pin,
                        keyboardType: TextInputType.number,
                        obscureText: hidePin,
                        maxLength: 4,
                        decoration: InputDecoration(
                          labelText: signup ? 'Set 4-digit PIN *' : '4-digit PIN *',
                          helperText: signup ? 'You will use mobile + PIN to log in next time' : null,
                          counterText: '',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(hidePin ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => hidePin = !hidePin),
                          ),
                        ),
                      ),
                      if (!signup)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(onPressed: forgotPin, child: const Text('Forgot PIN?')),
                        ),
                      if (error != null)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(10)),
                          child: Text(error!, style: const TextStyle(color: Color(0xFFC0352B))),
                        ),
                      const SizedBox(height: 18),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: kAccent),
                        onPressed: busy ? null : submit,
                        child: busy
                            ? const SizedBox(
                                height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Text(signup ? 'Create account' : 'Login'),
                      ),
                      const SizedBox(height: 14),
                      const Text('100% free for customers  ·  app v1.1.0',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.black45, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
