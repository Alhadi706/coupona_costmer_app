import 'dart:async';
import 'package:flutter/material.dart';

class AdsBannerSlider extends StatefulWidget {
  final List<Map<String, dynamic>> ads;
  final double height;
  final ValueChanged<Map<String, dynamic>>? onAdTap;
  final ValueChanged<Map<String, dynamic>>? onAdImpression;

  const AdsBannerSlider({
    required this.ads,
    required this.height,
    this.onAdTap,
    this.onAdImpression,
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
    if (widget.ads.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_pageController.hasClients) {
        int nextPage = _currentPage + 1;
        if (nextPage >= widget.ads.length) nextPage = 0;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

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
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.ads.length,
        onPageChanged: (index) {
          widget.onAdImpression?.call(widget.ads[index]);
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
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
