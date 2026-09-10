class InvoiceItemModel {
  final int? id;
  final int? invoiceId;
  final int? productId;
  final String itemDescription;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  InvoiceItemModel({
    this.id,
    this.invoiceId,
    this.productId,
    required this.itemDescription,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    return InvoiceItemModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? ''),
      invoiceId: json['invoice_id'] is int
          ? json['invoice_id']
          : int.tryParse(json['invoice_id']?.toString() ?? ''),
      productId: json['product_id'] is int
          ? json['product_id']
          : int.tryParse(json['product_id']?.toString() ?? ''),
      itemDescription:
          json['product_name']?.toString() ??
          json['item_description']?.toString() ??
          json['description']?.toString() ??
          '',
      quantity: parseDouble(json['quantity'] ?? json['qty']),
      unitPrice: parseDouble(json['unit_price'] ?? json['price']),
      lineTotal: parseDouble(json['line_total'] ?? json['total']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (productId != null) 'product_id': productId,
      // 💡 إرسال الحقلين للتوافق التام مع السيرفر وقاعدة البيانات
      'product_name': itemDescription,
      'item_description': itemDescription,
      'quantity': quantity,
      'unit_price': unitPrice,
      'line_total': lineTotal,
    };
  }

  InvoiceItemModel copyWith({
    int? id,
    int? invoiceId,
    int? productId,
    String? itemDescription,
    double? quantity,
    double? unitPrice,
    double? lineTotal,
  }) {
    return InvoiceItemModel(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      productId: productId ?? this.productId,
      itemDescription: itemDescription ?? this.itemDescription,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      lineTotal: lineTotal ?? this.lineTotal,
    );
  }
}
