import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/banner_carousel.dart';

class BookScreen extends StatefulWidget {
  final Catalog? catalog;
  final Future<void> Function() onBooked;
  final Future<void> Function() onRetryCatalog;
  const BookScreen({super.key, required this.catalog, required this.onBooked, required this.onRetryCatalog});
  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  String? catId, subId, leafId;
  final qty = TextEditingController(text: '1');
  final budget = TextEditingController();
  final addr = TextEditingController();
  final landmark = TextEditingController();
  final notes = TextEditingController();
  DateTime date = DateTime.now();
  TimeOfDay? time;
  Map<String, dynamic>? geo;
  String autoAddr = '';
  String? gpsMsg;
  bool gpsBusy = false, busy = false;
  String? error;

  Catalog? get cat => widget.catalog;

  Map<String, dynamic>? get curCat {
    if (cat == null || cat!.cats.isEmpty) return null;
    return cat!.cats.firstWhere((c) => c['id'] == catId, orElse: () => cat!.cats.first);
  }

  List<Map<String, dynamic>> get subs =>
      ((curCat?['subs'] as List?) ?? []).cast<Map<String, dynamic>>();

  Map<String, dynamic>? get curSub {
    if (subs.isEmpty) return null;
    return subs.firstWhere((x) => x['id'] == subId, orElse: () => subs.first);
  }

  List<Leaf> get leaves => ((curSub?['leaves'] as List?) ?? []).cast<Leaf>();

  Leaf? get curLeaf {
    if (leaves.isEmpty) return null;
    return leaves.firstWhere((l) => l.id == leafId, orElse: () => leaves.first);
  }

  int get q => (int.tryParse(qty.text.trim()) ?? 1).clamp(1, 100);

  String two(int n) => n.toString().padLeft(2, '0');
  String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

