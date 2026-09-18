import 'package:flutter/material.dart';

/// Curated icon set for categories (notes, rappels, budget), stored on
/// `CategoryModel.icon` by name (e.g. `'home'`) and resolved back to a
/// Material glyph here. Keep the keys in sync with the web app's icon
/// picker so both platforms stay visually consistent.
///
/// Was `lucide_icons` until that package's `IconData` subclass broke
/// against a Flutter SDK that made `IconData` `final` — no newer
/// `lucide_icons` release existed to fix it, so this switched to the
/// built-in Material set instead of pinning an older SDK.
const categoryIcons = <String, IconData>{
  'home': Icons.home_rounded,
  'utensils': Icons.restaurant_rounded,
  'shoppingCart': Icons.shopping_cart_rounded,
  'car': Icons.directions_car_rounded,
  'bus': Icons.directions_bus_rounded,
  'train': Icons.train_rounded,
  'bike': Icons.pedal_bike_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'plane': Icons.flight_rounded,
  'briefcase': Icons.work_rounded,
  'graduationCap': Icons.school_rounded,
  'heartPulse': Icons.monitor_heart_rounded,
  'stethoscope': Icons.medical_services_rounded,
  'pill': Icons.medication_rounded,
  'dumbbell': Icons.fitness_center_rounded,
  'gamepad2': Icons.sports_esports_rounded,
  'film': Icons.movie_rounded,
  'music': Icons.music_note_rounded,
  'coffee': Icons.local_cafe_rounded,
  'wine': Icons.wine_bar_rounded,
  'gift': Icons.card_giftcard_rounded,
  'piggyBank': Icons.savings_rounded,
  'creditCard': Icons.credit_card_rounded,
  'wallet': Icons.account_balance_wallet_rounded,
  'trendingUp': Icons.trending_up_rounded,
  'trendingDown': Icons.trending_down_rounded,
  'landmark': Icons.account_balance_rounded,
  'banknote': Icons.payments_rounded,
  'receipt': Icons.receipt_long_rounded,
  'wifi': Icons.wifi_rounded,
  'plug': Icons.power_rounded,
  'phone': Icons.phone_rounded,
  'wrench': Icons.build_rounded,
  'baby': Icons.child_care_rounded,
  'dog': Icons.pets_rounded,
  'users': Icons.people_rounded,
  'book': Icons.menu_book_rounded,
  'pencil': Icons.edit_rounded,
  'clipboardList': Icons.assignment_rounded,
  'checkSquare': Icons.check_box_rounded,
  'calendarCheck': Icons.event_available_rounded,
  'bellRing': Icons.notifications_active_rounded,
  'sparkles': Icons.auto_awesome_rounded,
  'star': Icons.star_rounded,
  'heart': Icons.favorite_rounded,
  'tag': Icons.label_rounded,
  'folder': Icons.folder_rounded,
  'fileText': Icons.description_rounded,
  'camera': Icons.camera_alt_rounded,
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
    categoryIcons[iconName] ?? Icons.label_rounded;

/// Parses a category's stored `#RRGGBB` hex color, falling back to the
/// given default when null or malformed.
Color parseCategoryColor(String? hex, {required Color fallback}) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
    return fallback;
  }

  return Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
}
