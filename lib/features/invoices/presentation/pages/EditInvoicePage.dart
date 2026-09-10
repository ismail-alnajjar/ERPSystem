import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/tax_calculator.dart';
import '../../data/model/invoice_item_model.dart';
import '../../data/model/invoice_model.dart';
import '../bloc/invoice_bloc.dart';
import '../bloc/invoice_event.dart';

class EditInvoicePage extends StatefulWidget {
  final InvoiceModel invoice;

  const EditInvoicePage({
    super.key,
    required this.invoice,
  });

  @override
  State<EditInvoicePage> createState() => _EditInvoicePageState();
}

class _EditInvoicePageState extends State<EditInvoicePage> {
  late List<InvoiceItemModel> _items;
  late String _currencyCode;
  late double _exchangeRate;
  late double _taxRate;
  late String _taxMode;

  late TextEditingController _taxRateController;
  late TextEditingController _exchangeRateController;

  // أسعار الصرف مقابل العملة الأساسية (JOD)
  final Map<String, double> _currencyExchangeRates = {
    'JOD': 1.0,
    'USD': 0.71,
    'AED': 0.19,
  };

  @override
  void initState() {
    super.initState();
    // 🟢 الاعتماد المباشر على بيانات الفاتورة الأصلية لمنع الرجوع لـ JOD تلقائياً
    _items = widget.invoice.items.map((item) => item.copyWith()).toList();
    _currencyCode = widget.invoice.currencyCode.isNotEmpty
        ? widget.invoice.currencyCode
        : 'JOD';
    _exchangeRate = widget.invoice.exchangeRate > 0
        ? widget.invoice.exchangeRate
        : 1.0;
    _taxRate = widget.invoice.taxRate;
    _taxMode = widget.invoice.taxMode.isNotEmpty
        ? widget.invoice.taxMode.toUpperCase()
        : 'EXCLUSIVE';

    _taxRateController = TextEditingController(text: _taxRate.toString());
    _exchangeRateController = TextEditingController(
      text: _exchangeRate.toString(),
    );
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  /// إعادة الفاتورة لقيمها الأصلية عند الفتح
  void _resetToDefault() {
    setState(() {
      _items = widget.invoice.items.map((item) => item.copyWith()).toList();
      _currencyCode = widget.invoice.currencyCode.isNotEmpty
          ? widget.invoice.currencyCode
          : 'JOD';
      _exchangeRate = widget.invoice.exchangeRate > 0
          ? widget.invoice.exchangeRate
          : 1.0;
      _taxRate = widget.invoice.taxRate;
      _taxMode = widget.invoice.taxMode.isNotEmpty
          ? widget.invoice.taxMode.toUpperCase()
          : 'EXCLUSIVE';

      _taxRateController.text = _taxRate.toString();
      _exchangeRateController.text = _exchangeRate.toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تمت إعادة الفاتورة إلى بياناتها الأصلية'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// حساب المجموع الفرعي والضريبة بشكل موحد وبدون قسمة أو تحويلات مزدوجة
  TaxCalculationResult _calculateTotals() {
    double rawSubtotal = 0.0;
    for (var item in _items) {
      rawSubtotal += (item.quantity * item.unitPrice);
    }

    return TaxCalculator.calculate(
      rawSubtotal: rawSubtotal,
      taxRate: _taxRate,
      taxMode: _taxMode,
    );
  }

  void _onCurrencyChanged(String? newCurrency) {
    if (newCurrency != null) {
      final double newRate = _currencyExchangeRates[newCurrency] ?? 1.0;
      setState(() {
        _currencyCode = newCurrency;
        _exchangeRate = newRate;
        _exchangeRateController.text = newRate.toString();
      });
    }
  }

  void _updateQuantity(int index, num newQuantity) {
    if (newQuantity <= 0) return;
    setState(() {
      final item = _items[index];
      final double updatedQty = newQuantity.toDouble();

      _items[index] = item.copyWith(
        quantity: updatedQty,
        lineTotal: updatedQty * item.unitPrice,
      );
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _saveAndSubmitInvoice() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة عنصر واحد على الأقل.')),
      );
      return;
    }

    final parsedTaxRate = double.tryParse(_taxRateController.text) ?? _taxRate;
    final parsedExchangeRate =
        double.tryParse(_exchangeRateController.text) ?? _exchangeRate;

    final effectiveExchangeRate = parsedExchangeRate > 0
        ? parsedExchangeRate
        : 1.0;
    _taxRate = parsedTaxRate;
    _exchangeRate = effectiveExchangeRate;

    final totals = _calculateTotals();

    final updatedInvoice = widget.invoice.copyWith(
      currencyCode: _currencyCode,
      exchangeRate: effectiveExchangeRate,
      taxMode: _taxMode,
      taxRate: _taxRate,
      subtotalAmount: totals.subtotal,
      taxAmount: totals.taxAmount,
      totalAmount: totals.total,
      items: _items,
    );

    context.read<InvoiceBloc>().add(UpdateInvoiceEvent(updatedInvoice));

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();

    return Scaffold(
      appBar: AppBar(
        title: Text('تعديل الفاتورة (${widget.invoice.invoiceNumber})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة للوضع الأصلي',
            onPressed: _resetToDefault,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        color: Colors.white,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _saveAndSubmitInvoice,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'حفظ الفاتورة النهائية',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // قسم إعدادات الفاتورة
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إعدادات الفاتورة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _currencyCode,
                              decoration: const InputDecoration(
                                labelText: 'العملة',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              items: _currencyExchangeRates.keys.map((curr) {
                                return DropdownMenuItem(
                                  value: curr,
                                  child: Text(curr),
                                );
                              }).toList(),
                              onChanged: _onCurrencyChanged,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _exchangeRateController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'سعر الصرف',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              onChanged: (val) {
                                final parsed = double.tryParse(val) ?? 1.0;
                                setState(() {
                                  _exchangeRate = parsed > 0 ? parsed : 1.0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _taxMode,
                              decoration: const InputDecoration(
                                labelText: 'نظام الضريبة',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'EXCLUSIVE',
                                  child: Text('غير شامل'),
                                ),
                                DropdownMenuItem(
                                  value: 'INCLUSIVE',
                                  child: Text('شامل'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _taxMode = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _taxRateController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'نسبة الضريبة (%)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _taxRate = double.tryParse(val) ?? 0.0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // قائمة العناصر
              const Text(
                'عناصر الفاتورة (الكميات والأسعار)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.itemDescription,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'السعر: ${item.unitPrice.toStringAsFixed(2)} $_currencyCode',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _updateQuantity(
                                index,
                                item.quantity.toInt() - 1,
                              ),
                            ),
                            Text(
                              '${item.quantity.toInt()}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _updateQuantity(
                                index,
                                item.quantity.toInt() + 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.lineTotal.toStringAsFixed(2)} $_currencyCode',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeItem(index),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // كارت المجموع النهائي
              Card(
                color: Colors.indigo.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المجموع الفرعي:'),
                          Text(
                            '${totals.subtotal.toStringAsFixed(2)} $_currencyCode',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('قيمة الضريبة:'),
                          Text(
                            '${totals.taxAmount.toStringAsFixed(2)} $_currencyCode',
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'المجموع الكلي:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            '${totals.total.toStringAsFixed(2)} $_currencyCode',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
