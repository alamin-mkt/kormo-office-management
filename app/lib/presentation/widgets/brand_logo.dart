import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final double height;
  final bool iconOnly;

  const BrandLogo({
    super.key,
    this.height = 40,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return Image.asset(
        'assets/brand/kormo-icon.png',
        height: height,
        width: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback if image asset is loading
          return Container(
            height: height,
            width: height,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1A7E96),
            ),
            child: const Center(
              child: Text(
                'K',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          );
        },
      );
    }

    return Image.asset(
      'assets/brand/kormo-logo-full.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: height,
              width: height,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1A7E96),
              ),
              child: const Center(
                child: Text('K', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'KORMO',
              style: TextStyle(
                color: Color(0xFF1A7E96),
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 1.5,
              ),
            ),
          ],
        );
      },
    );
  }
}
