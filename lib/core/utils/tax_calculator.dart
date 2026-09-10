class TaxCalculationResult {
  final double subtotal;
  final double taxAmount;
  final double total;

  TaxCalculationResult({
    required this.subtotal,
    required this.taxAmount,
    required this.total,
  });
}

class TaxCalculator {
  static TaxCalculationResult calculate({
    required double rawSubtotal,
    required double taxRate,
    required String taxMode, // 'INCLUSIVE' or 'EXCLUSIVE'
  }) {
    final mode = taxMode.toUpperCase();

    if (mode == 'INCLUSIVE') {
      final subtotal = rawSubtotal / (1 + (taxRate / 100));
      final taxAmount = rawSubtotal - subtotal;
      return TaxCalculationResult(
        subtotal: subtotal,
        taxAmount: taxAmount,
        total: rawSubtotal,
      );
    } else {
      final taxAmount = rawSubtotal * (taxRate / 100);
      final total = rawSubtotal + taxAmount;
      return TaxCalculationResult(
        subtotal: rawSubtotal,
        taxAmount: taxAmount,
        total: total,
      );
    }
  }
}
