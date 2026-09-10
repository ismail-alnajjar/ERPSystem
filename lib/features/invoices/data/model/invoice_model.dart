import 'invoice_item_model.dart';

class InvoiceModel {
  final int? id;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String currencyCode;
  final double exchangeRate;
  final String taxMode; // 'INCLUSIVE' or 'EXCLUSIVE'
  final double taxRate;
  final String status; // 'DRAFT', 'APPROVED', 'CANCELLED'
  final double subtotalAmount;
  final double taxAmount;
  final double totalAmount;
  final List<InvoiceItemModel> items;

  InvoiceModel({
    this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.currencyCode,
    this.exchangeRate = 1.0,
    required this.taxMode,
    this.taxRate = 16.0,
    this.status = 'DRAFT',
    required this.subtotalAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.items,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    final rawItems = (json['items'] ?? json['invoice_items']) as List?;
    var itemsList = rawItems != null
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => InvoiceItemModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <InvoiceItemModel>[];

    return InvoiceModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? ''),
      invoiceNumber:
          (json['invoice_number'] ?? json['invoiceNumber'])?.toString() ?? '',
      invoiceDate: (json['invoice_date'] ?? json['invoiceDate']) != null
          ? DateTime.tryParse(
                  (json['invoice_date'] ?? json['invoiceDate']).toString(),
                ) ??
                DateTime.now()
          : DateTime.now(),
      currencyCode:
          (json['currency_code'] ?? json['currencyCode'])?.toString() ?? 'JOD',
      // 🟢 ضمان جلب سعر الصرف بدون تصفير
      exchangeRate: parseDouble(
        json['exchange_rate'] ?? json['exchangeRate'],
        1.0,
      ),
      taxMode:
          ((json['tax_mode'] ?? json['taxMode'])?.toString() ?? 'EXCLUSIVE')
              .toUpperCase(),
      taxRate: parseDouble(json['tax_rate'] ?? json['taxRate'], 16.0),
      // 🟢 تحويل الـ Status دائماً إلى Uppercase لتوافق قيود Supabase
      status: (json['status']?.toString() ?? 'DRAFT').toUpperCase(),
      subtotalAmount: parseDouble(
        json['subtotal_amount'] ?? json['subtotalAmount'],
      ),
      taxAmount: parseDouble(json['tax_amount'] ?? json['taxAmount']),
      totalAmount: parseDouble(json['total_amount'] ?? json['totalAmount']),
      items: itemsList,
    );
  }

  Map<String, dynamic> toJson() {
    final mappedItems = items.map((item) => item.toJson()).toList();
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate.toIso8601String(),
      'currency_code': currencyCode,
      'exchange_rate': exchangeRate,
      // 🟢 إرسال الحقول بالحروف الكبيرة لضمان قبول CHECK Constraint في Supabase
      'tax_mode': taxMode.toUpperCase(),
      'tax_rate': taxRate,
      'status': status.toUpperCase(),
      'subtotal_amount': subtotalAmount,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'items': mappedItems,
      'invoice_items': mappedItems,
    };
  }

  InvoiceModel copyWith({
    int? id,
    String? invoiceNumber,
    DateTime? invoiceDate,
    String? currencyCode,
    double? exchangeRate,
    String? taxMode,
    double? taxRate,
    String? status,
    double? subtotalAmount,
    double? taxAmount,
    double? totalAmount,
    List<InvoiceItemModel>? items,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      currencyCode: currencyCode ?? this.currencyCode,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      taxMode: taxMode ?? this.taxMode,
      taxRate: taxRate ?? this.taxRate,
      status: status ?? this.status,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
    );
  }
}
