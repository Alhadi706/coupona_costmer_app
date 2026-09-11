import 'dart:async';
import 'package:flutter/material.dart';

class AdsBannerSlider extends StatefulWidget {
  final List<Map<String, dynamic>> ads;
  final double height;
  final ValueChanged<Map<String, dynamic>>? onAdTap;
  final ValueChanged<Map<String, dynamic>>? onAdImpression;
  final VoidCallback? onBookingTap;

  const AdsBannerSlider({
    required this.ads,
    required this.height,
    this.onAdTap,
    this.onAdImpression,
    this.onBookingTap,
    super.key,
  });

  @override
  State<AdsBannerSlider> createState() => _AdsBannerSliderState();
}

class _AdsBannerSliderState extends State<AdsBannerSlider> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.ads.isNotEmpty) widget.onAdImpression?.call(widget.ads.first);
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer?.cancel();
    if (widget.ads.isEmpty) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        int nextPage = _currentPage + 1;
        if (nextPage >= widget.ads.length + 1) nextPage = 0;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _pauseAutoSlide(PointerDownEvent _) => _timer?.cancel();

  void _resumeAutoSlide(PointerEvent _) => _startAutoSlide();

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Listener(
        onPointerDown: _pauseAutoSlide,
        onPointerUp: _resumeAutoSlide,
        onPointerCancel: _resumeAutoSlide,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.ads.length + 1,
          onPageChanged: (index) {
            if (index < widget.ads.length) {
              widget.onAdImpression?.call(widget.ads[index]);
            }
            setState(() {
              _currentPage = index;
            });
          },
          itemBuilder: (context, index) {
            if (index == widget.ads.length) {
              return _bookingCard();
            }
          final ad = widget.ads[index];
          final imageUrl = (ad['imageUrl'] ?? ad['image'] ?? '').toString();
          final assetPath = imageUrl;
          final caption = (ad['description'] ?? ad['title'] ?? '').toString();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: InkWell(
              onTap: widget.onAdTap == null ? null : () => widget.onAdTap!(ad),
              borderRadius: BorderRadius.circular(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl.startsWith('http') || imageUrl.startsWith('/')
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallback(context),
                          )
                        : assetPath.isNotEmpty
                        ? Image.asset(
                            assetPath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallback(context),
                          )
                        : _fallback(context),
                    if (caption.isNotEmpty)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 14,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
          },
        ),
      ),
    );
  }

  Widget _bookingCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        key: const ValueKey<String>('booking_banner_cta'),
        onTap: widget.onBookingTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF006D77), Color(0xFFE09F3E)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Row(
              children: [
                Icon(Icons.campaign_rounded, color: Colors.white, size: 44),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'احجز مساحتك الإعلانية هنا',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'انشر علاماتك التجارية وتواصل مع عملاء كوبونا بفعالية',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: const Icon(Icons.campaign_outlined, size: 48),
    );
  }
}
