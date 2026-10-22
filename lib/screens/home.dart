import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../widgets/booking_card.dart';
import 'book.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int tab = -1; // -1 = not decided yet
  Map<String, dynamic>? me;
  List<Map<String, dynamic>> bookings = [];
  Catalog? catalog;
  String? loadError;
  bool loading = true;
  Timer? timer;
  String lastSig = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    loadCatalog();
    timer = Timer.periodic(const Duration(seconds: 20), (_) => refresh(silent: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh(silent: true);
  }

  void toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> loadCatalog() async {
    try {
      final raw = await Api.i.catalog();
      if (mounted) setState(() => catalog = Catalog(raw));
    } catch (_) {}
  }

  Future<void> refresh({bool silent = false}) async {
    try {
      final r = await Future.wait([Api.i.me(), Api.i.myBookings()]);
      final cust = Map<String, dynamic>.from((r[0] as Map<String, dynamic>)['customer'] as Map);
      final bk = r[1] as List<Map<String, dynamic>>;
      final sig = bk.map((b) => '${b['id']}${b['status']}${(b['bids'] as List?)?.length ?? 0}${b['feedback'] != null}').join('|');
      if (silent && lastSig.isNotEmpty && sig != lastSig) toast('🔔 Your booking has an update');
      lastSig = sig;
      if (!mounted) return;
      setState(() {
        me = cust;
        bookings = bk;
        loading = false;
        loadError = null;
        if (tab == -1) tab = bk.any(isCurrent) ? 1 : 0;
      });
    } catch (x) {
      if (!mounted) return;
      final m = x is ApiError ? x.message : 'Could not load your data: $x';
      if (!silent || me == null) setState(() { loadError = m; loading = false; });
    }
  }

  Future<void> run(Future<void> Function() f, String ok) async {
    try {
      await f();
      toast(ok);
      await refresh();
    } on ApiError catch (x) {
      toast(x.message);
    }
  }

  Future<void> accept(String id, String techId) async {
    final yes = await confirm('Accept this quote?', 'The technician will get your number and address.');
    if (yes) run(() => Api.i.acceptBid(id, techId), '✅ Technician confirmed!');
  }

  Future<void> complete(String id) async {
    final yes = await confirm('Job completed?', 'Has the technician completed the job?');
    if (!yes) return;
    try {
      await Api.i.complete(id);
      await refresh();
      toast('🎉 Job marked completed');
      feedbackDialog(id);
    } on ApiError catch (x) {
      toast(x.message);
    }
  }

  Future<void> cancel(String id) async {
    final c = TextEditingController();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Reason (optional)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel booking')),
        ],
      ),
    );
    if (yes == true) run(() => Api.i.cancel(id, c.text.trim()), 'Booking cancelled');
  }

  Future<bool> confirm(String title, String body) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    return r == true;
  }

  Future<void> feedbackDialog(String id) async {
    String sat = '';
    int stars = 0;
    final remark = TextEditingController();
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('How was the service?'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('😊 Satisfied'), selected: sat == 'satisfied', onSelected: (_) => set(() => sat = 'satisfied')),
                ChoiceChip(label: const Text('😞 Unsatisfied'), selected: sat == 'unsatisfied', onSelected: (_) => set(() => sat = 'unsatisfied')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                for (var n = 1; n <= 5; n++)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    onPressed: () => set(() => stars = n),
                    icon: Icon(n <= stars ? Icons.star : Icons.star_border, color: const Color(0xFFF59E0B), size: 32),
                  ),
              ]),
              TextField(
                controller: remark,
                maxLength: 300,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Remark (optional)'),
              ),
              if (err != null) Text(err!, style: const TextStyle(color: Color(0xFFC0352B))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(90, 40)),
              onPressed: () async {
                if (sat.isEmpty) { set(() => err = 'Select your experience'); return; }
                if (stars == 0) { set(() => err = 'Please tap the stars to rate'); return; }
                try {
                  await Api.i.feedback(id, sat, stars, remark.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                  toast('🙏 Thank you for your feedback!');
                  refresh();
                } on ApiError catch (x) {
                  set(() => err = x.message);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget bookingList(List<Map<String, dynamic>> list, String empty, {Widget? emptyAction}) {
    return RefreshIndicator(
      onRefresh: () => refresh(),
      child: list.isEmpty
          ? ListView(padding: const EdgeInsets.all(30), children: [
              const SizedBox(height: 40),
              Text(empty, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 15)),
              if (emptyAction != null) Padding(padding: const EdgeInsets.only(top: 16), child: emptyAction),
            ])
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                for (final b in list)
                  BookingCard(b: b, onAccept: accept, onComplete: complete, onCancel: cancel, onFeedback: feedbackDialog),
              ],
            ),
    );
  }

  Widget feedbackTab() {
    final pend = bookings.where((b) => b['status'] == 'completed' && b['feedback'] == null).toList();
    final given = bookings.where((b) => b['feedback'] != null).toList();
    Widget head(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 8), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)));
    return RefreshIndicator(
      onRefresh: () => refresh(),
      child: ListView(padding: const EdgeInsets.all(14), children: [
        head('Feedback pending (${pend.length})'),
        if (pend.isEmpty) const Padding(padding: EdgeInsets.only(bottom: 14), child: Text('All jobs reviewed 👍', style: TextStyle(color: Colors.black54))),
        for (final b in pend)
          Card(
            elevation: 0,
            child: ListTile(
              title: Text(s(b['service']), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${s(b['techName'])} · ${s(b['schedule'])}'),
              trailing: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(70, 38), backgroundColor: const Color(0xFFF59E0B)),
                onPressed: () => feedbackDialog(s(b['id'])),
                child: const Text('Rate'),
              ),
            ),
          ),
        const SizedBox(height: 10),
        head('Feedback given (${given.length})'),
        if (given.isEmpty) const Text('No feedback given yet.', style: TextStyle(color: Colors.black54)),
        for (final b in given)
          Card(
            elevation: 0,
            child: ListTile(
              title: Text(s(b['techName']).isNotEmpty ? s(b['techName']) : s(b['service']), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${s(b['service'])}\n${'★' * ((b['feedback']['stars'] as num?)?.toInt() ?? 0)} · '
                '${b['feedback']['satisfaction'] == 'satisfied' ? 'Satisfied' : 'Unsatisfied'}'
                '${s(b['feedback']['remark']).isNotEmpty ? '\n“${s(b['feedback']['remark'])}”' : ''}',
              ),
              isThreeLine: true,
            ),
          ),
      ]),
    );
  }

  Future<void> editProfile() async {
    final name = TextEditingController(text: s(me?['name']));
    final loc = TextEditingController(text: s(me?['location']));
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Edit profile'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name *')),
            const SizedBox(height: 10),
            TextField(controller: loc, decoration: const InputDecoration(labelText: 'Location *')),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Color(0xFFC0352B)))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(80, 40)),
              onPressed: () async {
                try {
                  await Api.i.updateProfile(name.text.trim(), loc.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                  toast('✅ Profile updated');
                  refresh();
                } on ApiError catch (x) {
                  set(() => err = x.message);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget profileTab() {
    final done = bookings.where((b) => b['status'] == 'completed').length;
    final fb = bookings.where((b) => b['feedback'] != null).length;
    Widget stat(String n, String l) => Expanded(
        child: Card(
            elevation: 0,
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(children: [
                  Text(n, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F766E))),
                  Text(l, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ]))));
    return ListView(padding: const EdgeInsets.all(14), children: [
      Card(
        elevation: 0,
        child: Column(children: [
          ListTile(leading: const Icon(Icons.person_outline), title: Text(s(me?['name'])), subtitle: const Text('Name')),
          ListTile(leading: const Icon(Icons.phone_outlined), title: Text(s(me?['mobile'])), subtitle: const Text('Mobile')),
          ListTile(leading: const Icon(Icons.place_outlined), title: Text(s(me?['location'])), subtitle: const Text('Location')),
          ListTile(leading: const Icon(Icons.event_outlined), title: Text(fmtDay(me?['createdAt'])), subtitle: const Text('Member since')),
        ]),
      ),
      Row(children: [stat('${bookings.length}', 'Total bookings'), stat('$done', 'Completed'), stat('$fb', 'Feedback given')]),
      const SizedBox(height: 8),
      OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: editProfile,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit profile')),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: const Color(0xFFC0352B)),
        onPressed: () async {
          if (!await confirm('Logout?', 'You will need your mobile and PIN to log in again.')) return;
          await Api.i.saveToken(null);
          widget.onLogout();
        },
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
      ),
      const SizedBox(height: 16),
      const Center(child: Text('Lifeline Customer · v1.0.0', style: TextStyle(color: Colors.black38, fontSize: 12))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cur = bookings.where(isCurrent).toList();
    final hist = bookings.where((b) => !isCurrent(b)).toList();
    final pend = bookings.where((b) => b['status'] == 'completed' && b['feedback'] == null).length;
    final first = s(me?['name']).split(' ').first;

    Widget body;
    if (tab == -1 && loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (loadError != null && me == null) {
      body = Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
                    onPressed: () { setState(() { loading = true; loadError = null; }); refresh(); },
                    child: const Text('Retry')),
              ])));
    } else {
      switch (tab) {
        case 0:
          body = BookScreen(
            catalog: catalog,
            onBooked: () async {
              await refresh();
              if (mounted) setState(() => tab = 1);
              toast('✅ Service booked! Technicians will send quotes soon.');
            },
            onRetryCatalog: loadCatalog,
          );
          break;
        case 1:
          body = bookingList(cur, 'No active booking right now.',
              emptyAction: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(200, 46)),
                  onPressed: () => setState(() => tab = 0),
                  child: const Text('Book a new service')));
          break;
        case 2:
          body = bookingList(hist, 'No past bookings yet. Completed and cancelled bookings appear here.');
          break;
        case 3:
          body = feedbackTab();
          break;
        default:
          body = profileTab();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(first.isEmpty ? 'Lifeline' : 'Hi, $first 👋', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (me != null) Text('📍 ${s(me!['location'])}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab < 0 ? 0 : tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Book'),
          NavigationDestination(
              icon: Badge(isLabelVisible: cur.isNotEmpty, label: Text('${cur.length}'), child: const Icon(Icons.assignment_outlined)),
              selectedIcon: const Icon(Icons.assignment),
              label: 'Current'),
          const NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
              icon: Badge(isLabelVisible: pend > 0, label: Text('$pend'), child: const Icon(Icons.star_border)),
              selectedIcon: const Icon(Icons.star),
              label: 'Feedback'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
