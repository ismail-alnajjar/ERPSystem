import 'package:erp_mobile_app/helper/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/tax_calculator.dart';
import '../../data/repositories/invoices_repository.dart';
import '../bloc/invoice_bloc.dart';
import '../bloc/invoice_event.dart';

import 'package:erp_mobile_app/features/invoices/data/model/invoice_item_model.dart';
import 'package:erp_mobile_app/features/invoices/data/model/invoice_model.dart';
import 'package:erp_mobile_app/features/invoices/data/model/product_model.dart';

// استيراد خدمة الإعدادات
class CreateInvoicePage extends StatefulWidget {
  const CreateInvoicePage({super.key});

  @override
  State<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage> {
  final List<InvoiceItemModel> _items = [];
  List<ProductModel> _allProducts = [];

  String _currencyCode = 'JOD';
  double _exchangeRate = 1.0;
  double _taxRate = 16.0;
  String _taxMode = 'EXCLUSIVE';
  late String _generatedInvoiceNumber;

  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // 1. جلب الإعدادات من SettingsService
    final settings = await SettingsService.loadSettings();

    // 2. توليد رقم فاتورة تلقائي
    _generatedInvoiceNumber =
        'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    if (!mounted) return;

    setState(() {
      _currencyCode = settings['currency'];
      _exchangeRate = settings['exchangeRate'];
      _taxRate = settings['taxRate'];
      _taxMode = settings['taxMode'];
      _isLoadingSettings = false;
    });

    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await sl<InvoicesRepository>().getAllProducts();
      if (!mounted) return;
      setState(() {
        _allProducts = products;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل في جلب المنتجات: $e')));
    }
  }

  // حساب المجاميع المالية بناءً على حاسبة الضرائب TaxCalculator
  TaxCalculationResult _calculateTotals() {
    double rawSubtotal = 0;
    for (var item in _items) {
      rawSubtotal += item.lineTotal;
    }
    return TaxCalculator.calculate(
      rawSubtotal: rawSubtotal,
      taxRate: _taxRate,
      taxMode: _taxMode,
    );
  }

  void _addProductToInvoice(ProductModel product) {
    if (!mounted) return;

    setState(() {
      final existingIndex = _items.indexWhere((i) => i.productId == product.id);
      if (existingIndex >= 0) {
        final existing = _items[existingIndex];
        final newQty = existing.quantity + 1;

        _items[existingIndex] = existing.copyWith(
          quantity: newQty,
          lineTotal: newQty * existing.unitPrice,
        );
      } else {
        _items.add(
          InvoiceItemModel(
            productId: product.id,
            itemDescription: product.name,
            quantity: 1,
            unitPrice: product.unitPrice,
            lineTotal: product.unitPrice,
          ),
        );
      }
    });
  }

  void _openBarcodeScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: 400,
        child: MobileScanner(
          onDetect: (capture) async {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                final code = barcode.rawValue!;
                Navigator.pop(ctx);
                final product = await sl<InvoicesRepository>()
                    .getProductByBarcode(code);

                if (!mounted) return;

                if (product != null) {
                  _addProductToInvoice(product);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added: ${product.name}')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product not found!')),
                  );
                }
                break;
              }
            }
          },
        ),
      ),
    );
  }

  void _saveInvoice() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item.')),
      );
      return;
    }

    final totals = _calculateTotals();

    final double convertedSubtotal = _exchangeRate > 0
        ? totals.subtotal / _exchangeRate
        : totals.subtotal;
    final double convertedTax = _exchangeRate > 0
        ? totals.taxAmount / _exchangeRate
        : totals.taxAmount;
    final double convertedTotal = _exchangeRate > 0
        ? totals.total / _exchangeRate
        : totals.total;

    final convertedItems = _items.map((item) {
      final double priceInCurrency = _exchangeRate > 0
          ? item.unitPrice / _exchangeRate
          : item.unitPrice;
      return item.copyWith(
        unitPrice: priceInCurrency,
        lineTotal: item.quantity * priceInCurrency,
      );
    }).toList();

    final invoice = InvoiceModel(
      invoiceNumber: _generatedInvoiceNumber,
      invoiceDate: DateTime.now(),
      currencyCode: _currencyCode,
      exchangeRate: _exchangeRate,
      taxMode: _taxMode,
      taxRate: _taxRate,
      status: 'DRAFT',
      subtotalAmount: convertedSubtotal,
      taxAmount: convertedTax,
      totalAmount: convertedTotal,
      items: convertedItems,
    );

    context.read<InvoiceBloc>().add(CreateInvoiceEvent(invoice));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSettings) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final totals = _calculateTotals();

    final double convertedSubtotal = _exchangeRate > 0
        ? totals.subtotal / _exchangeRate
        : totals.subtotal;
    final double convertedTax = _exchangeRate > 0
        ? totals.taxAmount / _exchangeRate
        : totals.taxAmount;
    final double convertedTotal = _exchangeRate > 0
        ? totals.total / _exchangeRate
        : totals.total;

    return Scaffold(
      appBar: AppBar(
        title: Text('New Invoice ($_generatedInvoiceNumber)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _openBarcodeScanner,
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط الترويسة يعرض الإعدادات فقط بدون القابليّة للتعديل
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.indigo.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Currency: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '$_currencyCode ($_exchangeRate)',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  'Tax: $_taxMode ($_taxRate%)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // قائمة العناصر
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('No items added yet. Scan or select below.'),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final itemConvertedPrice = _exchangeRate > 0
                          ? item.unitPrice / _exchangeRate
                          : item.unitPrice;
                      final itemConvertedTotal = _exchangeRate > 0
                          ? item.lineTotal / _exchangeRate
                          : item.lineTotal;

                      return ListTile(
                        title: Text(item.itemDescription),
                        subtitle: Text(
                          '${item.quantity} x ${itemConvertedPrice.toStringAsFixed(2)} $_currencyCode',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${itemConvertedTotal.toStringAsFixed(2)} $_currencyCode',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                if (!mounted) return;
                                setState(() {
                                  _items.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // اختيار المنتج يدوياً
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButton<ProductModel>(
              hint: const Text('Select product manually...'),
              isExpanded: true,
              items: _allProducts.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text('${p.name} - ${p.unitPrice} JOD'),
                );
              }).toList(),
              onChanged: (product) {
                if (product != null) {
                  _addProductToInvoice(product);
                }
              },
            ),
          ),

          // البطاقة المالية الحسابية
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:'),
                      Text(
                        '${convertedSubtotal.toStringAsFixed(2)} $_currencyCode',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tax Amount:'),
                      Text('${convertedTax.toStringAsFixed(2)} $_currencyCode'),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '${convertedTotal.toStringAsFixed(2)} $_currencyCode',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  if (_currencyCode != 'JOD') ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Equivalent in JOD:',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        Text(
                          '(${totals.total.toStringAsFixed(2)} JOD)',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _saveInvoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text(
                      'Save Invoice',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
