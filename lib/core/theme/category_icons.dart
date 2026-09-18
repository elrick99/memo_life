import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Curated icon set for categories (notes, rappels, budget), stored on
/// `CategoryModel.icon` by name (e.g. `'home'`) and resolved back to a
/// [LucideIcons] glyph here. Keep the keys in sync with the web app's
/// `lucide-react` icon picker so both platforms stay visually consistent.
const categoryIcons = <String, IconData>{
  'home': LucideIcons.home,
  'utensils': LucideIcons.utensils,
  'shoppingCart': LucideIcons.shoppingCart,
  'car': LucideIcons.car,
  'bus': LucideIcons.bus,
  'train': LucideIcons.train,
  'bike': LucideIcons.bike,
  'fuel': LucideIcons.fuel,
  'plane': LucideIcons.plane,
  'briefcase': LucideIcons.briefcase,
  'graduationCap': LucideIcons.graduationCap,
  'heartPulse': LucideIcons.heartPulse,
  'stethoscope': LucideIcons.stethoscope,
  'pill': LucideIcons.pill,
  'dumbbell': LucideIcons.dumbbell,
  'gamepad2': LucideIcons.gamepad2,
  'film': LucideIcons.film,
  'music': LucideIcons.music,
  'coffee': LucideIcons.coffee,
  'wine': LucideIcons.wine,
  'gift': LucideIcons.gift,
  'piggyBank': LucideIcons.piggyBank,
  'creditCard': LucideIcons.creditCard,
  'wallet': LucideIcons.wallet,
  'trendingUp': LucideIcons.trendingUp,
  'trendingDown': LucideIcons.trendingDown,
  'landmark': LucideIcons.landmark,
  'banknote': LucideIcons.banknote,
  'receipt': LucideIcons.receipt,
  'wifi': LucideIcons.wifi,
  'plug': LucideIcons.plug,
  'phone': LucideIcons.phone,
  'wrench': LucideIcons.wrench,
  'baby': LucideIcons.baby,
  'dog': LucideIcons.dog,
  'users': LucideIcons.users,
  'book': LucideIcons.book,
  'pencil': LucideIcons.pencil,
  'clipboardList': LucideIcons.clipboardList,
  'checkSquare': LucideIcons.checkSquare,
  'calendarCheck': LucideIcons.calendarCheck,
  'bellRing': LucideIcons.bellRing,
  'sparkles': LucideIcons.sparkles,
  'star': LucideIcons.star,
  'heart': LucideIcons.heart,
  'tag': LucideIcons.tag,
  'folder': LucideIcons.folder,
  'fileText': LucideIcons.fileText,
  'camera': LucideIcons.camera,
};

/// Extended color swatches for category pickers — the existing 5-color
/// `AppColors.chartLight` extended with a few more common accent tones.
const categoryColorSwatches = <Color>[
  Color(0xFF2563EB), // bleu
  Color(0xFF22C55E), // vert
  Color(0xFFF59E0B), // ambre
  Color(0xFF8B5CF6), // violet
  Color(0xFF60A5FA), // bleu clair
  Color(0xFFF43F5E), // rose
  Color(0xFF06B6D4), // cyan
  Color(0xFFEF4444), // rouge
  Color(0xFF14B8A6), // sarcelle
  Color(0xFFEAB308), // jaune
  Color(0xFFA855F7), // pourpre
  Color(0xFF64748B), // ardoise
];

/// Resolves a category's stored icon name to a glyph, with a sensible
/// fallback (a plain tag) for legacy categories created before icons
/// existed, or an unrecognized/future icon key.
IconData resolveCategoryIcon(String? iconName) =>
    categoryIcons[iconName] ?? LucideIcons.tag;

/// Parses a category's stored `#RRGGBB` hex color, falling back to the
/// given default when null or malformed.
Color parseCategoryColor(String? hex, {required Color fallback}) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
    return fallback;
  }

  return Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
}
