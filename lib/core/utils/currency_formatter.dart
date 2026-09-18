import 'package:intl/intl.dart';

/// Formats amounts the way the seeded demo data (and the backend's default
/// account currency) expects: XOF, no decimals, French grouping.
class CurrencyFormatter {
  const CurrencyFormatter._();

  static final _format = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'F',
    decimalDigits: 0,
  );

  static String format(num amount) => _format.format(amount);
}
