class ProductModel {
  final int id;
  final String barcode;
  final String name;
  final double unitPrice;

  ProductModel({
    required this.id,
    required this.barcode,
    required this.name,
    required this.unitPrice,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // معالجة مرنة للغاية لحقل السعر سواء جاء باسم unit_price أو price
    final rawPrice = json['unit_price'] ?? json['price'];

    double parsedPrice = 0.0;
    if (rawPrice is num) {
      parsedPrice = rawPrice.toDouble();
    } else if (rawPrice is String) {
      parsedPrice = double.tryParse(rawPrice) ?? 0.0;
    }

    // معالجة مرنة للـ ID
    final rawId = json['id'];
    int parsedId = 0;
    if (rawId is int) {
      parsedId = rawId;
    } else if (rawId is String) {
      parsedId = int.tryParse(rawId) ?? 0;
    }

    return ProductModel(
      id: parsedId,
      barcode: json['barcode']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      unitPrice: parsedPrice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'unit_price': unitPrice,
    };
  }
}
