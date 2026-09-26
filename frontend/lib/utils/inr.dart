/// Minimal Indian-rupee formatting for HunarSathi without adding an `intl`
/// dependency.
///
/// Uses Indian digit grouping (last 3 digits, then pairs):
/// 350 -> ₹350, 6800 -> ₹6,800, 150000 -> ₹1,50,000, 1250000 -> ₹12,50,000.
///
/// Handles integers, decimal paise when present, negatives, and paise
/// rounding edge cases (e.g. 99.999 -> ₹100).
String formatInr(num value) {
  final negative = value < 0;
  final absValue = value.abs();
  var rupees = absValue.truncate();
  var paise = ((absValue - rupees) * 100).round();
  if (paise == 100) {
    rupees += 1;
    paise = 0;
  }

  final digits = rupees.toString();
  final buf = StringBuffer();
  final len = digits.length;
  for (var i = 0; i < len; i++) {
    buf.write(digits[i]);
    final pos = len - i - 1;
    if (pos > 0 && (pos == 3 || (pos > 3 && (pos - 3) % 2 == 0))) {
      buf.write(',');
    }
  }

  var out = buf.toString();
  if (paise > 0) {
    out += '.${paise.toString().padLeft(2, '0')}';
  }
  return '${negative ? '-₹' : '₹'}$out';
}
