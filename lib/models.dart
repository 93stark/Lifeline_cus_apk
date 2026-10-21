/// Lightweight helpers over the JSON the backend returns.

class Leaf {
  final String id, name, unit, catId, subId, catName, subName;
  final int rate;
  Leaf(this.id, this.name, this.unit, this.rate, this.catId, this.subId, this.catName, this.subName);
}

class Catalog {
  final List<Map<String, dynamic>> cats = [];
  final List<Leaf> leaves = [];

  Catalog(List<dynamic> raw) {
    for (final c in raw.whereType<Map>()) {
      final subs = <Map<String, dynamic>>[];
      for (final s in ((c['children'] as List?) ?? []).whereType<Map>()) {
        final ls = ((s['children'] as List?) ?? []).whereType<Map>().toList();
        if (ls.isEmpty) continue;
        subs.add({'id': s['id'].toString(), 'name': s['name'].toString(), 'leaves': <Leaf>[]});
        for (final l in ls) {
          final leaf = Leaf(
            l['id'].toString(),
            l['name'].toString(),
            (l['unit'] ?? 'unit').toString(),
            int.tryParse('${l['rate'] ?? 0}') ?? 0,
            c['id'].toString(),
            s['id'].toString(),
            c['name'].toString(),
            s['name'].toString(),
          );
          (subs.last['leaves'] as List<Leaf>).add(leaf);
          leaves.add(leaf);
        }
      }
      if (subs.isNotEmpty) {
        cats.add({'id': c['id'].toString(), 'name': c['name'].toString(), 'subs': subs});
      }
    }
  }
}

const statusText = {
  'open': 'Waiting for quotes',
  'assigned': 'Technician confirmed',
  'coming': 'Technician on the way',
  'completed': 'Completed',
  'cancelled': 'Cancelled',
};

bool isCurrent(Map<String, dynamic> b) => const ['open', 'assigned', 'coming'].contains(b['status']);

String s(dynamic v) => v == null ? '' : v.toString();

String inr(dynamic n) {
  final v = n is num ? n.round() : int.tryParse(s(n)) ?? 0;
  final str = v.toString();
  if (str.length <= 3) return '₹$str';
  final last3 = str.substring(str.length - 3);
  var rest = str.substring(0, str.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${parts.join(',')},$last3';
}

String shortId(String id) => (id.length > 6 ? id.substring(id.length - 6) : id).toUpperCase();

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String fmtDay(dynamic iso) {
  final d = DateTime.tryParse(s(iso))?.toLocal();
  if (d == null) return '';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}
