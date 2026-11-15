import 'package:flutter/material.dart';

/// KORMO Brand Design Tokens
/// Strictly follows brand rules: WCAG AA contrast, minimum 44px touch targets.
class AppColors {
  AppColors._();

  // Core Brand Palette
  static const Color primaryTeal = Color(0xFF1A7E96);
  static const Color accentOrange = Color(0xFFF3760C);
  static const Color orangeText = Color(0xFFB45309); // WCAG AA compliant text accent

  // Neutral Palette
  static const Color ink = Color(0xFF0F172A);
  static const Color background = Color(0xFFF4F6F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color muted = Color(0xFF64748B);
  static const Color subtle = Color(0xFF94A3B8);

  // Status & Semantic Colors
  static const Color success = Color(0xFF047857);
  static const Color warning = Color(0xFFB45309);
  static const Color danger = Color(0xFFB91C1C);
  static const Color info = Color(0xFF1D4ED8);

  // Soft Status Backgrounds for Badges & Chips
  static const Color successBg = Color(0xFFECFDF5);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color infoBg = Color(0xFFEFF6FF);
  static const Color tealBg = Color(0xFFE6F4F7);
}
