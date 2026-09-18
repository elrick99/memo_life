/// Laravel serializes `decimal:N`-cast attributes (`balance`, `amount`,
/// `target_amount`, `current_amount`, ...) as JSON **strings** (e.g.
/// `"1234.56"`), not numbers — confirmed against the live API. `num`-cast
/// parsing of API decimals must go through this helper instead of
/// `as num?`, which throws on the string form.
double parseApiDecimal(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    return value.toDouble();
  }

  return double.parse(value.toString());
}
