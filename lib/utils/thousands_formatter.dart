import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats a plain-number TextField with thousands separators as the
/// user types (e.g. "1000000" displays as "1,000,000"). The underlying
/// value sent to the backend should still be parsed with
/// [ThousandsInputFormatter.unformat] to strip the commas back out.
class ThousandsInputFormatter extends TextInputFormatter {
  static final _numberFormat = NumberFormat.decimalPattern('en_US');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(',', '');
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }
    if (!RegExp(r'^\d+$').hasMatch(digitsOnly)) {
      // Reject non-digit input (e.g. stray letters) by keeping the old
      // value instead of allowing invalid characters through.
      return oldValue;
    }
    final parsed = int.parse(digitsOnly);
    final formatted = _numberFormat.format(parsed);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Strips commas back out before sending a value to the backend, e.g.
  /// `unformat(priceCtrl.text)` → "1000000".
  static String unformat(String formatted) => formatted.replaceAll(',', '');
}