  Future<void> pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: date.isBefore(DateTime(now.year, now.month, now.day)) ? now : date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (d != null) setState(() => date = d);
  }

  Future<void> pickTime() async {
    final t = await showTimePicker(context: context, initialTime: time ?? const TimeOfDay(hour: 10, minute: 0));
    if (t != null) setState(() => time = t);
  }

  String? slotError() {
    if (time == null) return 'Select the booking time';
    final mins = time!.hour * 60 + time!.minute;
    if (mins < 480 || mins > 1200) return 'Please choose a time between 8:00 AM and 8:00 PM.';
    final at = DateTime(date.year, date.month, date.day, time!.hour, time!.minute);
    if (at.isBefore(DateTime.now())) return 'This time has already passed. Choose a later time.';
    return null;
  }

  Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final r = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=18&addressdetails=1&accept-language=en'),
        headers: {'User-Agent': 'LifelineCustomerApp/1.0'},
      ).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
        final a = (j['address'] as Map?)?.cast<String, dynamic>() ?? {};
        final parts = <String>[
          if (a['road'] != null) '${a['house_number'] != null ? '${a['house_number']} ' : ''}${a['road']}',
          (a['neighbourhood'] ?? a['suburb'] ?? a['quarter'] ?? '').toString(),
          (a['village'] ?? a['hamlet'] ?? '').toString(),
          (a['town'] ?? a['city'] ?? a['municipality'] ?? '').toString(),
          (a['state_district'] ?? a['county'] ?? '').toString(),
          (a['state'] ?? '').toString(),
          (a['postcode'] ?? '').toString(),
        ].where((e) => e.isNotEmpty).toSet().toList();
        if (parts.isNotEmpty) return parts.join(', ');
        return (j['display_name'] ?? '').toString();
      }
    } catch (_) {}
    return '';
  }

  Future<void> useGps() async {
    setState(() {
      gpsBusy = true;
      gpsMsg = 'Getting your location… allow location access if asked.';
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => gpsMsg = '⚠️ Location is off. Turn on GPS / Location on your phone and try again.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() => gpsMsg = '⚠️ Location permission denied. Allow it in phone settings, or type the address.');
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      geo = {'lat': p.latitude, 'lng': p.longitude, 'acc': p.accuracy.round()};
      setState(() => gpsMsg = 'Location found (±${p.accuracy.round()} m). Fetching address…');
      final a = await reverseGeocode(p.latitude, p.longitude);
      if (a.isNotEmpty) {
        if (addr.text.trim().isEmpty || addr.text == autoAddr) {
          addr.text = a;
          autoAddr = a;
        }
        setState(() => gpsMsg = '✅ Address filled from GPS (±${p.accuracy.round()} m). Please check it and add house no. / landmark.');
      } else {
        setState(() => gpsMsg = '📍 Location saved, but address could not be read. Please type your address.');
      }
    } catch (_) {
      setState(() => gpsMsg = '⚠️ Could not get location. Please type the address.');
    } finally {
      if (mounted) setState(() => gpsBusy = false);
    }
  }

  Future<void> submit() async {
    final leaf = curLeaf;
    String? e;
    if (leaf == null) {
      e = 'Select a service';
    } else if (addr.text.trim().length < 5) {
      e = 'Please enter your full address';
    } else {
      e = slotError();
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
      await Api.i.createBooking({
        'serviceId': leaf!.id,
        'quantity': '$q',
        'budget': budget.text.trim(),
        'date': ymd(date),
        'time': '${two(time!.hour)}:${two(time!.minute)}',
        'address': addr.text.trim(),
        'landmark': landmark.text.trim(),
        'notes': notes.text.trim(),
        'geo': geo,
      });
      qty.text = '1';
      budget.clear();
      addr.clear();
      landmark.clear();
      notes.clear();
      geo = null;
      autoAddr = '';
      gpsMsg = null;
      time = null;
      await widget.onBooked();
    } on ApiError catch (x) {
      setState(() => error = x.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)));

  @override
  Widget build(BuildContext context) {
    if (cat == null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 14),
        TextButton(onPressed: widget.onRetryCatalog, child: const Text('Loading services… tap to retry')),
      ]));
    }
    if (cat!.cats.isEmpty) return const Center(child: Text('No services available right now.'));

    final cc = curCat!;
    final cs = curSub;
    final leaf = curLeaf;
    final total = (leaf?.rate ?? 0) * q;

    return ListView(padding: const EdgeInsets.all(16), children: [
      const BannerCarousel(),
      const SizedBox(height: 18),
      Row(children: [
        Container(width: 5, height: 24, decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        const Text('Book a service', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: kDark)),
      ]),
      const Padding(
        padding: EdgeInsets.only(left: 13),
        child: Text('Technicians nearby will send you their quotes.', style: TextStyle(color: Colors.black54)),
      ),
      label('Category *'),
      DropdownButtonFormField<String>(
        value: cc['id'] as String,
        isExpanded: true,
        items: [for (final c in cat!.cats) DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))],
        onChanged: (v) => setState(() {
          catId = v;
          subId = null;
          leafId = null;
        }),
      ),
      label('Type *'),
      DropdownButtonFormField<String>(
        key: ValueKey('sub-${cc['id']}'),
        value: cs?['id'] as String?,
        isExpanded: true,
        items: [for (final x in subs) DropdownMenuItem(value: x['id'] as String, child: Text(x['name'] as String))],
        onChanged: (v) => setState(() {
          subId = v;
          leafId = null;
        }),
      ),
      label('Service *'),
      DropdownButtonFormField<String>(
        key: ValueKey('leaf-${cs?['id']}'),
        value: leaf?.id,
        isExpanded: true,
        items: [
          for (final l in leaves)
            DropdownMenuItem(value: l.id, child: Text('${l.name}${l.rate > 0 ? ' — avg ${inr(l.rate)}/${l.unit}' : ''}', overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() => leafId = v),
      ),
      label(leaf != null ? 'Quantity (no. of ${leaf.unit}) *' : 'Quantity *'),
      TextField(controller: qty, keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
      if (leaf != null && leaf.rate > 0)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFE8F1FA), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFCFE0F1))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Market average rate', style: TextStyle(color: Colors.black54, fontSize: 12)),
            Text('${inr(leaf.rate)} per ${leaf.unit} × $q = ${inr(total)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Text('Only a guide. Enter any budget you like — technicians will send their own quote.',
                style: TextStyle(color: Colors.black54, fontSize: 12)),
            TextButton(onPressed: () => setState(() => budget.text = '$total'), child: Text('Use ${inr(total)} as budget')),
          ]),
        ),
      label('Your budget (₹)'),
      TextField(controller: budget, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Optional')),
      label('Date & time * (8 AM – 8 PM)'),
      Row(children: [
        Expanded(
            child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.white),
                onPressed: pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(ymd(date)))),
        const SizedBox(width: 10),
        Expanded(
            child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.white),
                onPressed: pickTime,
                icon: const Icon(Icons.access_time, size: 18),
                label: Text(time == null ? 'Pick time' : time!.format(context)))),
      ]),
      label('Service address *'),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), backgroundColor: Colors.white),
        onPressed: gpsBusy ? null : useGps,
        icon: gpsBusy
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.my_location),
        label: Text(geo == null ? 'Use my current location' : 'Update location'),
      ),
      if (gpsMsg != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(gpsMsg!, style: const TextStyle(fontSize: 12.5, color: Colors.black54))),
      const SizedBox(height: 8),
      TextField(
          controller: addr,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Area, road, town, PIN code')),
      label('House no. / Landmark'),
      TextField(controller: landmark, decoration: const InputDecoration(hintText: 'e.g. House 12, near Durga Mandir')),
      label('Problem details'),
      TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(hintText: 'Describe the issue (optional)')),
      if (error != null)
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(10)),
          child: Text(error!, style: const TextStyle(color: Color(0xFFC0352B))),
        ),
      const SizedBox(height: 18),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: kAccent, minimumSize: const Size.fromHeight(54)),
        onPressed: busy ? null : submit,
        child: busy
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : const Text('Book service'),
      ),
      const SizedBox(height: 24),
    ]);
  }
}
