import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models.dart';

Color statusColor(String st) {
  switch (st) {
    case 'open':
      return const Color(0xFFB45309);
    case 'assigned':
      return const Color(0xFF1D4ED8);
    case 'coming':
      return const Color(0xFF7C3AED);
    case 'completed':
      return const Color(0xFF12805C);
    default:
      return const Color(0xFFC0352B);
  }
}

Future<void> openUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

class BookingCard extends StatelessWidget {
  final Map<String, dynamic> b;
  final void Function(String bookingId, String techId) onAccept;
  final void Function(String bookingId) onComplete;
  final void Function(String bookingId) onCancel;
  final void Function(String bookingId) onFeedback;

  const BookingCard({
    super.key,
    required this.b,
    required this.onAccept,
    required this.onComplete,
    required this.onCancel,
    required this.onFeedback,
  });

  Widget note(String text, Color bg, {Widget? extra}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(text), if (extra != null) extra]),
      );

  Widget kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 92, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final id = s(b['id']);
    final st = s(b['status']);
    final bids = ((b['bids'] as List?) ?? []).whereType<Map>().toList();
    final rej = ((b['rejections'] as List?) ?? []).whereType<Map>().toList();
    final fb = b['feedback'] is Map ? b['feedback'] as Map : null;
    final qty = s(b['unit']).isNotEmpty ? '${s(b['quantity'])} ${s(b['unit'])}' : s(b['quantity']);
    final children = <Widget>[];

    if (st == 'open') {
      if (bids.isNotEmpty) {
        children.add(note('💬 ${bids.length} technician quote(s) received — choose one:', const Color(0xFFE8F1FF)));
        for (final q in bids) {
          final rt = q['rating'] is Map ? q['rating'] as Map : null;
          children.add(Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE3E7EF)), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s(q['techName'])}  ✓ verified', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    [
                      s(q['experience']),
                      if (rt != null) '★ ${rt['avg']} (${rt['n']})',
                      if (s(q['message']).isNotEmpty) s(q['message']),
                    ].where((e) => e.isNotEmpty).join(' · '),
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ]),
              ),
              Column(children: [
                Text(inr(q['quote']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(80, 34), padding: const EdgeInsets.symmetric(horizontal: 14)),
                  onPressed: () => onAccept(id, s(q['techId'])),
                  child: const Text('Accept'),
                ),
              ]),
            ]),
          ));
        }
      } else {
        children.add(note('⏳ Service booked! Nearby ${s(b['service'])} technicians are being notified. Quotes will appear here.',
            const Color(0xFFFFF4E5)));
      }
      if (rej.isNotEmpty) {
        children.add(note('Declined by:\n${rej.map((r) => '• ${s(r['techName'])}: “${s(r['remark'])}”').join('\n')}',
            const Color(0xFFFDECEA)));
      }
    }

    if (['assigned', 'coming', 'completed'].contains(st) && s(b['techName']).isNotEmpty) {
      final mob = s(b['techMobile']);
      final head = st == 'coming'
          ? '🚗 Coming! Your technician is on the way.'
          : st == 'assigned'
              ? '✅ Confirmed. Technician will contact you.'
              : '🎉 Job completed.';
      children.add(note(
        '$head\n${s(b['techName'])}${b['finalQuote'] != null ? ' · Agreed ${inr(b['finalQuote'])}' : ''}',
        st == 'coming' ? const Color(0xFFFFF4E5) : const Color(0xFFE7F6EF),
        extra: mob.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 8, children: [
                  OutlinedButton.icon(
                      onPressed: () => openUrl('tel:$mob'), icon: const Icon(Icons.call, size: 18), label: Text(mob)),
                  OutlinedButton.icon(
                      onPressed: () => openUrl('https://wa.me/91$mob'),
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('WhatsApp')),
                ]),
              ),
      ));
    }

    if (fb != null) {
      final stars = (fb['stars'] is num) ? (fb['stars'] as num).toInt() : 0;
      children.add(note(
        'Your feedback: ${'★' * stars}${'☆' * (5 - stars)} · ${fb['satisfaction'] == 'satisfied' ? '😊 Satisfied' : '😞 Unsatisfied'}'
        '${s(fb['remark']).isNotEmpty ? '\n“${s(fb['remark'])}”' : ''}',
        const Color(0xFFF1F5F9),
      ));
    }

    final actions = <Widget>[];
    if (st == 'completed' && fb == null) {
      actions.add(FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40), backgroundColor: const Color(0xFFF59E0B)),
          onPressed: () => onFeedback(id),
          icon: const Icon(Icons.star),
          label: const Text('Give feedback')));
    }
    if (st == 'assigned' || st == 'coming') {
      actions.add(FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => onComplete(id),
          child: const Text('Mark completed')));
    }
    if (['open', 'assigned', 'coming'].contains(st)) {
      actions.add(OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), foregroundColor: const Color(0xFFC0352B)),
          onPressed: () => onCancel(id),
          child: const Text('Cancel')));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE3E7EF))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s(b['service']), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text(
                  '${s(b['servicePath']).isNotEmpty ? '${s(b['servicePath'])} · ' : ''}#${shortId(id)}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: statusColor(st).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(statusText[st] ?? st,
                  style: TextStyle(color: statusColor(st), fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),
          kv('Qty', qty),
          kv('When', s(b['schedule'])),
          if (b['estimate'] != null && s(b['estimate']) != '0') kv('Market est.', inr(b['estimate'])),
          if (b['budget'] != null && s(b['budget']).isNotEmpty && s(b['budget']) != '0') kv('Your budget', inr(b['budget'])),
          kv('Address', '${s(b['address'])}${s(b['landmark']).isNotEmpty ? ', ${s(b['landmark'])}' : ''}'),
          ...children,
          if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(spacing: 8, runSpacing: 8, children: actions)),
        ]),
      ),
    );
  }
}
