import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'booking_card.dart' show openUrl;

/// Offer banners set by the admin (up to 3). Auto-slides. Falls back to a brand banner.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key});
  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  static List<Map<String, dynamic>>? _cache;
  List<Map<String, dynamic>>? items = _cache;
  final PageController pc = PageController(viewportFraction: 0.94);
  int page = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 4), (_) {
      final n = items?.length ?? 0;
      if (n < 2 || !pc.hasClients) return;
      pc.animateToPage((page + 1) % n, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    pc.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final b = await Api.i.banners();
      _cache = b;
      if (mounted) setState(() => items = b);
    } catch (_) {
      if (mounted && items == null) setState(() => items = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = items;
    if (list == null) {
      return AspectRatio(
        aspectRatio: 16 / 7,
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFFDCE6F0), borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
    if (list.isEmpty) return const _BrandBanner();

    return Column(children: [
      AspectRatio(
        aspectRatio: 16 / 7,
        child: PageView.builder(
          controller: pc,
          itemCount: list.length,
          onPageChanged: (i) => setState(() => page = i),
          itemBuilder: (_, i) {
            final b = list[i];
            final url = '$kBaseUrl/api/banner?id=${Uri.encodeComponent('${b['id']}')}&v=${b['v'] ?? ''}';
            final caption = '${b['caption'] ?? ''}';
            final link = '${b['link'] ?? ''}';
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: link.isEmpty ? null : () => openUrl(link),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (c, w, p) => p == null ? w : Container(color: const Color(0xFFDCE6F0)),
                      errorBuilder: (c, e, s) => const _BrandBanner(),
                    ),
                    if (caption.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 22, 14, 10),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
                          ),
                          child: Text(caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      if (list.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < list.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 7,
                width: i == page ? 20 : 7,
                decoration: BoxDecoration(color: i == page ? kAccent : Colors.black26, borderRadius: BorderRadius.circular(4)),
              ),
          ]),
        ),
    ]);
  }
}

class _BrandBanner extends StatelessWidget {
  const _BrandBanner();
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 7,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: kGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Row(children: [
          const LogoMark(size: 72, glow: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Trusted technicians\nat your door',
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(12)),
                child: const Text('Verified • Local • Fast',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
